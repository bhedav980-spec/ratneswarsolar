import { useState } from 'react';
import { Eye, FilePlus2, Plus, XCircle } from 'lucide-react';
import { Modal } from '../components/Modal';
import { Empty, Field, PageHeader, Status } from '../components/Ui';
import { useCrm } from '../lib/CrmContext';
import { calculateSplitGst, formatDate, formatInr } from '../services/calculations';
import { linkedBillNumber, linkedWorkReference, normaliseLegacyQuotationNumber } from '../services/documentNumbers';
import type { Customer, CustomerType, Invoice, ManualInvoiceRecord, Project, Quotation } from '../types/domain';
import { InvoicePrint } from './InvoicePrint';
import { canIssueInvoice, InstallationForm } from './Projects';

interface ManualInvoiceFormValue {
  legacyQuoteNo: string;
  invoiceDate: string;
  customerName: string;
  mobile: string;
  address: string;
  district: string;
  state: string;
  pinCode: string;
  consumerNumber: string;
  discom: string;
  customerType: CustomerType;
  capacityKw: number;
  panelBrand: string;
  panelTechnology: 'Bifacial' | 'TOPCon';
  panelWattage: number;
  panelQuantity: number;
  panelSerials: string;
  inverterBrand: string;
  inverterModel: string;
  inverterCapacityKw: number;
  inverterSerial: string;
  quotedAmount: number;
  taxTreatment: 'inclusive' | 'exclusive';
  placeOfSupply: string;
}

const today = () => new Date().toISOString().slice(0, 10);

export function Invoices() {
  const { data, cancelCustomerInvoice, cancelManualInvoice, saving } = useCrm();
  const [preview, setPreview] = useState<{ invoice: Invoice; project: Project; customer: Customer } | null>(null);
  const [issuing, setIssuing] = useState<Project | null>(null);
  const [manualOpen, setManualOpen] = useState(false);
  if (!data || data.profile.role === 'dealer') return <Empty title="Access denied" detail="Dealers cannot access tax invoices." />;
  const admin = data.profile.role === 'admin';
  return <>
    <PageHeader
      title="Invoices"
      subtitle="Generate project-linked invoices or an Admin-only invoice for earlier manually prepared quotations."
      actions={admin ? <button className="btn btn--primary" onClick={() => setManualOpen(true)}><Plus size={16}/> Manual Invoice</button> : undefined}
    />
    <section className="card table-card">{data.projects.length ? <table><thead><tr><th>Project</th><th>Customer</th><th>Capacity</th><th>Project Value</th><th>Invoice</th><th>Action</th></tr></thead><tbody>{data.projects.map((project) => {
      const customer = data.customers.find((item) => item.id === project.customerId);
      const invoice = data.invoices.find((item) => item.projectId === project.id && item.status !== 'cancelled');
      const cancelledInvoice = data.invoices.find((item) => item.projectId === project.id && item.status === 'cancelled');
      return <tr key={project.id}><td><strong>{project.projectNo}</strong><small>{project.stage.replaceAll('_', ' ')}</small></td><td><strong>{customer?.fullName ?? 'Archived customer'}</strong><small>{customer?.mobile}</small></td><td>{project.acceptedQuoteSnapshot.dcCapacityKw.toFixed(3)} kW<small>{project.acceptedQuoteSnapshot.panelBrand} {project.acceptedQuoteSnapshot.panelTechnology}</small></td><td><strong>{formatInr(project.acceptedQuoteSnapshot.grandTotal)}</strong><small>Accepted quotation value</small></td><td>{invoice ? <Status tone="good">{invoice.invoiceNo}</Status> : cancelledInvoice ? <Status tone="bad">Cancelled {formatDate(cancelledInvoice.invoiceDate)}</Status> : canIssueInvoice(project.stage) ? <Status tone="warn">Ready to issue</Status> : <Status tone="neutral">Waiting for installation</Status>}</td><td>{invoice ? <div className="row-actions">{customer&&<button className="btn btn--small btn--primary" onClick={() => setPreview({ invoice, project, customer })}><Eye size={14} /> View / Print</button>}{admin&&<button className="btn btn--small btn--danger" disabled={saving} onClick={async()=>{const reason=window.prompt(`Cancellation reason for ${invoice.invoiceNo} (required)`)??'';if(!reason.trim()||!window.confirm(`Cancel invoice ${invoice.invoiceNo}?`))return;await cancelCustomerInvoice(invoice.id,reason);setPreview(null);}}><XCircle size={14}/> Cancel Invoice</button>}</div> : cancelledInvoice ? <small>Delete the erroneous project from Projects.</small> : <button className="btn btn--small btn--primary" disabled={!canIssueInvoice(project.stage)} onClick={() => setIssuing(project)}><FilePlus2 size={14} /> Generate Invoice</button>}</td></tr>;
    })}</tbody></table> : <Empty title="No CRM projects" detail="Project-linked invoicing becomes available after installation is completed." />}</section>

    {admin && <section className="card table-card"><div className="card__title"><div><h2>Manual Invoice Register</h2><p>For quotations, agreements and feasibility records prepared outside this CRM.</p></div><button className="btn btn--small btn--primary" onClick={() => setManualOpen(true)}><Plus size={14}/> New Manual Invoice</button></div>
      {data.manualInvoices.length ? <table><thead><tr><th>Bill No.</th><th>Old Quotation</th><th>Customer</th><th>Capacity</th><th>Amount</th><th>Status</th><th>Action</th></tr></thead><tbody>{data.manualInvoices.map((record)=><tr key={record.id}><td><strong>{record.invoiceNo}</strong><small>{formatDate(record.invoiceDate)}</small></td><td>{record.legacyQuoteNo}</td><td><strong>{record.customerName}</strong><small>{record.mobile || record.consumerNumber || '-'}</small></td><td>{record.capacityKw.toFixed(3)} kW</td><td>{formatInr(record.grandTotal)}</td><td><Status tone={record.status==='issued'?'good':'bad'}>{record.status}</Status></td><td><div className="row-actions">{record.status==='issued'&&<button className="btn btn--small btn--primary" onClick={()=>setPreview(record.snapshot)}><Eye size={14}/> View / Print</button>}{record.status==='issued'&&<button className="btn btn--small btn--danger" disabled={saving} onClick={async()=>{const reason=window.prompt(`Cancellation reason for ${record.invoiceNo} (required)`)??'';if(!reason.trim()||!window.confirm(`Cancel manual invoice ${record.invoiceNo}?`))return;await cancelManualInvoice(record.id,reason);setPreview(null);}}><XCircle size={14}/> Cancel</button>}</div></td></tr>)}</tbody></table> : <Empty title="No manual invoices" detail="Use Manual Invoice for old quotation serials such as 1 to 36."/>}
    </section>}

    {issuing && <InstallationForm project={issuing} onClose={() => setIssuing(null)} />}
    {manualOpen && <ManualInvoiceForm onClose={() => setManualOpen(false)} onCreated={(value)=>{setManualOpen(false);setPreview(value);}} />}
    {preview && <InvoicePrint invoice={preview.invoice} project={preview.project} customer={preview.customer} onClose={() => setPreview(null)} />}
  </>;
}

function ManualInvoiceForm({ onClose, onCreated }: { onClose: () => void; onCreated: (value: ManualInvoiceRecord['snapshot']) => void }) {
  const { data, saveManualInvoice, saving } = useCrm();
  const date = today();
  const [error, setError] = useState('');
  const [form, setForm] = useState<ManualInvoiceFormValue>({
    legacyQuoteNo:'',invoiceDate:date,customerName:'',mobile:'',address:'',
    district:data?.districts[0]?.name ?? 'Kutch',state:data?.settings.company.state ?? 'Gujarat',pinCode:'',
    consumerNumber:'',discom:'PGVCL',customerType:'Residential',capacityKw:0,
    panelBrand:'WAAREE',panelTechnology:'Bifacial',panelWattage:540,panelQuantity:0,panelSerials:'',
    inverterBrand:'KSOLE',inverterModel:'',inverterCapacityKw:0,inverterSerial:'',
    quotedAmount:0,taxTreatment:'inclusive',
    placeOfSupply:`${data?.settings.company.state ?? 'Gujarat'} (${data?.settings.company.stateCode ?? '24'})`,
  });
  if (!data) return null;
  const set = <K extends keyof ManualInvoiceFormValue>(key: K, value: ManualInvoiceFormValue[K]) => setForm((current)=>({...current,[key]:value}));
  let billPreview = 'Enter the old quotation serial';
  try { if (form.legacyQuoteNo.trim()) billPreview = linkedBillNumber(form.legacyQuoteNo, form.invoiceDate); } catch { billPreview = 'Quotation number must end with a valid serial'; }
  const activeTaxRule=[...data.taxRules].filter((rule)=>rule.active&&rule.effectiveFrom<=form.invoiceDate&&(!rule.effectiveTo||rule.effectiveTo>=form.invoiceDate)).sort((a,b)=>b.effectiveFrom.localeCompare(a.effectiveFrom))[0];
  const taxPreview=activeTaxRule&&form.quotedAmount>0?calculateSplitGst(form.quotedAmount,activeTaxRule,form.taxTreatment):null;

  const createRecord = (): ManualInvoiceRecord => {
    if (!activeTaxRule || !taxPreview) throw new Error('No active split GST rule exists for this invoice date.');
    const id=crypto.randomUUID(); const customerId=crypto.randomUUID(); const projectId=crypto.randomUUID();
    const invoiceNo=linkedBillNumber(form.legacyQuoteNo,form.invoiceDate);
    const quoteNo=/^\d+$/.test(form.legacyQuoteNo.trim())?normaliseLegacyQuotationNumber(form.legacyQuoteNo,form.invoiceDate):form.legacyQuoteNo.trim();
    const panelSerials=form.panelSerials.split(/[\n,]+/).map((value)=>value.trim()).filter(Boolean);
    const customer:Customer={
      id:customerId,customerNo:`LEGACY-${invoiceNo.split('/').at(-1)}`,fullName:form.customerName.trim(),mobile:form.mobile.trim(),
      address:form.address.trim(),villageCity:form.district,district:form.district,state:form.state,pinCode:form.pinCode.trim(),
      customerType:form.customerType,discom:form.discom,consumerNumber:form.consumerNumber.trim(),leadStatus:'Invoiced',
      notes:'Manual invoice for a pre-CRM quotation.',createdAt:form.invoiceDate,updatedAt:form.invoiceDate,rowVersion:1,
    };
    const quotation:Quotation={
      id:crypto.randomUUID(),quoteNo,customerId,versionNo:1,status:'approved',systemType:'On-grid',dcrType:'DCR',scheme:'Rooftop Solar',
      panelTechnology:form.panelTechnology,panelBrand:form.panelBrand.trim(),panelWattage:form.panelWattage,panelQuantity:form.panelQuantity,
      dcCapacityKw:form.capacityKw,configurationMode:'manual',inverterBrand:form.inverterBrand.trim(),inverterModel:form.inverterModel.trim(),
      inverterCapacityKw:form.inverterCapacityKw,structureType:'As installed',items:[],basePrice:form.quotedAmount,suggestedPrice:form.quotedAmount,
      discount:0,taxMode:form.taxTreatment,taxRate:activeTaxRule.gstRate,taxableValue:taxPreview.taxableValue,
      taxAmount:taxPreview.cgst+taxPreview.sgst+taxPreview.igst,roundOff:0,grandTotal:taxPreview.gross,
      subsidy:{eligible:false,central:0,state:0,total:0},paymentTerms:data.settings.paymentTerms,warrantyTerms:data.settings.warrantyTerms,
      validityDays:data.settings.quotationValidityDays,createdAt:form.invoiceDate,approvedAt:form.invoiceDate,priceSnapshot:{source:'manual-pre-crm'},
    };
    const project:Project={
      id:projectId,projectNo:linkedWorkReference(form.legacyQuoteNo,form.invoiceDate),customerId,quotationId:quotation.id,
      acceptedQuoteSnapshot:quotation,stage:'installation_done',stageHistory:[],materials:[],district:form.district,
      paymentReceived:0,expensesTotal:0,createdAt:form.invoiceDate,updatedAt:form.invoiceDate,
      installationMaterials:{
        invoiceNo,invoiceDate:form.invoiceDate,placeOfSupply:form.placeOfSupply,taxTreatment:form.taxTreatment,
        panelBrand:form.panelBrand.trim(),panelTechnology:form.panelTechnology,panelWattage:form.panelWattage,panelSerials,
        inverterBrand:form.inverterBrand.trim(),inverterModel:form.inverterModel.trim(),inverterCapacityKw:form.inverterCapacityKw,
        inverterSerial:form.inverterSerial.trim(),
      },
    };
    const invoice:Invoice={
      id,invoiceNo,customerId,projectId,invoiceDate:form.invoiceDate,placeOfSupply:form.placeOfSupply,status:'issued',
      taxMode:form.taxTreatment,quotedAmount:form.quotedAmount,taxableValue:taxPreview.taxableValue,cgst:taxPreview.cgst,
      sgst:taxPreview.sgst,igst:taxPreview.igst,roundOff:0,grandTotal:taxPreview.gross,taxRuleName:activeTaxRule.name,taxLines:taxPreview.lines,
    };
    return {
      id,invoiceNo,legacyQuoteNo:quoteNo,invoiceDate:form.invoiceDate,customerName:customer.fullName,mobile:customer.mobile,
      district:customer.district,consumerNumber:customer.consumerNumber,capacityKw:form.capacityKw,grandTotal:invoice.grandTotal,
      status:'issued',snapshot:{invoice,customer,project},createdAt:new Date().toISOString(),
    };
  };

  return <Modal title="Manual Invoice for Earlier Quotation" onClose={onClose} wide><form onSubmit={async(event)=>{event.preventDefault();setError('');try{const record=createRecord();await saveManualInvoice(record);onCreated(record.snapshot);}catch(cause){setError(cause instanceof Error?cause.message:'Manual invoice could not be saved.');}}}>
    <div className="alert alert--info">Use this only for quotations prepared outside the CRM. The numeric quotation serial is reused inside the Bill No.; the Bill reference format remains separate.</div>
    <div className="form-grid">
      <Field label="Old Quotation Number / Serial *"><input required value={form.legacyQuoteNo} onChange={(event)=>set('legacyQuoteNo',event.target.value)} placeholder="Example: 18 or RE-RSS-PGVCL-2026018"/><small>Generated Bill No.: {billPreview}</small></Field>
      <Field label="Invoice Date *"><input required type="date" value={form.invoiceDate} onChange={(event)=>set('invoiceDate',event.target.value)}/></Field>
      <Field label="Customer Name *"><input required value={form.customerName} onChange={(event)=>set('customerName',event.target.value)}/></Field>
      <Field label="Mobile"><input value={form.mobile} onChange={(event)=>set('mobile',event.target.value)}/></Field>
      <Field label="Consumer Number"><input value={form.consumerNumber} onChange={(event)=>set('consumerNumber',event.target.value)}/></Field>
      <Field label="DISCOM"><input value={form.discom} onChange={(event)=>set('discom',event.target.value)}/></Field>
      <Field label="Customer Type"><select value={form.customerType} onChange={(event)=>set('customerType',event.target.value as CustomerType)}>{['Residential','Commercial','Agricultural','Industrial','Institutional','RWA/GHS'].map((value)=><option key={value}>{value}</option>)}</select></Field>
      <Field label="District *"><input required value={form.district} onChange={(event)=>set('district',event.target.value)}/></Field>
      <Field label="State *"><input required value={form.state} onChange={(event)=>set('state',event.target.value)}/></Field>
      <Field label="PIN Code"><input value={form.pinCode} onChange={(event)=>set('pinCode',event.target.value)}/></Field>
      <Field label="Full Address *" wide><textarea required value={form.address} onChange={(event)=>set('address',event.target.value)}/></Field>
    </div>
    <section className="form-section"><h3>Installed Solar System</h3><div className="form-grid">
      <Field label="Actual Capacity (kW) *"><input required min="0.001" step="0.001" type="number" value={form.capacityKw||''} onChange={(event)=>set('capacityKw',Number(event.target.value))}/></Field>
      <Field label="Panel Brand *"><input required value={form.panelBrand} onChange={(event)=>set('panelBrand',event.target.value)}/></Field>
      <Field label="Panel Technology"><select value={form.panelTechnology} onChange={(event)=>set('panelTechnology',event.target.value as 'Bifacial'|'TOPCon')}><option>Bifacial</option><option>TOPCon</option></select></Field>
      <Field label="Panel Wattage *"><input required min="1" type="number" value={form.panelWattage||''} onChange={(event)=>set('panelWattage',Number(event.target.value))}/></Field>
      <Field label="Panel Quantity *"><input required min="1" type="number" value={form.panelQuantity||''} onChange={(event)=>set('panelQuantity',Number(event.target.value))}/></Field>
      <Field label="Panel Serial Numbers" wide><textarea value={form.panelSerials} onChange={(event)=>set('panelSerials',event.target.value)} placeholder="One serial per line or comma-separated"/></Field>
      <Field label="Inverter Brand *"><input required value={form.inverterBrand} onChange={(event)=>set('inverterBrand',event.target.value)}/></Field>
      <Field label="Inverter Model"><input value={form.inverterModel} onChange={(event)=>set('inverterModel',event.target.value)}/></Field>
      <Field label="Inverter Capacity (kW) *"><input required min="0.001" step="0.001" type="number" value={form.inverterCapacityKw||''} onChange={(event)=>set('inverterCapacityKw',Number(event.target.value))}/></Field>
      <Field label="Inverter Serial Number"><input value={form.inverterSerial} onChange={(event)=>set('inverterSerial',event.target.value)}/></Field>
    </div></section>
    <section className="form-section"><h3>Commercial and GST</h3><div className="form-grid">
      <Field label="Accepted Quotation Amount *"><input required min="1" step="0.01" type="number" value={form.quotedAmount||''} onChange={(event)=>set('quotedAmount',Number(event.target.value))}/></Field>
      <Field label="GST Treatment"><select value={form.taxTreatment} onChange={(event)=>set('taxTreatment',event.target.value as 'inclusive'|'exclusive')}><option value="inclusive">GST Included in Entered Amount</option><option value="exclusive">Add GST Above Entered Amount</option></select></Field>
      <Field label="Place of Supply *"><input required value={form.placeOfSupply} onChange={(event)=>set('placeOfSupply',event.target.value)}/></Field>
    </div>{taxPreview&&activeTaxRule&&<div className="invoice-tax-preview"><strong>{activeTaxRule.name}</strong>{taxPreview.lines.map((line)=><div key={line.lineType}><span>{line.description} · {line.sharePercent}%</span><span>Taxable {formatInr(line.taxableValue)} · GST {line.gstRate}% · Total {formatInr(line.grossAmount)}</span></div>)}<b>Final invoice total: {formatInr(taxPreview.gross)}</b></div>}</section>
    {error&&<div className="alert alert--error">{error}</div>}
    <div className="form-actions"><button type="button" className="btn" onClick={onClose}>Cancel</button><button className="btn btn--primary" disabled={saving||!activeTaxRule||!taxPreview}>{saving?'Saving...':'Save and Open Invoice'}</button></div>
  </form></Modal>;
}
