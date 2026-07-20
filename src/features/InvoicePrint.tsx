import { useState } from 'react';
import { Download, Printer } from 'lucide-react';
import { Modal } from '../components/Modal';
import { openVectorInvoicePdf, downloadVectorInvoicePdf } from '../lib/invoicePdf';
import { amountInWords, formatDate, formatInr } from '../services/calculations';
import type { Customer, Invoice, InvoiceTaxLine, Project } from '../types/domain';
import { useCrm } from '../lib/CrmContext';

export function InvoicePrint({ invoice, project, customer, onClose }: { invoice: Invoice; project: Project; customer: Customer; onClose: () => void }) {
  const { data } = useCrm();
  const company = data!.settings.company;
  const bank = data!.settings.bank;
  const quote = project.acceptedQuoteSnapshot;
  const materials = project.installationMaterials;
  const [busy, setBusy] = useState<'print'|'download'|''>('');
  const documentId = `invoice-document-${invoice.id.replace(/[^a-zA-Z0-9_-]/g, '')}`;
  const filename = `${invoice.invoiceNo.replace(/[^a-zA-Z0-9_-]/g, '-')}-tax-invoice.pdf`;
  const wattageLabel = quote.panelWattageLabel ?? `${quote.panelWattage} Wp`;
  const totalTax = invoice.cgst + invoice.sgst + invoice.igst;
  const taxLines: InvoiceTaxLine[] = invoice.taxLines?.length ? invoice.taxLines : [{ lineType:'supply', description:`Supply & Installation of ${quote.dcCapacityKw.toFixed(3)} kWp Rooftop Solar Power Plant`, hsnSac:data!.settings.defaultHsnSac, sharePercent:100, gstRate:invoice.taxableValue>0?Number((totalTax/invoice.taxableValue*100).toFixed(3)):0, grossAmount:invoice.grandTotal, taxableValue:invoice.taxableValue, cgst:invoice.cgst, sgst:invoice.sgst, igst:invoice.igst }];
  const approvedDate = quote.approvedAt ? formatDate(quote.approvedAt) : '-';
  const pdfInput = { invoice, project, customer, settings: data!.settings };

  const run = async (mode: 'print'|'download') => {
    setBusy(mode);
    try {
      if (mode === 'print') await openVectorInvoicePdf(pdfInput, filename);
      else await downloadVectorInvoicePdf(pdfInput, filename);
    } finally { setBusy(''); }
  };

  const title = (label: string) => <div className="tally-title-row"><strong>{label}</strong><em>(ORIGINAL FOR RECIPIENT)</em></div>;

  const partyAndInvoiceDetails = <section className="tally-party-meta">
    <div className="tally-party-column">
      <div className="tally-seller">
        <strong>{company.legalName}</strong>
        <span>{company.address}</span>
        <span>GSTIN/UIN: <b>{company.gstin}</b></span>
        <span>State Name: {company.state}, Code: {company.stateCode}</span>
        <span>E-Mail: {company.email}</span>
      </div>
      <div className="tally-buyer">
        <label>Buyer (Bill to)</label>
        <strong>{customer.fullName}</strong>
        <span>{customer.address}, {customer.villageCity}, {customer.district}{customer.pinCode ? ` - ${customer.pinCode}` : ''}</span>
        <span>Mobile: <b>{customer.mobile}</b></span>
        <span>Consumer No.: <b>{customer.consumerNumber || '-'}</b></span>
        <span>DISCOM: {customer.discom || '-'} · Category: {customer.customerType}</span>
        <span>State Name: {customer.state}, Code: {company.stateCode}</span>
        <span>Place of Supply: {invoice.placeOfSupply}</span>
      </div>
    </div>
    <div className="tally-meta-grid">
      <div><label>Invoice No.</label><strong>{invoice.invoiceNo}</strong></div><div><label>Dated</label><strong>{formatDate(invoice.invoiceDate)}</strong></div>
      <div><label>GST Treatment</label><strong>{invoice.taxMode==='exclusive'?`Added above quote · Base ${formatInr(invoice.quotedAmount??quote.grandTotal)}`:'Included in quotation total'}</strong></div><div><label>Mode/Terms of Payment</label><strong>{quote.paymentTerms || data!.settings.paymentTerms}</strong></div>
      <div><label>Reference No. & Date.</label><strong>{quote.quoteNo} · {approvedDate}</strong></div><div><label>Other References</label><strong>{project.projectNo}</strong></div>
      <div><label>Buyer's Consumer No.</label><strong>{customer.consumerNumber || '-'}</strong></div><div><label>Project Capacity</label><strong>{quote.dcCapacityKw.toFixed(3)} kWp</strong></div>
      <div><label>Dispatched through</label><strong>EPC Installation</strong></div><div><label>Destination</label><strong>{customer.villageCity}, {customer.district}</strong></div>
      <div className="tally-meta-wide"><label>Terms of Delivery</label><strong>Supply, installation and commissioning of rooftop solar power plant as per accepted quotation.</strong></div>
    </div>
  </section>;

  const footer = <footer className="tally-footer"><strong>SUBJECT TO {company.jurisdiction.toUpperCase()} JURISDICTION</strong><span>This is a Computer Generated Invoice</span></footer>;

  return <Modal title="Tax Invoice Preview" onClose={onClose} wide>
    <div className="print-controls no-print"><div className="print-assurance">Clean A4 PDF: only the invoice is exported - no dashboard, browser URL, date/time header or controls.</div><div className="pdf-actions"><button className="btn" disabled={Boolean(busy)} onClick={() => void run('download')}><Download size={16}/>{busy === 'download' ? 'Creating...' : 'Download PDF'}</button><button className="btn btn--primary" disabled={Boolean(busy)} onClick={() => void run('print')}><Printer size={16}/>{busy === 'print' ? 'Preparing...' : 'Print Clean PDF'}</button></div></div>
    <div className="print-preview-stage"><article id={documentId} className="pdf-document-stack">
      <section data-pdf-page className="a4-document pdf-page rs-reference-document invoice-document tally-invoice tally-invoice-primary">
        {title('Tax Invoice')}
        {partyAndInvoiceDetails}

        <table className="tally-items-table">
          <colgroup><col className="tally-col-sl"/><col className="tally-col-particulars"/><col className="tally-col-hsn"/><col className="tally-col-qty"/><col className="tally-col-rate"/><col className="tally-col-per"/><col className="tally-col-amount"/></colgroup>
          <thead><tr><th>Sl<br/><small>No.</small></th><th>Particulars</th><th>HSN/SAC</th><th>Quantity</th><th>Rate</th><th>per</th><th>Amount</th></tr></thead>
          <tbody>{taxLines.map((line,index)=><tr className="tally-main-item tally-split-item" key={line.lineType}><td>{index+1}</td><td><strong>{line.description}</strong>{line.lineType==='supply'&&<><span>{quote.panelQuantity} x {wattageLabel} {quote.panelBrand} {quote.panelTechnology} PV modules</span>{materials?.panelSerials.length?<span className="tally-panel-serials"><b>Panel Serial Nos.:</b> {materials.panelSerials.map((serial,serialIndex)=>`${serialIndex+1}. ${serial}`).join(', ')}</span>:null}<span>{quote.inverterBrand} {quote.inverterModel||''} {quote.inverterCapacityKw} kW inverter{materials?.inverterSerial?` · Serial No.: ${materials.inverterSerial}`:''}</span></>}</td><td>{line.hsnSac}</td><td>1 Job</td><td>{formatInr(line.taxableValue)}</td><td>Job</td><td><strong>{formatInr(line.taxableValue)}</strong></td></tr>)}
            {invoice.cgst > 0 && <tr className="tally-tax-line"><td></td><td><strong>CGST</strong></td><td></td><td></td><td></td><td></td><td><strong>{formatInr(invoice.cgst)}</strong></td></tr>}
            {invoice.sgst > 0 && <tr className="tally-tax-line"><td></td><td><strong>SGST</strong></td><td></td><td></td><td></td><td></td><td><strong>{formatInr(invoice.sgst)}</strong></td></tr>}
            {invoice.igst > 0 && <tr className="tally-tax-line"><td></td><td><strong>IGST</strong></td><td></td><td></td><td></td><td></td><td><strong>{formatInr(invoice.igst)}</strong></td></tr>}
          </tbody>
          <tfoot><tr><td colSpan={6}>Total</td><td>{formatInr(invoice.grandTotal)}</td></tr></tfoot>
        </table>

        <section className="tally-amount-words"><div><span>Amount Chargeable (in words)</span><em>E. & O.E</em></div><strong>INR {amountInWords(invoice.grandTotal)}</strong></section>

        {invoice.igst > 0 ? <table className="tally-tax-table"><thead><tr><th>HSN/SAC</th><th>Taxable Value</th><th>IGST Rate</th><th>IGST Amount</th><th>Total Tax Amount</th></tr></thead><tbody>{taxLines.map(line=><tr key={line.lineType}><td>{line.hsnSac}</td><td>{formatInr(line.taxableValue)}</td><td>{line.gstRate}%</td><td>{formatInr(line.igst)}</td><td>{formatInr(line.igst)}</td></tr>)}</tbody><tfoot><tr><td>Total</td><td>{formatInr(invoice.taxableValue)}</td><td></td><td>{formatInr(invoice.igst)}</td><td>{formatInr(totalTax)}</td></tr></tfoot></table> : <table className="tally-tax-table"><thead><tr><th rowSpan={2}>HSN/SAC</th><th rowSpan={2}>Taxable Value</th><th colSpan={2}>CGST</th><th colSpan={2}>SGST/UTGST</th><th rowSpan={2}>Total Tax Amount</th></tr><tr><th>Rate</th><th>Amount</th><th>Rate</th><th>Amount</th></tr></thead><tbody>{taxLines.map(line=><tr key={line.lineType}><td>{line.hsnSac}</td><td>{formatInr(line.taxableValue)}</td><td>{line.gstRate/2}%</td><td>{formatInr(line.cgst)}</td><td>{line.gstRate/2}%</td><td>{formatInr(line.sgst)}</td><td>{formatInr(line.cgst+line.sgst)}</td></tr>)}</tbody><tfoot><tr><td>Total</td><td>{formatInr(invoice.taxableValue)}</td><td></td><td>{formatInr(invoice.cgst)}</td><td></td><td>{formatInr(invoice.sgst)}</td><td>{formatInr(totalTax)}</td></tr></tfoot></table>}

        <p className="tally-tax-words">Tax Amount (in words): <strong>INR {amountInWords(totalTax)}</strong></p>
        <section className="tally-bottom-grid"><div className="tally-declaration"><p>Company's PAN: <strong>{company.pan}</strong></p><u>Declaration</u><span>We declare that this invoice shows the actual value of the goods and services described and that all particulars are true and correct.</span></div><div className="tally-bank-sign"><div><label>Company's Bank Details</label><span>Bank Name: <strong>{bank.bankName}</strong></span><span>A/c No.: <strong>{bank.accountNumber}</strong></span><span>Branch & IFS Code: <strong>{bank.branch} & {bank.ifsc}</strong></span></div><div className="tally-authorised">for {company.legalName}<strong>Authorised Signatory</strong></div></div></section>
        {footer}
      </section>

    </article></div>
  </Modal>;
}
