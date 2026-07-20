import { useState } from 'react';
import { Eye, FilePlus2 } from 'lucide-react';
import { Empty, PageHeader, Status } from '../components/Ui';
import { useCrm } from '../lib/CrmContext';
import { formatDate, formatInr } from '../services/calculations';
import type { Invoice, Project } from '../types/domain';
import { InvoicePrint } from './InvoicePrint';
import { canIssueInvoice, InstallationForm } from './Projects';

export function Invoices() {
  const { data } = useCrm();
  const [preview, setPreview] = useState<{ invoice: Invoice; project: Project } | null>(null);
  const [issuing, setIssuing] = useState<Project | null>(null);
  if (!data || data.profile.role === 'dealer') return <Empty title="Access denied" detail="Dealers cannot access tax invoices." />;
  return <>
    <PageHeader title="Invoices" subtitle="Generate installation-linked tax invoices and open a clean A4 printable copy." />
    <section className="card table-card">{data.projects.length ? <table><thead><tr><th>Project</th><th>Customer</th><th>Capacity</th><th>Project Value</th><th>Invoice</th><th>Action</th></tr></thead><tbody>{data.projects.map((project) => {
      const customer = data.customers.find((item) => item.id === project.customerId);
      const invoice = data.invoices.find((item) => item.projectId === project.id && item.status !== 'cancelled');
      return <tr key={project.id}><td><strong>{project.projectNo}</strong><small>{project.stage.replaceAll('_', ' ')}</small></td><td><strong>{customer?.fullName ?? 'Missing customer'}</strong><small>{customer?.mobile}</small></td><td>{project.acceptedQuoteSnapshot.dcCapacityKw.toFixed(3)} kW<small>{project.acceptedQuoteSnapshot.panelBrand} {project.acceptedQuoteSnapshot.panelTechnology}</small></td><td><strong>{formatInr(project.acceptedQuoteSnapshot.grandTotal)}</strong><small>GST included</small></td><td>{invoice ? <Status tone="good">Issued {formatDate(invoice.invoiceDate)}</Status> : canIssueInvoice(project.stage) ? <Status tone="warn">Ready to issue</Status> : <Status tone="neutral">Waiting for installation</Status>}</td><td>{invoice && customer ? <button className="btn btn--small btn--primary" onClick={() => setPreview({ invoice, project })}><Eye size={14} /> View / Print Invoice</button> : <button className="btn btn--small btn--primary" disabled={!canIssueInvoice(project.stage)} onClick={() => setIssuing(project)}><FilePlus2 size={14} /> Generate Invoice</button>}</td></tr>;
    })}</tbody></table> : <Empty title="No projects" detail="An approved quotation creates a project. Invoicing becomes available after installation is completed." />}</section>
    {issuing && <InstallationForm project={issuing} onClose={() => setIssuing(null)} />}
    {preview && <InvoicePrint invoice={preview.invoice} project={preview.project} customer={data.customers.find((item) => item.id === preview.project.customerId)!} onClose={() => setPreview(null)} />}
  </>;
}
