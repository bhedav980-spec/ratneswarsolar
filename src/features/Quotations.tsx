import { useEffect, useMemo, useRef, useState } from 'react';
import { CheckCircle2, Copy, Download, Eye, FileCheck2, FilePlus2, Plus, Send, Trash2, XCircle } from 'lucide-react';
import { Modal } from '../components/Modal';
import { Empty, Field, PageHeader, Status } from '../components/Ui';
import { useCrm } from '../lib/CrmContext';
import { agreementFilename, agreementMimeType, createAgreementDocx } from '../lib/agreementDocx';
import { createFeasibilityPdf, quotationSerialNumber } from '../lib/feasibilityPdf';
import { calculateLoanCustomerPrice, calculateQuote, formatInr, standardInformationalSubsidy } from '../services/calculations';
import { exactCapacityKw, resolveOfficialPriceRow, wattagesForPriceRows } from '../services/priceMatching';
import { uploadPrivateFile } from '../services/repository';
import type { Customer, Dealer, FeasibilityInput, FeasibilityReport, Quotation, QuoteItem } from '../types/domain';
import { QuotationPrint } from './QuotationPrint';

const sourceStructure: Record<number, { pipe40: number; pipe60: number }> = {
  4:{pipe40:2,pipe60:3},5:{pipe40:3,pipe60:3},6:{pipe40:3,pipe60:4},7:{pipe40:3,pipe60:4},8:{pipe40:4,pipe60:4},9:{pipe40:4,pipe60:5},10:{pipe40:4,pipe60:5},11:{pipe40:5,pipe60:6},12:{pipe40:5,pipe60:6},13:{pipe40:6,pipe60:6},14:{pipe40:6,pipe60:6},15:{pipe40:6,pipe60:7},16:{pipe40:6,pipe60:7},17:{pipe40:6,pipe60:8},
};

const standardItems = (brand: string, tech: string, wattageLabel: string, qty: number): QuoteItem[] => {
  const structure = sourceStructure[qty];
  return [
    { id: crypto.randomUUID(), description: 'PV Module', brand, specification: `${wattageLabel} ${tech}`, quantity: qty, unit: 'Nos', rate: 0, taxRate: 0, selected: true },
    { id: crypto.randomUUID(), description: 'Grid Tie Inverter', brand: 'Polycab', specification: 'Capacity as selected', quantity: 1, unit: 'No', rate: 0, taxRate: 0, selected: true },
    { id: crypto.randomUUID(), description: 'Mounting Structure', brand: 'Hot Dip Galvanized', specification: structure ? `${structure.pipe60} x 60x40 legs/rafters and ${structure.pipe40} x 40x40 purlins` : 'As per site design', quantity: 1, unit: 'Set', rate: 0, taxRate: 0, selected: true },
    { id: crypto.randomUUID(), description: 'AC Distribution Box', brand: 'Schneider / Approved', specification: 'Protection as per design', quantity: 1, unit: 'Set', rate: 0, taxRate: 0, selected: true },
    { id: crypto.randomUUID(), description: 'DC Distribution Box', brand: 'Schneider / Approved', specification: 'Protection as per design', quantity: 1, unit: 'Set', rate: 0, taxRate: 0, selected: true },
    { id: crypto.randomUUID(), description: 'AC & DC Cables', brand: 'Finolex / Polycab', specification: 'Size and length as per site design', quantity: 1, unit: 'Lot', rate: 0, taxRate: 0, selected: true },
    { id: crypto.randomUUID(), description: 'Earthing Kit with Lightning Arrestor', brand: 'Approved', specification: 'Copper earthing and LA protection', quantity: 1, unit: 'Set', rate: 0, taxRate: 0, selected: true },
    { id: crypto.randomUUID(), description: 'LA Earthing Cable', brand: 'Weecab / Jainflex', specification: 'As per site design', quantity: 1, unit: 'Lot', rate: 0, taxRate: 0, selected: true },
    { id: crypto.randomUUID(), description: 'Online Monitoring System', brand: 'OMS', specification: 'Mobile App + Remote Monitoring', quantity: 1, unit: 'No', rate: 0, taxRate: 0, selected: true },
    { id: crypto.randomUUID(), description: 'Installation, Testing and Commissioning', specification: 'Complete rooftop EPC scope', quantity: 1, unit: 'Job', rate: 0, taxRate: 0, selected: true },
  ];
};

const upper = (value: string) => value.trim().toUpperCase();
const cleanQuotationNotes = (value: string) => value
  .split(/\n+/)
  .filter((line) => !/subsidy.*informational|subject to authority approval|does not reduce or change the quotation value/i.test(line))
  .join('\n')
  .trim();

export function Quotations() {
  const { data, saveQuotation, setQuotationStatus, saveAgreementDocument, saveFeasibilityAndCreateProject, updateFeasibilityReport, saving } = useCrm();
  const [editing, setEditing] = useState<Quotation | 'new' | null>(null); const [preview, setPreview] = useState<Quotation | null>(null); const [feasibilityQuote, setFeasibilityQuote] = useState<Quotation | null>(null); const [filter, setFilter] = useState('all');
  const [documentBusy, setDocumentBusy] = useState(''); const [documentError, setDocumentError] = useState('');
  if (!data) return null;
  const list = filter === 'all' ? data.quotations : data.quotations.filter((q) => q.status === filter); const customer = (id: string) => data.customers.find((c) => c.id === id);
  const canApprove = data.profile.role !== 'dealer'; const statusTone = (s: string) => s === 'approved' || s === 'project_created' ? 'good' : s === 'rejected' ? 'bad' : ['sent','pending'].includes(s) ? 'warn' : 'neutral';
  const change = async (q: Quotation, status: Quotation['status']) => { const reason = status === 'rejected' ? window.prompt('Rejection reason (required)') ?? '' : ''; if (status === 'rejected' && !reason.trim()) return; await setQuotationStatus(q.id, status, reason); };
  const approve = async (q: Quotation) => { if (!window.confirm(`Approve ${q.quoteNo}? The Agreement DOCX and Feasibility Report will be completed before its project is created.`)) return; await change(q, 'approved'); };
  const downloadBlob = (blob: Blob, filename: string) => { const url = URL.createObjectURL(blob); const link = document.createElement('a'); link.href = url; link.download = filename; link.click(); window.setTimeout(() => URL.revokeObjectURL(url), 60_000); };
  const generateAgreement = async (q: Quotation) => {
    const selectedCustomer = customer(q.customerId); if (!selectedCustomer) return;
    setDocumentBusy(q.id); setDocumentError('');
    try {
      const blob = await createAgreementDocx(q, selectedCustomer); const filename = agreementFilename(q);
      if (q.status === 'approved') {
        const path = `${q.customerId}/${q.id}/${Date.now()}-${filename}`;
        await uploadPrivateFile('agreement-files', path, new File([blob], filename, { type: agreementMimeType }));
        await saveAgreementDocument(q.id, path);
      }
      downloadBlob(blob, filename);
    } catch (cause) { setDocumentError(cause instanceof Error ? cause.message : 'Agreement generation failed.'); }
    finally { setDocumentBusy(''); }
  };
  const generateFeasibility = async (q: Quotation, input: FeasibilityInput) => {
    const selectedCustomer = customer(q.customerId); if (!selectedCustomer) return;
    const pdf = await createFeasibilityPdf({ quotation:q,customer:selectedCustomer,feasibility:input });
    if (q.status === 'project_created') await updateFeasibilityReport(q.id, input);
    else await saveFeasibilityAndCreateProject(q.id, input);
    pdf.save(`${q.quoteNo.replace(/[^A-Za-z0-9_-]+/g, '-')}-feasibility-report.pdf`);
  };
  return <>
    <PageHeader title="Quotations" subtitle="Automatic source pricing with fully editable system configuration, BOM and commercial values." actions={<button className="btn btn--primary" onClick={() => setEditing('new')} disabled={!data.customers.length}><Plus size={17} /> New Quotation</button>} />
    {documentError && <div className="alert alert--error">{documentError}</div>}
    <div className="toolbar"><select aria-label="Quotation status filter" value={filter} onChange={(e) => setFilter(e.target.value)}><option value="all">All statuses</option>{['draft','sent','pending','approved','rejected','project_created'].map((s) => <option key={s}>{s}</option>)}</select></div>
    <section className="card table-card">{list.length ? <table><thead><tr><th>Reference</th><th>Customer</th><th>System</th><th>Value</th><th>Status</th><th>Actions</th></tr></thead><tbody>{list.map((q) => <tr key={q.id}><td><strong>{q.quoteNo}</strong><small>Revision {q.versionNo}</small></td><td>{customer(q.customerId)?.fullName ?? 'Missing customer'}</td><td>{q.dcCapacityKw.toFixed(3)} kW<small>{q.panelBrand} {q.panelTechnology} · {q.panelWattageLabel ?? `${q.panelWattage} Wp`}</small></td><td><strong>{formatInr(q.grandTotal)}</strong><small>{q.loanRequired ? 'Loan quotation' : 'GST included'}</small></td><td><Status tone={statusTone(q.status)}>{q.status.replace('_',' ')}</Status></td><td><div className="row-actions">
      <button className="icon-btn" title="Preview" onClick={() => setPreview(q)}><Eye size={16} /></button>
      {q.status === 'draft' && <button className="icon-btn" title="Edit draft" onClick={() => setEditing(q)}><FilePlus2 size={16} /></button>}
      {q.status === 'draft' && <button className="icon-btn" title="Mark sent" onClick={() => void change(q, 'sent')}><Send size={16} /></button>}
      {canApprove && ['sent','pending'].includes(q.status) && <button className="icon-btn good" title="Approve quotation" onClick={() => void approve(q)}><CheckCircle2 size={16} /></button>}
      {canApprove && q.status === 'approved' && <button className="btn btn--small" disabled={documentBusy === q.id || saving} title={data.agreements.some((agreement) => agreement.quotationId === q.id) ? 'Download the editable Agreement DOCX again' : 'Generate editable Agreement DOCX'} onClick={() => void generateAgreement(q)}><Download size={14} /> Agreement DOCX</button>}
      {canApprove && q.status === 'approved' && data.agreements.some((agreement) => agreement.quotationId === q.id) && <button className="btn btn--small btn--primary" title="Complete feasibility and create project" onClick={() => setFeasibilityQuote(q)}><FileCheck2 size={14} /> Feasibility</button>}
      {canApprove && q.status === 'project_created' && data.agreements.some((agreement) => agreement.quotationId === q.id) && <button className="btn btn--small" disabled={documentBusy === q.id} title="Download editable Agreement DOCX" onClick={() => void generateAgreement(q)}><Download size={14} /> Agreement</button>}
      {canApprove && q.status === 'project_created' && data.feasibilityReports.find((report) => report.quotationId === q.id) && <button className="btn btn--small" title="Edit report fields and download a corrected Feasibility PDF" onClick={() => setFeasibilityQuote(q)}><FileCheck2 size={14} /> Edit Feasibility</button>}
      {canApprove && !['rejected','project_created'].includes(q.status) && <button className="icon-btn bad" title="Reject" onClick={() => void change(q, 'rejected')}><XCircle size={16} /></button>}
      {!['draft','project_created'].includes(q.status) && <button className="icon-btn" title="Create revision" onClick={() => setEditing({ ...q, id: crypto.randomUUID(), versionNo: q.versionNo + 1, status: 'draft', createdAt: new Date().toISOString(), approvedAt: null, sentAt: null, rejectedAt: null })}><Copy size={16} /></button>}
    </div></td></tr>)}</tbody></table> : <Empty title="No quotations" detail="Create a quotation after adding a customer." />}</section>
    {editing && <QuoteForm initial={editing === 'new' ? undefined : editing} customers={data.customers} onClose={() => setEditing(null)} saving={saving} onSave={async (quote) => { await saveQuotation(quote); setEditing(null); }} />}
    {preview && customer(preview.customerId) && <QuotationPrint quote={preview} customer={customer(preview.customerId)!} onClose={() => setPreview(null)} />}
    {feasibilityQuote && customer(feasibilityQuote.customerId) && <FeasibilityForm quotation={feasibilityQuote} customer={customer(feasibilityQuote.customerId)!} initial={data.feasibilityReports.find((report)=>report.quotationId===feasibilityQuote.id)} saving={saving} onClose={() => setFeasibilityQuote(null)} onGenerate={async(input)=>{await generateFeasibility(feasibilityQuote,input);setFeasibilityQuote(null);}} />}
  </>;
}

function FeasibilityForm({ quotation, customer, initial, saving, onClose, onGenerate }: { quotation:Quotation;customer:Customer;initial?:FeasibilityReport;saving:boolean;onClose:()=>void;onGenerate:(input:FeasibilityInput)=>Promise<void> }) {
  const defaultAddress=[customer.address,customer.villageCity,customer.taluka,customer.district,customer.state,customer.pinCode].filter(Boolean).join(', ');
  const [applicantName,setApplicantName]=useState(initial?.applicantName??customer.fullName); const [consumerNumber,setConsumerNumber]=useState(initial?.consumerNumber??customer.consumerNumber??'');
  const [installationAddress,setInstallationAddress]=useState(initial?.installationAddress??defaultAddress); const [districtName,setDistrictName]=useState(initial?.districtName??customer.district); const [stateName,setStateName]=useState(initial?.stateName??customer.state??'Gujarat'); const [pinCode,setPinCode]=useState(initial?.pinCode??customer.pinCode??'');
  const [oemName,setOemName]=useState(initial?.oemName??quotation.panelBrand); const [appliedCapacityKw,setAppliedCapacityKw]=useState(initial?.appliedCapacityKw??quotation.dcCapacityKw); const [actualCapacityKw,setActualCapacityKw]=useState(initial?.actualCapacityKw??quotation.dcCapacityKw); const [projectCost,setProjectCost]=useState(initial?.projectCost??quotation.grandTotal);
  const [applicationReferenceNumber,setApplicationReferenceNumber]=useState(initial?.applicationReferenceNumber??''); const [janSamarthId,setJanSamarthId]=useState(initial?.janSamarthId??''); const [discomId,setDiscomId]=useState(initial?.discomId??''); const [error,setError]=useState('');
  const isEditing=Boolean(initial);
  return <Modal title={isEditing?'Edit Vendor Feasibility Report':'Vendor Feasibility Report'} onClose={onClose} wide><form onSubmit={async(event)=>{event.preventDefault();if(!applicationReferenceNumber.trim()){setError('Application Reference Number is required.');return;}if(!applicantName.trim()||!installationAddress.trim()||!oemName.trim()){setError('Applicant name, address and OEM name are required.');return;}setError('');try{await onGenerate({applicationReferenceNumber:applicationReferenceNumber.trim(),janSamarthId:janSamarthId.trim(),discomId:discomId.trim(),applicantName:applicantName.trim(),consumerNumber:consumerNumber.trim(),installationAddress:installationAddress.trim(),districtName:districtName.trim(),stateName:stateName.trim(),pinCode:pinCode.trim(),oemName:oemName.trim(),appliedCapacityKw,actualCapacityKw,projectCost});}catch(cause){setError(cause instanceof Error?cause.message:'Feasibility generation failed.');}}}>
    <section className="form-section"><div className="card__title"><div><h3>Auto-filled, fully editable report details</h3><p>EPC Number {quotationSerialNumber(quotation.quoteNo)} is derived automatically from quotation {quotation.quoteNo}. Correct any field here before downloading.</p></div></div><div className="form-grid">
      <Field label="Applicant Name *"><input required value={applicantName} onChange={(event)=>setApplicantName(event.target.value)}/></Field><Field label="Consumer Number"><input value={consumerNumber} onChange={(event)=>setConsumerNumber(event.target.value)} placeholder="Blank prints as __"/></Field>
      <Field label="Installation Address *"><textarea required rows={3} value={installationAddress} onChange={(event)=>setInstallationAddress(event.target.value)}/></Field><Field label="District"><input value={districtName} onChange={(event)=>setDistrictName(event.target.value)}/></Field>
      <Field label="State"><input value={stateName} onChange={(event)=>setStateName(event.target.value)}/></Field><Field label="PIN Code"><input value={pinCode} onChange={(event)=>setPinCode(event.target.value)}/></Field>
      <Field label="Applied RTS Capacity (kW)"><input type="number" min="0" step="0.001" value={appliedCapacityKw} onChange={(event)=>setAppliedCapacityKw(Number(event.target.value))}/></Field><Field label="Actual RTS Capacity To Be Installed (kW)"><input type="number" min="0" step="0.001" value={actualCapacityKw} onChange={(event)=>setActualCapacityKw(Number(event.target.value))}/></Field>
      <Field label="Project Cost"><input type="number" min="0" step="0.01" value={projectCost} onChange={(event)=>setProjectCost(Number(event.target.value))}/></Field><Field label="OEM Name *"><input required value={oemName} onChange={(event)=>setOemName(event.target.value)}/></Field>
      <Field label="Application Reference Number *"><input required value={applicationReferenceNumber} onChange={(event)=>setApplicationReferenceNumber(event.target.value)} placeholder="Enter application reference number"/></Field>
      <Field label="Jan Samarth ID (optional)"><input value={janSamarthId} onChange={(event)=>setJanSamarthId(event.target.value)} placeholder="Blank prints as __"/></Field>
      <Field label="DISCOM ID (optional)"><input value={discomId} onChange={(event)=>setDiscomId(event.target.value)} placeholder="Blank prints as __"/></Field>
    </div></section>{error&&<div className="alert alert--error">{error}</div>}<div className="modal__actions"><button type="button" className="btn" onClick={onClose}>Cancel</button><button className="btn btn--primary" disabled={saving}>{saving?'Saving...':isEditing?'Update & Download PDF':'Generate PDF & Create Project'}</button></div>
  </form></Modal>;
}

function QuoteForm({ initial, customers, onClose, onSave, saving }: { initial?: Quotation; customers: Customer[]; onClose: () => void; onSave: (q: Quotation) => Promise<void>; saving: boolean }) {
  const { data, addDealer } = useCrm();
  const visibleCustomers = data?.profile.role === 'dealer' ? customers.filter((c) => c.dealerId === data.profile.dealerId) : customers;
  const rows = useMemo(() => data?.priceRows ?? [], [data?.priceRows]);
  const initialSource = rows.find((row) => row.id === initial?.priceSnapshot?.priceRowId)
    ?? rows.find((row) => upper(row.panelBrand) === upper(initial?.panelBrand ?? '') && row.panelTechnology === initial?.panelTechnology && row.panelQuantity === initial?.panelQuantity && (initial?.panelWattage ?? 0) >= (row.panelWattageMin ?? row.panelWattage) && (initial?.panelWattage ?? 0) <= (row.panelWattageMax ?? row.panelWattage))
    ?? rows.find((row) => upper(row.panelBrand) === 'WAAREE' && row.panelTechnology === 'Bifacial' && row.panelWattage === 540 && row.panelQuantity === 6)
    ?? rows[0];
  const [quoteNo, setQuoteNo] = useState(initial?.quoteNo ?? ''); const [customerId, setCustomerId] = useState(initial?.customerId ?? visibleCustomers[0]?.id ?? ''); const [systemType, setSystemType] = useState<Quotation['systemType']>(initial?.systemType ?? 'On-grid'); const [dcrType, setDcrType] = useState<Quotation['dcrType']>(initial?.dcrType ?? 'DCR');
  const [configurationMode, setConfigurationMode] = useState<Quotation['configurationMode']>(initial?.configurationMode ?? 'automatic');
  const [tech, setTech] = useState<Quotation['panelTechnology']>(initial?.panelTechnology ?? initialSource?.panelTechnology ?? 'Bifacial'); const [brand, setBrand] = useState(initial?.panelBrand ?? initialSource?.panelBrand ?? 'WAAREE'); const [wattage, setWattage] = useState(initial?.panelWattage ?? initialSource?.panelWattageMin ?? initialSource?.panelWattage ?? 540); const [requestedCapacityKw, setRequestedCapacityKw] = useState(initial?.dcCapacityKw ?? initialSource?.capacityKw ?? 3.24); const [qty, setQty] = useState(initial?.panelQuantity ?? initialSource?.panelQuantity ?? 6); const [capacityKw, setCapacityKw] = useState(initial?.dcCapacityKw ?? exactCapacityKw(initial?.panelWattage ?? initialSource?.panelWattage ?? 540, initial?.panelQuantity ?? initialSource?.panelQuantity ?? 6)); const [configurationReason, setConfigurationReason] = useState(initial?.configurationOverrideReason ?? '');
  const [inverterBrand, setInverterBrand] = useState(initial?.inverterBrand ?? 'Polycab'); const [inverterModel, setInverterModel] = useState(initial?.inverterModel ?? ''); const [inverterKw, setInverterKw] = useState(initial?.inverterCapacityKw ?? 3); const [structureType, setStructureType] = useState(initial?.structureType ?? 'Hot Dip Galvanized');
  const [autoBom, setAutoBom] = useState(!initial || initial.configurationMode !== 'manual'); const [items, setItems] = useState<QuoteItem[]>(initial?.items ?? standardItems(brand, tech, initial?.panelWattageLabel ?? `${wattage} Wp`, qty));
  const [baseEpcPrice, setBaseEpcPrice] = useState(initial?.loanBasePrice ?? initial?.suggestedPrice ?? initialSource?.price ?? 0); const [loanRequired, setLoanRequired] = useState(initial?.loanRequired ?? false); const [loanPercent, setLoanPercent] = useState(initial?.loanGrossUpPercent ?? 10); const [loanFileCharge, setLoanFileCharge] = useState(initial?.loanFileCharge ?? 2000); const loanCalculation = calculateLoanCustomerPrice(baseEpcPrice, loanPercent, loanFileCharge);
  const calculatedCustomerPrice = loanRequired ? loanCalculation.total : Math.round(baseEpcPrice); const [finalOverride, setFinalOverride] = useState<number | null>(initial?.grandTotal ?? null); const finalPrice = finalOverride ?? calculatedCustomerPrice; const [overrideReason, setOverrideReason] = useState(initial?.priceOverrideReason ?? '');
  const [paymentTerms, setPaymentTerms] = useState(initial?.paymentTerms ?? data?.settings.paymentTerms ?? ''); const [warrantyTerms, setWarrantyTerms] = useState(initial?.warrantyTerms ?? data?.settings.warrantyTerms ?? ''); const [validityDays, setValidityDays] = useState(initial?.validityDays ?? data?.settings.quotationValidityDays ?? 15); const [notes, setNotes] = useState(cleanQuotationNotes(initial?.notes ?? data?.settings.quotationNotes ?? ''));
  const [dealerChoice, setDealerChoice] = useState(initial?.dealerId ?? ''); const [manualDealerName, setManualDealerName] = useState(initial?.manualDealerName ?? ''); const [manualDealerMobile, setManualDealerMobile] = useState(''); const [manualDealerAddress, setManualDealerAddress] = useState(''); const [commissionValue, setCommissionValue] = useState(initial?.dealerCommission ?? 0);
  const brands = [...new Set(rows.map((row) => row.panelBrand))].sort();
  const technologies = [...new Set(rows.filter((row) => upper(row.panelBrand) === upper(brand)).map((row) => row.panelTechnology))];
  const wattages = wattagesForPriceRows(rows, brand, tech);
  const sourcePrice = useMemo(() => resolveOfficialPriceRow(rows, brand, tech, wattage, requestedCapacityKw, configurationMode === 'manual' ? qty : undefined), [brand, configurationMode, qty, requestedCapacityKw, rows, tech, wattage]);
  const sourceSelectionKey = sourcePrice ? `${sourcePrice.id}:${wattage}:${sourcePrice.panelQuantity}` : '';
  const lastAppliedSource = useRef(initial ? sourceSelectionKey : '');
  useEffect(() => {
    if (!sourcePrice) return;
    if (configurationMode === 'automatic') {
      setQty(sourcePrice.panelQuantity);
      setCapacityKw(exactCapacityKw(wattage, sourcePrice.panelQuantity));
    }
    if (lastAppliedSource.current !== sourceSelectionKey) {
      setBaseEpcPrice(sourcePrice.price);
      setFinalOverride(null);
      setConfigurationReason('');
      lastAppliedSource.current = sourceSelectionKey;
    }
  }, [configurationMode, sourcePrice, sourceSelectionKey, wattage]);
  const customer = visibleCustomers.find((c) => c.id === customerId); const sourceSuggested = sourcePrice?.price ?? initial?.suggestedPrice ?? 0;
  const calc = calculateQuote({ panelWattage: wattage, panelQuantity: qty, basePrice: finalPrice, extraItems: [], discount: 0, taxMode: 'inclusive', taxRate: initial?.taxRate ?? 0 });
  const sourceMinimum = sourcePrice?.panelWattageMin ?? sourcePrice?.panelWattage ?? 0; const sourceMaximum = sourcePrice?.panelWattageMax ?? sourcePrice?.panelWattage ?? 0;
  const configurationChanged = Boolean(sourcePrice && (upper(brand) !== upper(sourcePrice.panelBrand) || tech !== sourcePrice.panelTechnology || wattage < sourceMinimum || wattage > sourceMaximum || qty !== sourcePrice.panelQuantity || Math.abs(capacityKw - exactCapacityKw(wattage, qty)) > 0.0005));
  const priceChanged = Math.abs(finalPrice - sourceSuggested) > 0.005;
  const effectiveOverrideReason = overrideReason.trim() || (loanRequired ? `Loan quotation: ${loanPercent}% gross-up and ${formatInr(loanFileCharge)} file charge.` : '');
  const configurationValid = !configurationChanged || Boolean(configurationReason.trim()); const commercialValid = !priceChanged || Boolean(effectiveOverrideReason);

  const selectBrand = (nextBrand: string) => {
    setBrand(nextBrand); const nextTechnology = rows.find((row) => upper(row.panelBrand) === upper(nextBrand))?.panelTechnology ?? tech; setTech(nextTechnology);
    const nextWattage = wattagesForPriceRows(rows, nextBrand, nextTechnology)[0]; if (nextWattage) setWattage(nextWattage);
  };
  const selectTechnology = (nextTechnology: Quotation['panelTechnology']) => { setTech(nextTechnology); const nextWattage = wattagesForPriceRows(rows, brand, nextTechnology)[0]; if (nextWattage) setWattage(nextWattage); };
  const manualItemChange = (index: number, patch: Partial<QuoteItem>) => { setAutoBom(false); setItems((current) => current.map((item, itemIndex) => itemIndex === index ? { ...item, ...patch } : item)); };

  const submit = async (event: React.FormEvent) => {
    event.preventDefault(); if (!customer || !sourcePrice || !configurationValid || !commercialValid || qty <= 0 || capacityKw <= 0) return;
    const wattageLabel = `${wattage} Wp`;
    const structure = sourceStructure[qty];
    const normalizedItems = autoBom ? items.map((item) => item.description === 'PV Module'
      ? { ...item, brand, specification: `${wattageLabel} ${tech}`, quantity: qty, unit: 'Nos' }
      : item.description === 'Grid Tie Inverter'
        ? { ...item, brand: inverterBrand, specification: `${inverterModel} ${inverterKw} kW`.trim() }
        : item.description === 'Mounting Structure' && structure
          ? { ...item, brand: structureType, specification: `${structure.pipe60} x 60x40 legs/rafters and ${structure.pipe40} x 40x40 purlins` }
          : item) : items;
    let resolvedDealerId = dealerChoice && dealerChoice !== '__manual__' ? dealerChoice : '';
    if (dealerChoice === '__manual__') {
      const dealerId = crypto.randomUUID(); const districtId = data?.districts.find((district) => district.name === customer.district)?.id ?? data?.profile.districtId ?? '';
      const manualDealer: Dealer = { id: dealerId, dealerNo: '', name: manualDealerName.trim(), mobile: manualDealerMobile.replace(/\D/g,''), address: manualDealerAddress.trim() || customer.address, districtId: districtId || undefined, district: customer.district, commissionType: 'fixed', commissionValue, active: true };
      await addDealer(manualDealer); resolvedDealerId = dealerId;
    }
    await onSave({ id: initial?.id ?? crypto.randomUUID(), quoteNo: quoteNo.trim(), customerId, versionNo: initial?.versionNo ?? 1, status: initial?.status ?? 'draft', systemType, dcrType, scheme: 'PM Surya Ghar', panelTechnology: tech, panelBrand: upper(brand), panelWattage: wattage, panelWattageLabel: wattageLabel, panelQuantity: qty, dcCapacityKw: capacityKw, configurationMode, configurationOverrideReason: configurationChanged ? configurationReason.trim() : '', inverterBrand: inverterBrand.trim(), inverterModel: inverterModel.trim(), inverterCapacityKw: inverterKw, structureType, items: normalizedItems, suggestedPrice: sourceSuggested, priceOverrideReason: priceChanged ? effectiveOverrideReason : '', basePrice: finalPrice, discount: 0, taxMode: 'inclusive', taxRate: initial?.taxRate ?? 0, taxableValue: calc.taxableValue, taxAmount: calc.taxAmount, roundOff: calc.roundOff, grandTotal: finalPrice, loanRequired, loanBasePrice: baseEpcPrice, loanGrossUpPercent: loanRequired ? loanPercent : 0, loanGrossUpAmount: loanRequired ? loanCalculation.grossUpAmount : 0, loanFileCharge: loanRequired ? loanFileCharge : 0, subsidy: standardInformationalSubsidy(), dealerId: resolvedDealerId || null, manualDealerName: dealerChoice === '__manual__' ? manualDealerName.trim() : undefined, dealerCommission: resolvedDealerId ? commissionValue : 0, internalCost: initial?.internalCost ?? 0, paymentTerms, warrantyTerms, validityDays, notes, createdAt: initial?.createdAt ?? new Date().toISOString(), approvedAt: initial?.approvedAt, sentAt: initial?.sentAt, rejectedAt: initial?.rejectedAt, priceSnapshot: { priceRowId: sourcePrice.id, technology: sourcePrice.panelTechnology, brand: sourcePrice.panelBrand, wattage: sourcePrice.panelWattage, wattageLabel: sourcePrice.panelWattageLabel, panelQuantity: sourcePrice.panelQuantity, capacityKw: sourcePrice.capacityKw, quotedTechnology: tech, quotedBrand: upper(brand), quotedWattage: wattage, quotedPanelQuantity: qty, quotedCapacityKw: capacityKw, suggestedPrice: sourceSuggested, finalPrice, gstIncluded: true, sourceDocument: sourcePrice.sourceDocument, capturedAt: new Date().toISOString() } });
  };

  return <Modal title={initial ? `Quotation Revision ${initial.versionNo}` : 'New Quotation'} onClose={onClose} wide><form onSubmit={submit}>
    <section className="form-section"><div className="card__title"><div><h3>Customer and quotation</h3><p>The customer address is printed directly; no separate quotation territory is required.</p></div></div><div className="form-grid">
      <Field label="Quotation Number (editable)"><input value={quoteNo} readOnly={Boolean(initial?.quoteNo)} onChange={(e)=>setQuoteNo(e.target.value)} placeholder={data ? `${data.settings.quotationNumbering.prefix}${String(data.settings.quotationNumbering.nextNumber).padStart(data.settings.quotationNumbering.padding,'0')} (automatic if blank)` : 'Automatic if blank'} /></Field><Field label="Customer"><select required value={customerId} onChange={(e) => setCustomerId(e.target.value)}>{visibleCustomers.map((entry) => <option value={entry.id} key={entry.id}>{entry.fullName} · {entry.mobile} · {entry.address}</option>)}</select></Field><Field label="System Type"><select value={systemType} onChange={(e) => setSystemType(e.target.value as Quotation['systemType'])}>{['On-grid','Off-grid','Hybrid'].map((entry) => <option key={entry}>{entry}</option>)}</select></Field><Field label="DCR / Non-DCR"><select value={dcrType} onChange={(e) => setDcrType(e.target.value as Quotation['dcrType'])}><option>DCR</option><option>Non-DCR</option></select></Field>
    </div></section>
    <section className="form-section"><div className="card__title"><div><h3>Solar system configuration</h3><p>Select the panel and enter the required kW. The closest official panel-count row and its GST-inclusive price are matched automatically.</p></div><div className="segmented"><button type="button" className={configurationMode==='automatic'?'active':''} onClick={()=>setConfigurationMode('automatic')}>Auto Match</button><button type="button" className={configurationMode==='manual'?'active':''} onClick={()=>setConfigurationMode('manual')}>Manual Edit</button></div></div><div className="form-grid">
      <Field label="Panel Brand"><select value={brand} onChange={(event)=>selectBrand(event.target.value)}>{brands.map((entry)=><option key={entry}>{entry}</option>)}</select></Field>
      <Field label="Panel Technology"><select value={tech} onChange={(event)=>selectTechnology(event.target.value as Quotation['panelTechnology'])}>{technologies.map((entry)=><option key={entry}>{entry}</option>)}</select></Field>
      <Field label="Panel Wattage"><select value={wattage} onChange={(event)=>setWattage(Number(event.target.value))}>{wattages.map((entry)=><option key={entry} value={entry}>{entry} Wp</option>)}</select><small>Only wattages verified in the attached official price lists are available.</small></Field>
      <Field label="Required Capacity (kW)"><input required type="number" min="0.001" step="0.001" value={requestedCapacityKw} onChange={(event)=>setRequestedCapacityKw(Number(event.target.value))}/><small>Example: 3.27 kW is matched to the nearest valid panel quantity.</small></Field>
      <Field label="Panel Quantity"><input readOnly={configurationMode==='automatic'} required type="number" min="1" value={qty} onChange={(event)=>{const next=Number(event.target.value);setQty(next);setCapacityKw(exactCapacityKw(wattage,next));}}/></Field><Field label="Exact Resulting DC Capacity (kW)"><input readOnly={configurationMode==='automatic'} required type="number" min="0.001" step="0.001" value={capacityKw} onChange={(event)=>setCapacityKw(Number(event.target.value))}/><small>This exact capacity is printed on the quotation.</small></Field>
      {configurationChanged&&<Field label="Configuration Edit Reason"><textarea required value={configurationReason} onChange={(event)=>setConfigurationReason(event.target.value)} placeholder="Reason for changing the verified source configuration"/></Field>}
      <Field label="Inverter Brand"><input list="inverter-brands" required value={inverterBrand} onChange={(event)=>setInverterBrand(event.target.value)}/><datalist id="inverter-brands">{['KSOLE','Solaryan','Suryyan','Polycab'].map((entry)=><option key={entry} value={entry}/>)}</datalist></Field><Field label="Inverter Model"><input value={inverterModel} onChange={(event)=>setInverterModel(event.target.value)}/></Field><Field label="Inverter Capacity (kW)"><input required type="number" min="0.1" step="0.1" value={inverterKw} onChange={(event)=>setInverterKw(Number(event.target.value))}/></Field><Field label="Structure Type"><input value={structureType} onChange={(event)=>setStructureType(event.target.value)}/></Field>
    </div>{sourcePrice&&<div className="alert alert--info">Official price matched internally: {sourcePrice.panelQuantity} panels · {exactCapacityKw(wattage,sourcePrice.panelQuantity).toFixed(3)} kW exact capacity. The source-file reference is kept only in the audit snapshot.</div>}</section>
    <section className="form-section"><div className="card__title"><div><h3>Commercials and optional loan</h3><p>The subsidy section is printed separately and does not alter this quoted total.</p></div></div><div className="form-grid">
      <Field label="Suggested Price (GST included)"><input readOnly value={sourceSuggested}/></Field><Field label="Base EPC Price (editable)"><input required type="number" min="1" value={baseEpcPrice} onChange={(event)=>{setBaseEpcPrice(Number(event.target.value));setFinalOverride(null);}}/></Field><Field label="Loan Required"><select value={loanRequired?'yes':'no'} onChange={(event)=>{setLoanRequired(event.target.value==='yes');setFinalOverride(null);}}><option value="no">No - Normal Quotation</option><option value="yes">Yes - Loan Quotation</option></select></Field>
      {loanRequired&&<><Field label="Loan Gross-up Percentage"><input type="number" min="0" max="99.99" step="0.01" value={loanPercent} onChange={(event)=>{setLoanPercent(Number(event.target.value));setFinalOverride(null);}}/></Field><Field label="Loan File Charge"><input type="number" min="0" value={loanFileCharge} onChange={(event)=>{setLoanFileCharge(Number(event.target.value));setFinalOverride(null);}}/></Field><Field label="Calculated Financed EPC Price"><input readOnly value={loanCalculation.financedEpcPrice}/><small>{formatInr(baseEpcPrice)} ÷ (1 - {loanPercent}%)</small></Field><Field label="Loan Gross-up Amount"><input readOnly value={loanCalculation.grossUpAmount}/></Field></>}
      <Field label="Final Customer Price (editable, GST included)"><input required type="number" min="1" value={finalPrice} onChange={(event)=>setFinalOverride(Number(event.target.value))}/></Field>{priceChanged&&!loanRequired&&<Field label="Price Override Reason"><textarea required value={overrideReason} onChange={(event)=>setOverrideReason(event.target.value)}/></Field>}
      {data?.profile.role !== 'dealer'&&<><Field label="Dealer (optional)"><select value={dealerChoice} onChange={(event)=>setDealerChoice(event.target.value)}><option value="">No dealer</option>{data?.dealers.map((dealer)=><option value={dealer.id} key={dealer.id}>{dealer.name}</option>)}<option value="__manual__">+ Add dealer manually</option></select></Field>{dealerChoice==='__manual__'&&<><Field label="Manual Dealer Name"><input required value={manualDealerName} onChange={(event)=>setManualDealerName(event.target.value)}/></Field><Field label="Dealer Mobile"><input required inputMode="numeric" minLength={10} value={manualDealerMobile} onChange={(event)=>setManualDealerMobile(event.target.value.replace(/\D/g,'').slice(0,10))}/></Field><Field label="Dealer Address"><input value={manualDealerAddress} onChange={(event)=>setManualDealerAddress(event.target.value)}/></Field></>}{dealerChoice&&<Field label="Dealer Commission Amount (fixed)"><input type="number" min="0" value={commissionValue} onChange={(event)=>setCommissionValue(Number(event.target.value))}/></Field>}</>}
      <Field label="Validity (days)"><input type="number" min="1" value={validityDays} onChange={(event)=>setValidityDays(Number(event.target.value))}/></Field><Field label="Payment Terms"><textarea value={paymentTerms} onChange={(event)=>setPaymentTerms(event.target.value)}/></Field><Field label="Warranty Terms"><textarea value={warrantyTerms} onChange={(event)=>setWarrantyTerms(event.target.value)}/></Field><Field label="Notes"><textarea value={notes} onChange={(event)=>setNotes(event.target.value)}/></Field>
    </div></section>
    <section className="form-section"><div className="card__title"><div><h3>Customer-facing Bill of Materials</h3><p>Rows are generated automatically. Editing any row turns off automatic BOM synchronisation.</p></div><div className="row-actions"><label className="switch-line"><input type="checkbox" checked={autoBom} onChange={(event)=>setAutoBom(event.target.checked)}/> Auto-sync</label><button type="button" className="btn btn--small" onClick={() => {setAutoBom(false);setItems((current)=>[...current,{id:crypto.randomUUID(),description:'Additional Item',quantity:1,unit:'Lot',rate:0,taxRate:0,selected:true}]);}}><Plus size={14}/> Add Item</button></div></div>{items.map((item,index)=><div className="bom-editor" key={item.id}><input aria-label="Include item" type="checkbox" checked={item.selected} onChange={(event)=>manualItemChange(index,{selected:event.target.checked})}/><input aria-label="Description" value={item.description} onChange={(event)=>manualItemChange(index,{description:event.target.value})}/><input aria-label="Brand" value={item.brand??''} placeholder="Brand" onChange={(event)=>manualItemChange(index,{brand:event.target.value})}/><input aria-label="Specification" value={item.specification??''} placeholder="Specification" onChange={(event)=>manualItemChange(index,{specification:event.target.value})}/><input aria-label="Quantity" type="number" min="0.001" step="0.001" value={item.quantity} onChange={(event)=>manualItemChange(index,{quantity:Number(event.target.value)})}/><input aria-label="Unit" value={item.unit} onChange={(event)=>manualItemChange(index,{unit:event.target.value})}/><button type="button" className="icon-btn bad" title="Remove material row" onClick={()=>{setAutoBom(false);setItems((current)=>current.filter((_,itemIndex)=>itemIndex!==index));}}><Trash2 size={15}/></button></div>)}</section>
    {!sourcePrice&&<div className="alert alert--error">No official active price exists for this brand, technology and wattage.</div>}{!configurationValid&&<div className="alert alert--error">Enter a reason for the manual system configuration.</div>}{!commercialValid&&<div className="alert alert--error">Enter a reason for the price override.</div>}<div className="quote-total"><span>{loanRequired?`Loan: ${formatInr(baseEpcPrice)} + ${formatInr(loanCalculation.grossUpAmount)} gross-up + ${formatInr(loanFileCharge)} file charge`:'GST included'}</span><strong>Gross Total {formatInr(finalPrice)}</strong></div><div className="form-actions"><button type="button" className="btn" onClick={onClose}>Cancel</button><button disabled={saving||!sourcePrice||!configurationValid||!commercialValid||(dealerChoice==='__manual__'&&(!manualDealerName.trim()||manualDealerMobile.length!==10))} className="btn btn--primary">{saving?'Saving...':'Save Quotation'}</button></div>
  </form></Modal>;
}
