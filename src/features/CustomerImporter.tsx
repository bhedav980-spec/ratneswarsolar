import { useMemo, useState } from 'react';
import { FileSearch, FolderOpen, ShieldCheck, Upload, X } from 'lucide-react';
import { Empty, Field, PageHeader, Status } from '../components/Ui';
import { useCrm } from '../lib/CrmContext';
import { invokeAiImporter, uploadPrivateFile } from '../services/repository';
import { supabase } from '../lib/supabase';
import type { Customer, CustomerType } from '../types/domain';

type Evidence = { value: string | number | null; confidence: number; source: string };
type Extraction = { documentType: string; fields: Record<string, Evidence>; warnings?: string[] };

export function CustomerImporter() {
  const { data, saveCustomer, saving } = useCrm();
  const [files, setFiles] = useState<File[]>([]); const [busy, setBusy] = useState(false); const [error, setError] = useState('');
  const [extraction, setExtraction] = useState<Extraction | null>(null);
  const initial = useMemo(() => extraction ? toCustomer(extraction, data?.profile.districtName ?? '') : null, [data?.profile.districtName, extraction]);
  const [review, setReview] = useState<Partial<Customer> | null>(null);
  if (!data || !['admin', 'district_partner'].includes(data.profile.role)) return <Empty title="Access denied" detail="Customer document import is available to Admin and Area Partner users." />;
  const selected = review ?? initial;
  const addFiles = (incoming: FileList | null) => { if (!incoming) return; setFiles((current) => [...current, ...Array.from(incoming)].filter((file, index, all) => all.findIndex((x) => x.name === file.name && x.size === file.size) === index)); };
  const analyse = async () => {
    if (!files.length) return; setBusy(true); setError('');
    try { const result = await invokeAiImporter('customer', files); setExtraction(result.extraction as Extraction); setReview(null); }
    catch (e) { setError(e instanceof Error ? e.message : 'Document analysis failed. Manual customer creation remains available.'); }
    finally { setBusy(false); }
  };
  const create = async () => {
    if (!selected?.fullName || !selected.mobile || !selected.address || !selected.district) { setError('Name, mobile, address and district are required.'); return; }
    const customerId = selected.id ?? crypto.randomUUID();
    await saveCustomer({ ...selected, id: customerId, leadStatus: selected.leadStatus ?? 'New', state: selected.state ?? 'Gujarat', customerType: selected.customerType ?? 'Residential' });
    await Promise.all(files.map(async (file) => { const path=`${customerId}/${crypto.randomUUID()}-${safeName(file.name)}`; await uploadPrivateFile('customer-documents',path,file); const { error: documentError }=await supabase!.from('customer_documents').insert({ customer_id:customerId,document_type:'AI import source',file_name:file.name,storage_path:path,uploaded_by:data.profile.id }); if(documentError) throw new Error(documentError.message); }));
    setFiles([]); setExtraction(null); setReview(null);
  };
  return <>
    <PageHeader title="AI Customer Document Importer" subtitle="Extract customer information with field-level confidence and source evidence before creating a record." />
    <section className="card importer-drop"><Upload size={30} /><h2>Upload customer documents</h2><p>PDF, JPG, JPEG, PNG or one ZIP. Files remain subject to private storage policies.</p>
      <div className="row-actions"><label className="btn btn--primary"><Upload size={16} /> Select Files<input hidden type="file" multiple accept=".pdf,.jpg,.jpeg,.png,.zip" onChange={(e) => addFiles(e.target.files)} /></label>
        <label className="btn"><FolderOpen size={16} /> Select Folder<input hidden type="file" multiple accept=".pdf,.jpg,.jpeg,.png" {...({ webkitdirectory: '', directory: '' } as Record<string, string>)} onChange={(e) => addFiles(e.target.files)} /></label></div>
      {!!files.length && <div className="file-chips">{files.map((file) => <span key={`${file.name}-${file.size}`}>{file.name}<button aria-label={`Remove ${file.name}`} onClick={() => setFiles((v) => v.filter((x) => x !== file))}><X size={13} /></button></span>)}</div>}
      <button className="btn btn--primary" disabled={!files.length || busy} onClick={() => void analyse()}><FileSearch size={17} /> {busy ? 'Analysing documents...' : 'Analyse and Review'}</button>
      {error && <div className="alert alert--error">{error}</div>}
    </section>
    {extraction && selected && <section className="card"><div className="card__title"><div><h2>Review extracted customer</h2><p>Uncertain or missing values are left blank. Edit every field before confirmation.</p></div><Status tone="info">{extraction.documentType}</Status></div>
      <div className="form-grid">
        <EvidenceField label="Full Name" evidence={extraction.fields.fullName}><input required value={selected.fullName ?? ''} onChange={(e) => setReview({ ...selected, fullName: e.target.value })} /></EvidenceField>
        <EvidenceField label="Mobile" evidence={extraction.fields.mobile}><input required value={selected.mobile ?? ''} onChange={(e) => setReview({ ...selected, mobile: e.target.value.replace(/\D/g, '').slice(0, 10) })} /></EvidenceField>
        <EvidenceField label="Address" evidence={extraction.fields.address}><textarea required value={selected.address ?? ''} onChange={(e) => setReview({ ...selected, address: e.target.value })} /></EvidenceField>
        <EvidenceField label="Consumer Number" evidence={extraction.fields.consumerNumber}><input value={selected.consumerNumber ?? ''} onChange={(e) => setReview({ ...selected, consumerNumber: e.target.value })} /></EvidenceField>
        <EvidenceField label="DISCOM" evidence={extraction.fields.discom}><input value={selected.discom ?? ''} onChange={(e) => setReview({ ...selected, discom: e.target.value })} /></EvidenceField>
        <EvidenceField label="Sanctioned Load (kW)" evidence={extraction.fields.sanctionedLoadKw}><input type="number" value={selected.sanctionedLoadKw ?? ''} onChange={(e) => setReview({ ...selected, sanctionedLoadKw: Number(e.target.value) || undefined })} /></EvidenceField>
        <Field label="Area / Territory"><input required value={selected.district ?? ''} disabled={data.profile.role === 'district_partner'} onChange={(e) => setReview({ ...selected, district: e.target.value })} /></Field>
        <Field label="Customer Category"><select value={selected.customerType ?? 'Residential'} onChange={(e) => setReview({ ...selected, customerType: e.target.value as CustomerType })}>{['Residential','Commercial','Agricultural','Industrial','Institutional','RWA/GHS'].map((x) => <option key={x}>{x}</option>)}</select></Field>
      </div>
      {!!extraction.warnings?.length && <div className="alert alert--warn">{extraction.warnings.join(' ')}</div>}
      <div className="form-actions"><span className="privacy-note"><ShieldCheck size={16} /> Originals are saved in a private bucket after confirmation.</span><button className="btn btn--primary" disabled={saving} onClick={() => void create()}>{saving ? 'Creating Customer...' : 'Confirm and Create Customer'}</button></div>
    </section>}
  </>;
}

function EvidenceField({ label, evidence, children }: { label: string; evidence?: Evidence; children: React.ReactNode }) {
  const confidence = Math.round((evidence?.confidence ?? 0) * 100);
  return <Field label={label}>{children}<small className="evidence">Confidence {confidence}% · {evidence?.source || 'No source found'}</small></Field>;
}

function toCustomer(extraction: Extraction, district: string): Partial<Customer> {
  const value = (key: string) => { const field=extraction.fields[key]; return field && field.confidence >= 0.65 ? field.value : ''; };
  return { id: crypto.randomUUID(), fullName: String(value('fullName') || ''), mobile: String(value('mobile') || ''), address: String(value('address') || ''), villageCity: String(value('villageCity') || ''), district, state: 'Gujarat', customerType: 'Residential', discom: String(value('discom') || ''), consumerNumber: String(value('consumerNumber') || ''), sanctionedLoadKw: Number(value('sanctionedLoadKw')) || undefined, leadStatus: 'New' };
}
const safeName = (name: string) => name.replace(/[^a-zA-Z0-9._-]/g, '_');
