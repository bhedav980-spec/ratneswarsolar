import { createHash } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !serviceKey) throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required. Run only from a trusted local/server environment.');
const supabase = createClient(url, serviceKey, { auth: { persistSession: false } });
const uuid = (kind, value) => {
  const hex = createHash('sha256').update(`${kind}:${value}`).digest('hex').slice(0, 32).split('');
  hex[12] = '4'; hex[16] = ((parseInt(hex[16], 16) & 3) | 8).toString(16);
  return `${hex.slice(0,8).join('')}-${hex.slice(8,12).join('')}-${hex.slice(12,16).join('')}-${hex.slice(16,20).join('')}-${hex.slice(20).join('')}`;
};
const report = { startedAt: new Date().toISOString(), migrated: {}, issues: [] };
const issue = (entityType, sourceKey, sourceData, message) => report.issues.push({ entityType, sourceKey, sourceData, message });
const expectArray = (state, key) => Array.isArray(state[key]) ? state[key] : (issue(key, key, state[key], 'Expected an array; record retained for manual review.'), []);
const check = (result, label) => { if (result.error) throw new Error(`${label}: ${result.error.message}`); return result.data; };

const legacy = check(await supabase.from('crm_state').select('id,data,updated_at').eq('id', 'main').maybeSingle(), 'read legacy crm_state');
if (!legacy?.data) throw new Error('No crm_state/main row found. Nothing was changed.');
const checksum = createHash('sha256').update(JSON.stringify(legacy.data)).digest('hex');
check(await supabase.from('legacy_state_backups').insert({ source_row_id: legacy.id, state_json: legacy.data, checksum }), 'backup legacy state');
const state = legacy.data;

const dealers = expectArray(state, 'dealers');
for (const [index, d] of dealers.entries()) {
  if (!d?.name || !d?.phone) { issue('dealer', d?.id ?? String(index), d, 'Missing name or phone.'); continue; }
  check(await supabase.from('dealers').upsert({ id: uuid('dealer', d.id ?? index), dealer_no: `LEGACY-DL-${String(index + 1).padStart(4,'0')}`, name: d.name, mobile: d.phone, district_name: d.district || 'Kutch', commission_type: 'percentage', commission_value: Number(d.commissionPercent || 0), active: true }), 'migrate dealer');
}
report.migrated.dealers = dealers.length - report.issues.filter((x) => x.entityType === 'dealer').length;

const customers = expectArray(state, 'customers');
for (const [index, c] of customers.entries()) {
  if (!c?.name || !c?.phone) { issue('customer', c?.id ?? String(index), c, 'Missing required name or phone.'); continue; }
  const dealerId = c.dealerId ? uuid('dealer', c.dealerId) : null;
  const result = await supabase.from('customers').upsert({
    id: uuid('customer', c.id ?? index), customer_no: `LEGACY-CU-${String(index + 1).padStart(4,'0')}`, full_name: c.name, mobile: String(c.phone).replace(/\D/g,'').slice(-10),
    email: c.email || null, full_address: c.address || '', village_city: c.village || '', taluka: c.taluka || null, district_name: c.district || 'Kutch', state: c.state || 'Gujarat',
    customer_type: c.type || 'Residential', discom: c.discom || 'PGVCL', consumer_number: c.consumerNo || null, dealer_id: dealerId, lead_status: 'Legacy Imported', notes: c.notes || null,
  });
  if (result.error) issue('customer', c.id ?? String(index), c, result.error.message);
}
report.migrated.customers = customers.length - report.issues.filter((x) => x.entityType === 'customer').length;

const quotes = expectArray(state, 'quotes');
for (const [index, q] of quotes.entries()) {
  const customerId = q?.customerId ? uuid('customer', q.customerId) : null;
  if (!customerId || !q?.ref) { issue('quotation', q?.id ?? String(index), q, 'Missing customer reference or quotation number.'); continue; }
  const qid = uuid('quotation', q.id ?? index);
  const payload = {
    id: qid, quoteNo: q.ref, customerId, versionNo: Number(q.versionNo || 1), status: String(q.status || 'draft').toLowerCase().replace('project created','project_created'),
    systemType: q.systemType || 'On-grid', dcrType: q.dcrType || 'DCR', scheme: q.scheme || '', panelTechnology: q.panelType || 'BIFACIAL', panelBrand: q.brand || 'Unspecified',
    panelWattage: q.nos ? Math.round(Number(q.kw || 0) * 1000 / Number(q.nos)) : 0, panelQuantity: Number(q.nos || 0), dcCapacityKw: Number(q.kw || 0),
    inverterBrand: q.inverterBrand || 'Unspecified', inverterCapacityKw: Number(q.inverterKw || 0), structureType: 'Legacy imported', items: [],
    basePrice: Number(q.basePrice || q.netPayable || 0), discount: 0, taxMode: 'inclusive', taxRate: 12, taxableValue: Number(q.basePrice || q.netPayable || 0) / 1.12,
    taxAmount: Number(q.basePrice || q.netPayable || 0) - Number(q.basePrice || q.netPayable || 0) / 1.12, roundOff: 0, grandTotal: Number(q.netPayable || q.basePrice || 0),
    subsidy: q.subsidy || { eligible: false, central: 0, state: 0, agreementCharge: 0, total: 0 }, priceSnapshot: { source: 'legacy_crm_state', original: q },
    dealerId: q.dealerId ? uuid('dealer', q.dealerId) : null, dealerCommission: Number(q.commissionPercent || 0), paymentTerms: 'Imported from legacy CRM', warrantyTerms: 'Verify legacy terms', validityDays: 7,
    createdAt: q.createdAt || new Date().toISOString(),
  };
  const result = await supabase.rpc('save_quotation_version', { p_quote: payload });
  if (result.error) issue('quotation', q.id ?? String(index), q, result.error.message);
}
report.migrated.quotations = quotes.length - report.issues.filter((x) => x.entityType === 'quotation').length;

for (const unresolved of report.issues) {
  await supabase.from('migration_issues').insert({ entity_type: unresolved.entityType, source_key: String(unresolved.sourceKey), source_data: unresolved.sourceData ?? {}, issue: unresolved.message });
}
report.finishedAt = new Date().toISOString();
writeFileSync('migration-report.json', JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
