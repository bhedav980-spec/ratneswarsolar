import { useState } from 'react';
import { Download, Printer } from 'lucide-react';
import { Modal } from '../components/Modal';
import { downloadVectorQuotationPdf, openVectorQuotationPdf } from '../lib/quotationPdf';
import { amountInWords, formatDate, formatInr } from '../services/calculations';
import type { Customer, Quotation } from '../types/domain';
import { useCrm } from '../lib/CrmContext';

type CopyType = 'customer' | 'internal';

const terms = (value: string) => value.split(/[;\n]+/).map((item) => item.trim()).filter(Boolean);

export function QuotationPrint({ quote, customer, onClose }: { quote: Quotation; customer: Customer; onClose: () => void }) {
  const [copyType, setCopyType] = useState<CopyType>('customer');
  const { data } = useCrm();
  const company = data!.settings.company; const bank = data!.settings.bank;
  const canSeeInternal = data?.profile.role !== 'dealer';
  const [busy, setBusy] = useState<'print'|'download'|''>('');
  const filename = `${quote.quoteNo.replace(/[^a-zA-Z0-9_-]/g, '-')}-quotation.pdf`;
  const visibleItems = quote.items.filter((item) => item.selected && (copyType === 'internal' || !item.internalOnly));
  const pdfInput = { quote, customer, settings: data!.settings, copyType };
  const run = async (mode: 'print'|'download') => {
    setBusy(mode);
    try { if (mode === 'print') await openVectorQuotationPdf(pdfInput, filename); else await downloadVectorQuotationPdf(pdfInput, filename); }
    finally { setBusy(''); }
  };
  const Header = () => <header className="word-quote-header"><div className="word-quote-credentials"><strong>G.S.T. No. {company.gstin}</strong><span>ELECTRICAL, MECHANICAL &amp; CIVIL CONTRACTOR</span></div><img src="/brand/ratneswar-wordmark.png" alt={company.tradeName}/></header>;
  const Footer = () => <footer className="word-quote-footer"><span>{company.address}</span><b>(M) {[company.mobilePrimary,company.mobileSecondary].filter(Boolean).join(' / ')} &nbsp;&nbsp; E-mail : {company.email}</b></footer>;

  return <Modal title="Quotation Preview" onClose={onClose} wide>
    <div className="print-controls no-print"><div className="segmented"><button className={copyType==='customer'?'active':''} onClick={()=>setCopyType('customer')}>Customer Copy</button>{canSeeInternal&&<button className={copyType==='internal'?'active':''} onClick={()=>setCopyType('internal')}>Internal Copy</button>}</div><div className="print-assurance">Exact two-page Word-reference layout · selectable A4 PDF</div><div className="pdf-actions"><button className="btn" disabled={Boolean(busy)} onClick={()=>void run('download')}><Download size={16}/>{busy==='download'?'Creating...':'Download PDF'}</button><button className="btn btn--primary" disabled={Boolean(busy)} onClick={()=>void run('print')}><Printer size={16}/>{busy==='print'?'Preparing...':'Print Clean PDF'}</button></div></div>
    <div className="print-preview-stage"><article className="pdf-document-stack word-quote-stack">
      <section className="a4-document pdf-page word-quote-page">
        <Header/><main className="word-quote-body word-quote-page-one">
          <div className="word-quote-number"><b>Quotation No.:</b><span>{quote.quoteNo}</span><b>Date:</b><span>{formatDate(quote.createdAt)}</span></div>
          <h1>QUOTATION</h1><section className="word-address-block"><h2>From,</h2><strong>{company.legalName}</strong><p>{company.address}</p><p>Mobile: +91 {company.mobilePrimary}</p><p>GSTIN: {company.gstin} | PAN: {company.pan}</p><h2>To,</h2><strong>{customer.fullName}</strong><p>{customer.address}{customer.villageCity?`, ${customer.villageCity}`:''}{customer.taluka?`, ${customer.taluka}`:''}{customer.district?`, Dist: ${customer.district}`:''}{customer.pinCode?` - ${customer.pinCode}`:''}</p><p>Contact: +91 {customer.mobile}</p></section>
          <h2 className="word-quote-subject">SUBJECT: {quote.dcCapacityKw.toFixed(2)} kW Rooftop Solar ({quote.scheme})</h2>
          <section><h2 className="word-section-title">DETAILS OF SUPPLY</h2><table className="word-supply-table"><thead><tr><th>Sr. No</th><th>Description of Goods</th><th>HSN Code</th><th>Qty</th><th>Unit Rate</th><th>Amount</th></tr></thead><tbody><tr><td>1</td><td><strong>Rooftop Solar System</strong> under {quote.scheme}</td><td>-</td><td>{quote.dcCapacityKw.toFixed(2)} kW</td><td>{formatInr(quote.grandTotal)}</td><td><strong>{formatInr(quote.grandTotal)}</strong></td></tr></tbody></table><div className="word-grand-total"><b>Grand Total (Including GST):</b><strong>{formatInr(quote.grandTotal)}</strong></div>{quote.loanRequired&&<div className="word-loan-summary"><b>Loan Commercials:</b><span>Base EPC {formatInr(quote.loanBasePrice??quote.grandTotal)} · Gross-up {quote.loanGrossUpPercent??10}%: {formatInr(quote.loanGrossUpAmount??0)} · File charge: {formatInr(quote.loanFileCharge??0)}</span></div>}</section>
          <section className="word-subsidy"><h2 className="word-section-title">SUBSIDY DETAILS (INFORMATIONAL ONLY)</h2><table><thead><tr><th>Sr. No</th><th>Description</th><th>Amount</th></tr></thead><tbody>{(quote.subsidy.referenceLines?.length?quote.subsidy.referenceLines:[{label:'Central Subsidy (Up to 2 kW)',amount:30000},{label:'Central Subsidy (Above 2 kW)',amount:18000},{label:'State Subsidy (Above 2 kW)',amount:30000},{label:'Agreement Charges',amount:350}]).map((line,index)=><tr key={line.label}><td>{index+1}</td><td>{line.label}</td><td>{formatInr(line.amount)}</td></tr>)}<tr><td></td><th>Total Informational Subsidy</th><th>{formatInr(quote.subsidy.total||78000)}</th></tr></tbody></table><small>Subject to authority approval. Subsidy does not reduce or change the quotation value.</small></section>
          <p className="word-net"><b>Net Amount Payable:</b> {formatInr(quote.grandTotal)}</p><p className="word-amount"><b>Amount in Words:</b> {amountInWords(quote.grandTotal)}</p>
        </main><Footer/>
      </section>
      <section className="a4-document pdf-page word-quote-page">
        <Header/><main className="word-quote-body word-quote-page-two">
          <section className="word-bank"><h2>BANK DETAILS</h2><strong>{bank.accountHolder}</strong><p><b>Bank Name :</b> {bank.bankName}</p><p><b>A/c No. :</b> {bank.accountNumber}</p><p><b>IFSC Code :</b> {bank.ifsc}</p><p><b>Branch :</b> {bank.branch}</p></section>
          <section className="word-payment"><h2>PAYMENT TERMS</h2><ul>{terms(quote.paymentTerms).map((term,index)=><li key={index}>{term}</li>)}</ul></section>
          <section className="word-bom"><h2>SYSTEM BILL OF MATERIALS (BOM)</h2><p><b>Project Capacity:</b> {quote.dcCapacityKw.toFixed(3)} kW</p><table><thead><tr><th>Sr.</th><th>Component</th><th>Brand / Model</th><th>Specification</th><th>Qty</th></tr></thead><tbody>{visibleItems.map((item,index)=><tr key={item.id}><td>{index+1}</td><td>{item.description==='Monitoring System'?'Online Monitoring System':item.description}</td><td>{item.brand||'-'}</td><td>{item.description==='Online Monitoring System'?'Mobile App + Remote Monitoring':item.specification||'-'}</td><td>{item.quantity} {item.unit}</td></tr>)}</tbody></table></section>
          {copyType==='internal'&&<section className="word-internal"><h2>INTERNAL COMMERCIALS - CONFIDENTIAL</h2><p>Suggested Price: <b>{formatInr(quote.suggestedPrice??quote.grandTotal)}</b> · Dealer Commission: <b>{formatInr(quote.dealerCommission??0)}</b> · Internal Cost: <b>{formatInr(quote.internalCost??0)}</b></p></section>}
          <section className="word-declaration"><h2>Declaration:</h2><p>We hereby declare that the information given above is true and correct to the best of our knowledge.</p><p><b>Validity of Quotation:</b> {quote.validityDays} Days from the date of issue.</p><div><strong>Authorised Signatory</strong><b>{company.legalName}</b><span>(Stamp &amp; Signature)</span></div></section>
        </main><Footer/>
      </section>
    </article></div>
  </Modal>;
}
