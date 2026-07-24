import { useMemo, useState } from 'react';
import { Pencil, Plus, Search, Trash2 } from 'lucide-react';
import { Modal } from '../components/Modal';
import { Empty, Field, PageHeader, Status } from '../components/Ui';
import { useCrm } from '../lib/CrmContext';
import type { Customer, CustomerType } from '../types/domain';

const customerDefaults: Partial<Customer> = { fullName: '', mobile: '', address: '', villageCity: '', district: 'Kutch', state: 'Gujarat', customerType: 'Residential', discom: 'PGVCL', leadStatus: 'New', rowVersion: 0 };

export function Customers() {
  const { data, saveCustomer, archiveCustomer, saving } = useCrm();
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState(''); const [status, setStatus] = useState(''); const [page, setPage] = useState(1);
  const [editing, setEditing] = useState<Partial<Customer> | null>(null);
  const removeCustomer = async (customer: Customer) => {
    if (!window.confirm(`Delete ${customer.fullName} from the active customer list?\n\nThis keeps the audit history but removes the customer from day-to-day screens.`)) return;
    const reason = window.prompt('Reason for deleting this customer (required)') ?? '';
    if (!reason.trim()) return;
    await archiveCustomer(customer.id, reason.trim());
  };
  const list = useMemo(() => (data?.customers ?? []).filter((c) => [c.fullName, c.mobile, c.consumerNumber, c.address, c.district].some((v) => v?.toLowerCase().includes(query.toLowerCase())) && (!category || c.customerType === category) && (!status || c.leadStatus === status)), [category, data, query, status]);
  if (!data) return null;
  return <>
    <PageHeader title="Customers" subtitle="Maintain one secure customer record for quotations, projects and invoices." actions={<button className="btn btn--primary" onClick={() => setEditing({ ...customerDefaults, district: data.profile.districtName ?? data.districts[0]?.name ?? '', dealerId: data.profile.role === 'dealer' ? data.profile.dealerId : null, assignedTo: data.profile.role === 'district_partner' ? data.profile.id : null })}><Plus size={17} /> New Customer</button>} />
    <div className="toolbar"><div className="search"><Search size={17} /><input value={query} onChange={(e) => { setQuery(e.target.value); setPage(1); }} placeholder="Name, mobile, consumer number, address or district" /></div><select value={category} onChange={(e) => setCategory(e.target.value)}><option value="">All categories</option>{['Residential','Commercial','Agricultural','Industrial','Institutional','RWA/GHS'].map((x) => <option key={x}>{x}</option>)}</select><select value={status} onChange={(e) => setStatus(e.target.value)}><option value="">All statuses</option>{['New','Contacted','Qualified','Quotation','Won','Lost'].map((x) => <option key={x}>{x}</option>)}</select></div>
    <section className="card table-card">{list.length ? <><table><thead><tr><th>Customer</th><th>Contact / Location</th><th>Consumer</th><th>Type</th><th>Status</th><th>Actions</th></tr></thead><tbody>{list.slice((page-1)*25,page*25).map((c) => <tr key={c.id}><td><strong>{c.fullName}</strong><small>{c.customerNo}</small></td><td>{c.mobile}<small>{c.district}{c.address ? ` · ${c.address}` : ''}</small></td><td>{c.discom}<small>{c.consumerNumber || '-'}</small></td><td>{c.customerType}</td><td><Status tone="info">{c.leadStatus}</Status></td><td><div className="row-actions"><button className="btn btn--small" onClick={() => setEditing(c)}><Pencil size={14} /> Edit</button>{data.profile.role !== 'dealer' && <button className="btn btn--small btn--danger" title="Delete Customer" disabled={saving} onClick={() => void removeCustomer(c)}><Trash2 size={14}/> Delete</button>}</div></td></tr>)}</tbody></table><div className="pagination"><button disabled={page===1} onClick={()=>setPage((x)=>x-1)}>Previous</button><span>Page {page} of {Math.ceil(list.length/25)}</span><button disabled={page*25>=list.length} onClick={()=>setPage((x)=>x+1)}>Next</button></div></> : <Empty title="No customer found" detail="Add the first customer or change the filters." />}</section>
    {editing && <CustomerForm value={editing} saving={saving} onClose={() => setEditing(null)} onSave={async (value) => { await saveCustomer(value); setEditing(null); }} />}
  </>;
}

function CustomerForm({ value, onSave, onClose, saving }: { value: Partial<Customer>; onSave: (v: Partial<Customer>) => Promise<void>; onClose: () => void; saving: boolean }) {
  const { data } = useCrm();
  const [form, setForm] = useState(value);
  const set = (key: keyof Customer, value: unknown) => setForm((f) => ({ ...f, [key]: value }));
  return <Modal title={form.id ? 'Edit Customer' : 'New Customer'} onClose={onClose} wide><form onSubmit={async (e) => { e.preventDefault(); await onSave({ ...form, villageCity: form.villageCity || form.district || '' }); }}><div className="form-grid">
    <Field label="Full Name *"><input required value={form.fullName ?? ''} onChange={(e) => set('fullName', e.target.value)} /></Field><Field label="Mobile *"><input required pattern="[0-9+ -]{10,15}" value={form.mobile ?? ''} onChange={(e) => set('mobile', e.target.value)} /></Field>
    <Field label="Email"><input type="email" value={form.email ?? ''} onChange={(e) => set('email', e.target.value)} /></Field><Field label="Customer Type"><select value={form.customerType} onChange={(e) => set('customerType', e.target.value as CustomerType)}>{['Residential', 'Commercial', 'Agricultural', 'Industrial', 'Institutional', 'RWA/GHS'].map((x) => <option key={x}>{x}</option>)}</select></Field>
    <Field label="DISCOM"><select value={form.discom} onChange={(e) => set('discom', e.target.value)}>{['PGVCL', 'UGVCL', 'MGVCL', 'DGVCL', 'Torrent Power'].map((x) => <option key={x}>{x}</option>)}</select></Field><Field label="Consumer Number"><input value={form.consumerNumber ?? ''} onChange={(e) => set('consumerNumber', e.target.value)} /></Field>
    <Field label="District *"><select required disabled={data?.profile.role !== 'admin'} value={form.district ?? ''} onChange={(e) => { set('district', e.target.value); set('assignedTo', null); }}><option value="">Select district</option>{data?.districts.map((d) => <option key={d.id}>{d.name}</option>)}</select></Field><Field label="Lead Status"><select value={form.leadStatus ?? 'New'} onChange={(e) => set('leadStatus', e.target.value)}>{['New','Contacted','Qualified','Quotation','Won','Lost'].map((x) => <option key={x}>{x}</option>)}</select></Field>{data?.profile.role === 'admin' && <Field label="Assigned Area Partner"><select value={form.assignedTo ?? ''} onChange={(e) => set('assignedTo', e.target.value || null)}><option value="">Unassigned</option>{data.users.filter((user) => user.role === 'district_partner' && user.active && data.districts.find((area) => area.id === user.districtId)?.name === form.district).map((user) => <option value={user.id} key={user.id}>{user.fullName}</option>)}</select></Field>}{data?.profile.role !== 'dealer' && <Field label="Linked Dealer"><select value={form.dealerId ?? ''} onChange={(e) => set('dealerId', e.target.value || null)}><option value="">No dealer</option>{data?.dealers.map((d) => <option value={d.id} key={d.id}>{d.name}</option>)}</select></Field>}
    <Field label="Full Address *" wide><textarea required value={form.address ?? ''} onChange={(e) => set('address', e.target.value)} /></Field><Field label="Notes" wide><textarea value={form.notes ?? ''} onChange={(e) => set('notes', e.target.value)} /></Field>
  </div><div className="form-actions"><button type="button" className="btn" onClick={onClose}>Cancel</button><button disabled={saving} className="btn btn--primary">{saving ? 'Saving...' : 'Save Customer'}</button></div></form></Modal>;
}
