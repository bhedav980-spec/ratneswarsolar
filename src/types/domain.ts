export type Role = 'admin' | 'district_partner' | 'dealer';

export type CustomerType = 'Residential' | 'Commercial' | 'Agricultural' | 'Industrial' | 'Institutional' | 'RWA/GHS';
export type QuoteStatus = 'draft' | 'sent' | 'pending' | 'approved' | 'rejected' | 'project_created';
export type ProjectStage =
  | 'project_created' | 'planning_done' | 'loan_required' | 'loan_not_required'
  | 'loan_application_pending' | 'loan_applied' | 'loan_sanctioned' | 'loan_rejected'
  | 'documentation_pending' | 'documentation_completed' | 'material_requirement_generated'
  | 'material_reserved' | 'material_dispatched' | 'installation_in_progress'
  | 'installation_done' | 'inspection_pending' | 'inspection_done'
  | 'meter_pending' | 'meter_done' | 'commissioning_done' | 'subsidy_pending'
  | 'subsidy_passed' | 'handover_completed' | 'project_closed';

export interface Profile {
  id: string;
  fullName: string;
  role: Role;
  districtId?: string | null;
  districtName?: string | null;
  dealerId?: string | null;
  active: boolean;
  lastLoginAt?: string | null;
}

export interface Customer {
  id: string;
  customerNo: string;
  fullName: string;
  mobile: string;
  alternateMobile?: string;
  email?: string;
  address: string;
  villageCity: string;
  taluka?: string;
  district: string;
  state: string;
  pinCode?: string;
  customerType: CustomerType;
  discom: string;
  consumerNumber?: string;
  sanctionedLoadKw?: number;
  phase?: string;
  meterType?: string;
  averageMonthlyUnits?: number;
  averageBill?: number;
  roofType?: string;
  availableRoofAreaSqFt?: number;
  gpsLink?: string;
  dealerId?: string | null;
  assignedTo?: string | null;
  leadStatus: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
  rowVersion: number;
  createdBy?: string;
  updatedBy?: string;
  archivedAt?: string | null;
}

export interface SiteSurvey {
  id: string;
  customerId: string;
  surveyDate: string;
  roofLengthFt?: number;
  roofWidthFt?: number;
  shadowObservations?: string;
  roofCondition?: string;
  structureType?: string;
  cableRoute?: string;
  earthingLocation?: string;
  inverterLocation?: string;
  meterLocation?: string;
  recommendedKw?: number;
  panelLayoutNotes?: string;
  customerRemarks?: string;
  internalRemarks?: string;
  status: 'draft' | 'completed';
}

export interface QuoteItem {
  id: string;
  description: string;
  brand?: string;
  specification?: string;
  quantity: number;
  unit: string;
  rate: number;
  taxRate: number;
  selected: boolean;
  internalOnly?: boolean;
}

export interface SubsidyBreakdown {
  eligible: boolean;
  central: number;
  state: number;
  total: number;
  ruleName?: string;
  informationalOnly?: boolean;
  referenceLines?: Array<{ label: string; amount: number }>;
}

export interface Quotation {
  id: string;
  quoteNo: string;
  customerId: string;
  versionNo: number;
  status: QuoteStatus;
  systemType: 'On-grid' | 'Off-grid' | 'Hybrid';
  dcrType: 'DCR' | 'Non-DCR';
  scheme: string;
  panelTechnology: 'Bifacial' | 'TOPCon';
  panelBrand: string;
  panelWattage: number;
  panelWattageLabel?: string;
  panelQuantity: number;
  dcCapacityKw: number;
  configurationMode?: 'automatic' | 'manual';
  configurationOverrideReason?: string;
  inverterBrand: string;
  inverterModel?: string;
  inverterCapacityKw: number;
  structureType: string;
  items: QuoteItem[];
  basePrice: number;
  suggestedPrice?: number;
  priceOverrideReason?: string;
  discount: number;
  taxMode: 'exclusive' | 'inclusive' | 'none';
  taxRate: number;
  taxableValue: number;
  taxAmount: number;
  roundOff: number;
  grandTotal: number;
  loanRequired?: boolean;
  loanBasePrice?: number;
  loanGrossUpPercent?: number;
  loanGrossUpAmount?: number;
  loanFileCharge?: number;
  subsidy: SubsidyBreakdown;
  dealerId?: string | null;
  manualDealerName?: string;
  dealerCommission?: number;
  internalCost?: number;
  paymentTerms: string;
  warrantyTerms: string;
  validityDays: number;
  notes?: string;
  createdAt: string;
  approvedAt?: string | null;
  sentAt?: string | null;
  rejectedAt?: string | null;
  updatedAt?: string;
  priceSnapshot: Record<string, unknown>;
}

export interface AgreementRecord {
  id: string;
  agreementNo: string;
  quotationId: string;
  customerId: string;
  projectId?: string | null;
  agreementDate: string;
  status: 'draft' | 'generated' | 'superseded';
  generatedFilePath: string;
  createdAt: string;
}

export interface FeasibilityInput {
  applicationReferenceNumber: string;
  janSamarthId?: string;
  discomId?: string;
  applicantName?: string;
  consumerNumber?: string;
  installationAddress?: string;
  districtName?: string;
  stateName?: string;
  pinCode?: string;
  oemName?: string;
  appliedCapacityKw?: number;
  actualCapacityKw?: number;
  projectCost?: number;
}

export interface FeasibilityReport extends FeasibilityInput {
  id: string;
  quotationId: string;
  customerId: string;
  agreementId: string;
  projectId?: string | null;
  reportDate: string;
  appliedCapacityKw: number;
  actualCapacityKw: number;
  projectCost: number;
  generatedAt: string;
}

export interface StageHistory {
  id: string;
  fromStage?: ProjectStage | null;
  toStage: ProjectStage;
  note?: string;
  changedBy: string;
  changedAt: string;
}

export interface MaterialRequirement {
  id: string;
  projectId?: string;
  itemCode: string;
  itemName: string;
  specification?: string;
  requiredQty: number;
  reservedQty: number;
  issuedQty: number;
  unit: string;
  shortageQty: number;
}

export interface Project {
  id: string;
  projectNo: string;
  customerId: string;
  quotationId: string;
  acceptedQuoteSnapshot: Quotation;
  stage: ProjectStage;
  stageHistory: StageHistory[];
  materials: MaterialRequirement[];
  assignedTo?: string | null;
  district: string;
  paymentReceived: number;
  expensesTotal: number;
  createdAt: string;
  updatedAt: string;
  installationMaterials?: InstallationDetails;
}

export interface InstallationDetails {
  invoiceNo?: string; invoiceDate?: string; placeOfSupply?: string;
  taxTreatment?: 'inclusive' | 'exclusive';
  panelBrand: string; panelTechnology: string; panelWattage: number; panelSerials: string[];
  inverterBrand: string; inverterModel: string; inverterCapacityKw: number; inverterSerial: string;
  acdb?: string; dcdb?: string; acCable?: string; dcCable?: string; earthingCable?: string;
  laCable?: string; mountingStructure?: string; earthingKit?: string; lightningArrestor?: string;
  monitoringSystem?: string; additionalItems?: string; overrideReason?: string;
}

export type InvoiceLineType = 'supply' | 'installation';

export interface InvoiceTaxLine {
  lineType: InvoiceLineType;
  description: string;
  hsnSac: string;
  sharePercent: number;
  gstRate: number;
  grossAmount: number;
  taxableValue: number;
  cgst: number;
  sgst: number;
  igst: number;
}

export interface Dealer {
  id: string;
  dealerNo: string;
  name: string;
  mobile: string;
  email?: string;
  address?: string;
  districtId?: string;
  loginUserId?: string | null;
  district: string;
  commissionType: 'fixed' | 'percentage';
  commissionValue: number;
  active: boolean;
}

export interface InventoryItem {
  id: string;
  itemCode: string;
  itemName: string;
  brand?: string;
  specification?: string;
  category?: string;
  model?: string;
  warehouseDistrict?: string;
  unit: string;
  onHand: number;
  reserved: number;
  available: number;
  reorderLevel: number;
  averageRate: number;
}

export interface CompanyProfileSettings {
  legalName: string;
  tradeName: string;
  address: string;
  mobilePrimary: string;
  mobileSecondary: string;
  email: string;
  gstin: string;
  pan: string;
  state: string;
  stateCode: string;
  jurisdiction: string;
}

export interface BankSettings {
  accountHolder: string;
  bankName: string;
  accountNumber: string;
  ifsc: string;
  branch: string;
}

export interface DocumentNumberSettings {
  prefix: string;
  nextNumber: number;
  padding: number;
}

export interface CrmSettings {
  company: CompanyProfileSettings;
  bank: BankSettings;
  quotationNumbering: DocumentNumberSettings;
  invoiceNumbering: DocumentNumberSettings;
  quotationValidityDays: number;
  paymentTerms: string;
  warrantyTerms: string;
  quotationNotes: string;
  defaultHsnSac: string;
  footerText: string;
  inactivityMinutes: number;
}

export interface Payment {
  id: string;
  customerId: string;
  projectId?: string | null;
  invoiceId?: string | null;
  paymentType: string;
  amount: number;
  paymentDate: string;
  mode: string;
  referenceNo?: string;
  notes?: string;
}

export interface Expense {
  id: string;
  projectId?: string | null;
  expenseDate: string;
  category: string;
  amount: number;
  vendor?: string;
  notes?: string;
}

export interface Invoice {
  id: string;
  invoiceNo: string;
  customerId: string;
  projectId: string;
  invoiceDate: string;
  placeOfSupply: string;
  status: 'draft' | 'issued' | 'paid' | 'cancelled' | 'credited';
  taxMode: 'exclusive' | 'inclusive' | 'none';
  quotedAmount?: number;
  taxableValue: number;
  cgst: number;
  sgst: number;
  igst: number;
  roundOff: number;
  grandTotal: number;
  taxRuleName?: string;
  taxLines?: InvoiceTaxLine[];
}

export interface PriceRow {
  id?: string;
  panelTechnology: 'Bifacial' | 'TOPCon';
  panelBrand: string;
  panelWattage: number;
  panelWattageMin?: number;
  panelWattageMax?: number;
  panelWattageLabel?: string;
  panelQuantity: number;
  capacityKw: number;
  price: number;
  expectedSubsidy?: number;
  afterSubsidy?: number;
  effectiveFrom?: string;
  versionNo?: number;
  sourceDocument?: string;
  active?: boolean;
}

export interface CommissionPayment {
  id: string; commissionId: string; paymentDate: string; amount: number; mode: string;
  referenceNo?: string; notes?: string; createdAt?: string;
}

export interface DealerCommission {
  id: string; dealerId: string; customerId: string; projectId: string; quotationId: string;
  totalCommission: number; amountPaid: number; status: 'unpaid' | 'partial' | 'paid' | 'cancelled';
  payments: CommissionPayment[]; createdAt: string;
}

export interface StockTransaction {
  id: string; inventoryItemId: string; projectId?: string | null;
  transactionType: 'purchase' | 'opening' | 'reservation' | 'issue' | 'return' | 'damage' | 'adjustment' | 'consumption';
  quantity: number; unitRate?: number; referenceNo?: string; reason?: string;
  idempotencyKey: string; occurredAt: string;
}

export interface District { id: string; name: string; code: string; active: boolean; }

export interface AuditLog {
  id: string; action: string; entityType: string; entityId?: string | null;
  reason?: string | null; createdAt: string; actorName?: string;
}
export interface SubsidyRule { id: string; name: string; customerCategory: CustomerType; effectiveFrom: string; effectiveTo?: string | null; minKw: number; maxKw?: number | null; calculation: { upTo2Rate?: number; above2Rate?: number; capKw?: number; fixedAmount?: number }; active: boolean; }
export interface TaxRule {
  id: string;
  name: string;
  effectiveFrom: string;
  effectiveTo?: string | null;
  gstRate: number;
  intrastate: boolean;
  active: boolean;
  supplyGstRate: number;
  installationGstRate: number;
  supplySharePercent: number;
  installationSharePercent: number;
  supplyHsn: string;
  installationSac: string;
}
export interface PurchaseInvoice { id: string; vendorName: string; vendorGstin?: string; invoiceNumber: string; invoiceDate: string; grossTotal: number; status: string; storagePath?: string; createdAt: string; }

export interface CrmSnapshot {
  profile: Profile;
  users: Profile[];
  customers: Customer[];
  surveys: SiteSurvey[];
  quotations: Quotation[];
  agreements: AgreementRecord[];
  feasibilityReports: FeasibilityReport[];
  projects: Project[];
  dealers: Dealer[];
  inventory: InventoryItem[];
  payments: Payment[];
  expenses: Expense[];
  invoices: Invoice[];
  priceRows: PriceRow[];
  commissions: DealerCommission[];
  stockTransactions: StockTransaction[];
  districts: District[];
  auditLogs: AuditLog[];
  subsidyRules: SubsidyRule[];
  taxRules: TaxRule[];
  purchaseInvoices: PurchaseInvoice[];
  settings: CrmSettings;
}
