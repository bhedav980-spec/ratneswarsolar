import type {
  AgreementRecord, AuditLog, CommissionPayment, CrmSnapshot, Customer, Dealer, DealerCommission,
  CrmSettings, District, Expense, FeasibilityInput, FeasibilityReport, InstallationDetails, Invoice, MaterialRequirement, Payment, ProjectStage, PurchaseInvoice, Quotation, SiteSurvey, StockTransaction, SubsidyRule, TaxRule,
} from '../types/domain';
import { supabase } from '../lib/supabase';
import { mergeCrmSettings } from './settings';

const requireClient = () => {
  if (!supabase) throw new Error('Supabase is not configured.');
  return supabase;
};
const throwIf = (error: { message: string } | null) => { if (error) throw new Error(error.message); };

export async function signIn(email: string, password: string) {
  const client = requireClient();
  const { data, error } = await client.auth.signInWithPassword({ email: email.trim(), password });
  throwIf(error);
  if (!data.user?.email_confirmed_at) { await client.auth.signOut(); throw new Error('Verify your email before signing in.'); }
  const { data: profile, error: profileError } = await client.from('profiles').select('active, role').eq('id', data.user.id).single();
  throwIf(profileError);
  if (!profile?.active) { await client.auth.signOut(); throw new Error('This account is suspended. Contact the administrator.'); }
  await client.rpc('record_security_event', { p_action: 'login', p_metadata: { email } });
  return { mode: 'complete' as const };
}

export async function requestPasswordReset(email: string) {
  const redirectTo = `${window.location.origin}/`;
  throwIf((await requireClient().auth.resetPasswordForEmail(email.trim(), { redirectTo })).error);
}

export async function updatePassword(password:string){
  if(password.length<12||!/[a-z]/.test(password)||!/[A-Z]/.test(password)||!/[0-9]/.test(password)||!/[\W_]/.test(password))throw new Error('Use at least 12 characters with uppercase, lowercase, number and symbol.');
  throwIf((await requireClient().auth.updateUser({password})).error);
  await requireClient().rpc('record_security_event',{p_action:'password_updated',p_metadata:{}});
}

export async function signOut() {
  await requireClient().rpc('record_security_event', { p_action: 'logout', p_metadata: {} });
  throwIf((await requireClient().auth.signOut({ scope: 'local' })).error);
}

export async function hasSession() {
  const client=requireClient();const session=(await client.auth.getSession()).data.session;if(!session)return false;
  const{data,error}=await client.from('profile_current').select('id,active').maybeSingle();
  if(error||!data?.active){await client.auth.signOut({scope:'local'});return false;}return true;
}

function mapCustomer(row: any): Customer {
  return {
    id: row.id, customerNo: row.customer_no, fullName: row.full_name, mobile: row.mobile,
    alternateMobile: row.alternate_mobile ?? '', email: row.email ?? '', address: row.full_address ?? '',
    villageCity: row.village_city ?? '', taluka: row.taluka ?? '', district: row.district_name ?? '', state: row.state ?? 'Gujarat',
    pinCode: row.pin_code ?? '', customerType: row.customer_category, discom: row.discom ?? '', consumerNumber: row.consumer_number ?? '',
    sanctionedLoadKw: row.sanctioned_load_kw == null ? undefined : Number(row.sanctioned_load_kw), phase: row.phase ?? '', meterType: row.meter_type ?? '',
    averageMonthlyUnits: row.average_monthly_units == null ? undefined : Number(row.average_monthly_units), averageBill: row.average_bill == null ? undefined : Number(row.average_bill),
    roofType: row.roof_type ?? '', availableRoofAreaSqFt: row.available_roof_area_sq_ft == null ? undefined : Number(row.available_roof_area_sq_ft),
    gpsLink: row.gps_link ?? '', dealerId: row.dealer_id, assignedTo: row.assigned_partner_id, leadStatus: row.lead_status,
    notes: row.notes ?? '', createdAt: row.created_at, updatedAt: row.updated_at, rowVersion: row.row_version,
    createdBy: row.created_by, updatedBy: row.updated_by, archivedAt: row.archived_at,
  };
}

async function optionalRows(table: string, select = '*') {
  const result = await requireClient().from(table).select(select);
  if (result.error && !/does not exist/i.test(result.error.message)) throw new Error(result.error.message);
  return result.data ?? [];
}

export async function loadSnapshot(): Promise<CrmSnapshot> {
  const client = requireClient();
  const [profile, users, customers, surveys, quotes, agreementRows, feasibilityRows, projects, dealers, inventory, payments, expenses, invoices, prices, commissions, commissionPayments, stock, districts, audit, subsidy, tax, purchases, settingRows] = await Promise.all([
    client.from('profile_current').select('*').single(),
    client.from('profiles').select('*,districts(name)').order('created_at',{ascending:false}),
    client.from('customers').select('*').is('archived_at', null).order('created_at', { ascending: false }),
    client.from('site_surveys').select('*').is('deleted_at', null),
    client.from('quotation_current').select('*').order('created_at', { ascending: false }),
    optionalRows('agreements'),
    optionalRows('feasibility_reports'),
    client.from('project_current').select('*').order('created_at', { ascending: false }),
    client.from('dealers').select('*').is('deleted_at', null).order('name'),
    client.from('inventory_balance').select('*'), client.from('payments').select('*').is('deleted_at', null),
    client.from('expenses').select('*').is('deleted_at', null), client.from('customer_invoices').select('*').order('issued_at',{ascending:false}),
    client.from('active_price_rows').select('*'), client.from('dealer_commissions').select('*'), optionalRows('dealer_commission_payments'), optionalRows('stock_transactions'),
    client.from('districts').select('*').eq('active', true).order('name'), optionalRows('audit_logs'), client.from('subsidy_rules').select('*').eq('active',true), client.from('tax_rules').select('*').eq('active',true), optionalRows('purchase_invoices'), optionalRows('company_settings'),
  ]);
  for (const result of [profile, users, customers, surveys, quotes, projects, dealers, inventory, payments, expenses, invoices, prices, commissions, districts, subsidy, tax]) throwIf(result.error);
  const p: any = profile.data;
  const paymentRows = commissionPayments as any[];
  return {
    profile: { id: p.id, fullName: p.full_name, role: p.role, districtId: p.district_id, districtName: p.district_name, dealerId: p.dealer_id, active: p.active, lastLoginAt: p.last_login_at },
    users: (users.data ?? []).map((u:any)=>({id:u.id,fullName:u.full_name,role:u.role,districtId:u.district_id,districtName:u.districts?.name,dealerId:u.dealer_id,active:u.active,lastLoginAt:u.last_login_at})),
    customers: (customers.data ?? []).map(mapCustomer), surveys: (surveys.data ?? []).map((r: any) => r.payload as SiteSurvey),
    quotations: (quotes.data ?? []).map((r: any) => r.payload as Quotation),
    agreements: (agreementRows as any[]).map((r): AgreementRecord => ({ id:r.id,agreementNo:r.agreement_no,quotationId:r.quotation_id,customerId:r.customer_id,projectId:r.project_id,agreementDate:r.agreement_date,status:r.status,generatedFilePath:r.generated_file_path,createdAt:r.created_at })),
    feasibilityReports: (feasibilityRows as any[]).map((r): FeasibilityReport => ({ id:r.id,quotationId:r.quotation_id,customerId:r.customer_id,agreementId:r.agreement_id,projectId:r.project_id,reportDate:r.report_date,applicationReferenceNumber:r.application_reference_number,janSamarthId:r.jan_samarth_id,discomId:r.discom_id,appliedCapacityKw:Number(r.applied_capacity_kw),actualCapacityKw:Number(r.actual_capacity_kw),projectCost:Number(r.project_cost),generatedAt:r.generated_at })),
    projects: (projects.data ?? []).map((r: any) => r.payload),
    dealers: (dealers.data ?? []).map((r: any) => ({ id: r.id, dealerNo: r.dealer_no, name: r.name, mobile: r.mobile, email: r.email, address: r.address, district: r.district_name, districtId: r.district_id, loginUserId: r.login_user_id, commissionType: r.default_commission_type, commissionValue: Number(r.default_commission_value), active: r.active })),
    inventory: (inventory.data ?? []).map((r: any) => ({ id: r.id, itemCode: r.item_code, itemName: r.item_name, category: r.category, brand: r.brand, model: r.model, specification: r.specification, warehouseDistrict: r.district_name, unit: r.unit, onHand: Number(r.on_hand), reserved: Number(r.reserved), available: Number(r.available), reorderLevel: Number(r.reorder_level), averageRate: Number(r.average_rate) })),
    payments: (payments.data ?? []).map((r: any) => r.payload as Payment), expenses: (expenses.data ?? []).map((r: any) => r.payload as Expense),
    invoices: (invoices.data ?? []).map((r: any) => r.snapshot as Invoice),
    priceRows: (prices.data ?? []).map((r: any) => ({ id: r.id, panelTechnology: r.panel_technology, panelBrand: r.panel_brand, panelWattage: Number(r.panel_wattage), panelWattageMin: r.panel_wattage_min == null ? undefined : Number(r.panel_wattage_min), panelWattageMax: r.panel_wattage_max == null ? undefined : Number(r.panel_wattage_max), panelWattageLabel: r.panel_wattage_label ?? `${r.panel_wattage} Wp`, panelQuantity: r.panel_quantity, capacityKw: Number(r.dc_capacity_kw), price: Number(r.gross_price), expectedSubsidy: r.expected_subsidy == null ? undefined : Number(r.expected_subsidy), afterSubsidy: r.after_subsidy == null ? undefined : Number(r.after_subsidy), effectiveFrom: r.effective_from, versionNo: r.version_no, sourceDocument: r.source_document, active: r.active })),
    commissions: (commissions.data ?? []).map((r: any): DealerCommission => ({ id: r.id, dealerId: r.dealer_id, customerId: r.customer_id, projectId: r.project_id, quotationId: r.quotation_id, totalCommission: Number(r.total_commission), amountPaid: Number(r.amount_paid), status: r.status, payments: paymentRows.filter((x) => x.commission_id === r.id).map((x): CommissionPayment => ({ id: x.id, commissionId: x.commission_id, paymentDate: x.payment_date, amount: Number(x.amount), mode: x.mode, referenceNo: x.reference_no, notes: x.notes, createdAt: x.created_at })), createdAt: r.created_at })),
    stockTransactions: (stock as any[]).map((r): StockTransaction => ({ id: r.id, inventoryItemId: r.inventory_item_id, projectId: r.project_id, transactionType: r.transaction_type, quantity: Number(r.quantity), unitRate: r.unit_rate == null ? undefined : Number(r.unit_rate), referenceNo: r.reference_no, reason: r.reason, idempotencyKey: r.idempotency_key, occurredAt: r.occurred_at })),
    districts: (districts.data ?? []).map((r: any): District => ({ id: r.id, name: r.name, code: r.code, active: r.active })),
    auditLogs: (audit as any[]).map((r): AuditLog => ({ id: r.id, action: r.action, entityType: r.entity_type, entityId: r.entity_id, reason: r.reason, createdAt: r.created_at, actorName: r.actor_name })),
    subsidyRules: (subsidy.data ?? []).map((r:any):SubsidyRule=>({id:r.id,name:r.name,customerCategory:r.customer_category,effectiveFrom:r.effective_from,effectiveTo:r.effective_to,minKw:Number(r.min_kw),maxKw:r.max_kw==null?null:Number(r.max_kw),calculation:r.calculation,active:r.active})),
    taxRules: (tax.data ?? []).map((r:any):TaxRule=>({
      id:r.id,name:r.name,effectiveFrom:r.effective_from,effectiveTo:r.effective_to,
      gstRate:Number(r.gst_rate),intrastate:r.intrastate,active:r.active,
      supplyGstRate:Number(r.supply_gst_rate ?? r.gst_rate),
      installationGstRate:Number(r.installation_gst_rate ?? r.gst_rate),
      supplySharePercent:Number(r.supply_share_percent ?? 70),
      installationSharePercent:Number(r.installation_share_percent ?? 30),
      supplyHsn:r.supply_hsn ?? '854140',installationSac:r.installation_sac ?? '995442',
    })),
    purchaseInvoices: (purchases as any[]).map((r):PurchaseInvoice=>({id:r.id,vendorName:r.vendor_name,vendorGstin:r.vendor_gstin,invoiceNumber:r.invoice_number,invoiceDate:r.invoice_date,grossTotal:Number(r.gross_total),status:r.status,storagePath:r.storage_path,createdAt:r.created_at})),
    settings: mergeCrmSettings((settingRows as any[]).find((row) => row.key === 'crm.settings')?.value),
  };
}

function customerPayload(c: Partial<Customer>) {
  return { id: c.id ?? null, fullName: c.fullName, mobile: c.mobile, alternateMobile: c.alternateMobile || null, email: c.email || null,
    address: c.address, villageCity: c.villageCity, taluka: c.taluka || null, district: c.district, state: c.state || 'Gujarat',
    pinCode: c.pinCode || null, customerCategory: c.customerType, discom: c.discom, consumerNumber: c.consumerNumber || null,
    sanctionedLoadKw: c.sanctionedLoadKw || null, phase: c.phase || null, meterType: c.meterType || null,
    averageMonthlyUnits: c.averageMonthlyUnits || null, averageBill: c.averageBill || null, roofType: c.roofType || null,
    availableRoofAreaSqFt: c.availableRoofAreaSqFt || null, gpsLink: c.gpsLink || null, dealerId: c.dealerId || null,
    assignedPartnerId: c.assignedTo || null, leadStatus: c.leadStatus || 'New', notes: c.notes || null, rowVersion: c.rowVersion ?? null };
}

export async function saveCustomer(_snapshot: CrmSnapshot, input: Partial<Customer>) {
  const { error } = await requireClient().rpc('save_customer', { p_customer: customerPayload(input) }); throwIf(error); return loadSnapshot();
}
export async function archiveCustomer(_snapshot: CrmSnapshot, customerId: string, reason: string) {
  const { error } = await requireClient().rpc('archive_customer', { p_customer_id: customerId, p_reason: reason }); throwIf(error); return loadSnapshot();
}
export async function saveSurvey(_snapshot: CrmSnapshot, survey: SiteSurvey) {
  const { error } = await requireClient().from('site_surveys').upsert({ id: survey.id, customer_id: survey.customerId, survey_date: survey.surveyDate, status: survey.status, payload: survey }); throwIf(error); return loadSnapshot();
}
export async function saveQuotation(_snapshot: CrmSnapshot, quote: Quotation) {
  const { error } = await requireClient().rpc('save_quotation_version', { p_quote: quote }); throwIf(error); return loadSnapshot();
}
export async function setQuotationStatus(_snapshot: CrmSnapshot, quoteId: string, status: Quotation['status'], reason = '') {
  const { error } = await requireClient().rpc('set_quotation_status', { p_quotation_id: quoteId, p_status: status, p_reason: reason || null }); throwIf(error); return loadSnapshot();
}
export async function saveAgreementDocument(_snapshot: CrmSnapshot, quoteId: string, generatedFilePath: string) {
  const { error } = await requireClient().rpc('save_agreement_document', { p_quotation_id: quoteId, p_generated_file_path: generatedFilePath }); throwIf(error); return loadSnapshot();
}
export async function saveFeasibilityAndCreateProject(_snapshot: CrmSnapshot, quoteId: string, input: FeasibilityInput) {
  const { error } = await requireClient().rpc('save_feasibility_and_create_project', { p_quotation_id: quoteId, p_data: input }); throwIf(error); return loadSnapshot();
}
export async function changeProjectStage(_snapshot: CrmSnapshot, projectId: string, stage: ProjectStage, note: string, overrideReason = '') {
  const { error } = await requireClient().rpc('change_project_stage', { p_project_id: projectId, p_new_stage: stage, p_note: note || null, p_override_reason: overrideReason || null }); throwIf(error); return loadSnapshot();
}
export async function addDealer(_snapshot: CrmSnapshot, dealer: Dealer) {
  const { error } = await requireClient().rpc('save_dealer', { p_dealer: dealer }); throwIf(error); return loadSnapshot();
}
export async function addPayment(_snapshot: CrmSnapshot, payment: Payment) {
  const { error } = await requireClient().from('payments').insert({ customer_id: payment.customerId, project_id: payment.projectId || null, invoice_id: payment.invoiceId || null, payment_type: payment.paymentType, amount: payment.amount, payment_date: payment.paymentDate, mode: payment.mode, reference_no: payment.referenceNo || null, notes: payment.notes || null, payload: payment, idempotency_key: payment.id }); throwIf(error); return loadSnapshot();
}
export async function addExpense(_snapshot: CrmSnapshot, expense: Expense) {
  const { error } = await requireClient().from('expenses').insert({ project_id: expense.projectId || null, expense_date: expense.expenseDate, category: expense.category, amount: expense.amount, vendor: expense.vendor || null, notes: expense.notes || null, payload: expense }); throwIf(error); return loadSnapshot();
}
export async function issueInvoice(_snapshot: CrmSnapshot, invoice: Invoice) {
  const { error } = await requireClient().rpc('issue_customer_invoice', { p_invoice: invoice }); throwIf(error); return loadSnapshot();
}
export async function saveInstallationAndIssueInvoice(_snapshot: CrmSnapshot, projectId: string, details: InstallationDetails) {
  const { error } = await requireClient().rpc('save_installation_and_issue_invoice', { p_project_id: projectId, p_details: details }); throwIf(error); return loadSnapshot();
}
export async function postStockTransaction(_snapshot: CrmSnapshot, transaction: StockTransaction) {
  const { error } = await requireClient().rpc('post_stock_transaction', { p_transaction: transaction }); throwIf(error); return loadSnapshot();
}
export async function payCommission(_snapshot: CrmSnapshot, payment: CommissionPayment) {
  const { error } = await requireClient().rpc('pay_dealer_commission', { p_payment: payment }); throwIf(error); return loadSnapshot();
}
export async function confirmVendorInvoice(payload: Record<string, unknown>) {
  const { data, error } = await requireClient().rpc('post_purchase_invoice', { p_invoice: payload }); throwIf(error); return data;
}
export async function createInventoryItem(payload: Record<string, unknown>) {
  const { data, error } = await requireClient().rpc('create_inventory_item', { p_item: payload }); throwIf(error); return data;
}
export async function updateInventoryItem(payload: Record<string, unknown>) {
  const { data, error } = await requireClient().rpc('update_inventory_item', { p_item: payload }); throwIf(error); return data;
}
export async function archiveInventoryItem(itemId: string, reason: string) {
  const { error } = await requireClient().rpc('archive_inventory_item', { p_item_id: itemId, p_reason: reason }); throwIf(error);
}
export async function saveProjectMaterials(projectId: string, materials: MaterialRequirement[], reason: string) {
  const { error } = await requireClient().rpc('save_project_material_requirements', { p_project_id: projectId, p_materials: materials, p_reason: reason }); throwIf(error);
}
export async function saveCrmSettings(settings: CrmSettings) {
  const { error } = await requireClient().rpc('save_crm_settings', { p_settings: settings }); throwIf(error);
}

export async function uploadPrivateFile(bucket: string, path: string, file: File) {
  const client = requireClient();
  const { error } = await client.storage.from(bucket).upload(path, file, { upsert: false, contentType: file.type }); throwIf(error); return path;
}
export async function getSignedUrl(bucket: string, path: string) {
  const { data, error } = await requireClient().storage.from(bucket).createSignedUrl(path, 300); throwIf(error); return data?.signedUrl ?? '';
}
export async function invokeAiImporter(kind: 'customer' | 'vendor_invoice', files: File[]) {
  const encoded = await Promise.all(files.map(async (file) => ({ name: file.name, type: file.type, data: bytesToBase64(new Uint8Array(await file.arrayBuffer())) })));
  const { data, error } = await requireClient().functions.invoke('document-importer', { body: { kind, files: encoded } }); await throwFunctionError(error); return data;
}

async function throwFunctionError(error: unknown) {
  if (!error) return;
  const fallback = error instanceof Error ? error.message : 'Edge Function request failed.';
  const response = (error as { context?: Response }).context;
  if (response) {
    try {
      const payload = await response.clone().json() as { error?: string };
      if (payload.error) throw new Error(payload.error);
    } catch (detail) { if (detail instanceof Error && detail.message !== 'Unexpected end of JSON input' && !(detail instanceof SyntaxError)) throw detail; }
  }
  throw new Error(fallback);
}

function bytesToBase64(bytes: Uint8Array) {
  const chunkSize = 0x8000;
  let binary = '';
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}
export async function inviteUser(input: { email: string; fullName: string; role: 'admin' | 'district_partner' | 'dealer'; districtId?: string; dealerId?: string }) {
  const { data, error } = await requireClient().functions.invoke('admin-users', { body: { action: 'invite', appUrl: window.location.origin, ...input } }); await throwFunctionError(error); return data;
}
export async function createUserManually(input: { email: string; password: string; fullName: string; role: 'admin' | 'district_partner' | 'dealer'; districtId?: string; dealerId?: string }) {
  const { data, error } = await requireClient().functions.invoke('admin-users', { body: { action: 'create_user', ...input } }); await throwFunctionError(error); return data;
}
export async function manageUser(action: 'set_active'|'reset_password'|'delete_user', userId: string, active?: boolean, reason?: string) {
  const { data, error } = await requireClient().functions.invoke('admin-users', { body: { action, userId, active, reason, appUrl: window.location.origin } }); await throwFunctionError(error); return data;
}
export async function deleteProject(projectId:string,reason:string){
  const{error}=await requireClient().rpc('delete_erroneous_project',{p_project_id:projectId,p_reason:reason});throwIf(error);return loadSnapshot();
}
export async function cancelCustomerInvoice(invoiceId:string,reason:string){
  const{error}=await requireClient().rpc('cancel_customer_invoice',{p_invoice_id:invoiceId,p_reason:reason});throwIf(error);return loadSnapshot();
}
export async function updateUserProfile(input:{userId:string;fullName:string;role:'admin'|'district_partner'|'dealer';districtId?:string|null;dealerId?:string|null}){const{data,error}=await requireClient().functions.invoke('admin-users',{body:{action:'update_profile',...input}});await throwFunctionError(error);return data;}
