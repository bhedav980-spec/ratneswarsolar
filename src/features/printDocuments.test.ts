import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

describe('clean printable documents', () => {
  const quotation = readFileSync('src/features/QuotationPrint.tsx', 'utf8');
  const invoice = readFileSync('src/features/InvoicePrint.tsx', 'utf8');
  const styles = readFileSync('src/styles.css', 'utf8');
  const engine = readFileSync('src/lib/printDocument.ts', 'utf8');
  const invoiceEngine = readFileSync('src/lib/invoicePdf.ts', 'utf8');
  const quotationEngine = readFileSync('src/lib/quotationPdf.ts', 'utf8');
  const projectFeature = readFileSync('src/features/Projects.tsx', 'utf8');
  const invoiceSignatureMigration = readFileSync('supabase/migrations/202608070022_invoice_signature_preference.sql', 'utf8');

  it('uses clean PDF generation instead of browser page printing', () => {
    expect(quotation).not.toContain('window.print');
    expect(invoice).not.toContain('window.print');
    expect(engine).toContain("format: 'a4'");
    expect(engine).toContain('outputPdf');
    expect(invoiceEngine).toContain("format: 'a4'");
    expect(invoiceEngine).toContain("doc.text('Tax Invoice'");
    expect(invoiceEngine).toContain("['Place of Supply', invoice.placeOfSupply");
    expect(invoiceEngine).not.toContain("['GST Treatment'");
    expect(invoiceEngine).not.toContain("doc.text('1 Job'");
    expect(invoiceEngine).not.toContain("SGST/UTGST");
    expect(invoiceEngine).not.toContain("${invoice.invoiceNo} | ${project.projectNo} | ${customer.customerNo}");
    expect(quotationEngine).toContain("format:'a4'");
    expect(quotationEngine).toContain("doc.addPage('a4','portrait')");
  });

  it('keeps quotation and invoice content in A4 document shells', () => {
    expect(styles).toContain('.a4-document { width: 210mm; min-height: 297mm;');
    expect(quotation).toContain('Grand Total:');
    expect(quotation).not.toContain('Grand Total (Including GST)');
    expect(invoice).toContain('Panel Serial Nos.');
    expect(invoice).not.toContain('Tax Invoice (Annexure)');
    expect(invoice).toContain('<label>Place of Supply</label><strong>{invoice.placeOfSupply}</strong>');
    expect(invoice).toContain("<label>Destination</label><strong>-</strong>");
    expect(invoice).not.toContain('<label>GST Treatment</label>');
    expect(invoice).not.toContain('tally-col-rate');
    expect(invoice).not.toContain('tally-col-per');
    expect(invoice).not.toContain('1 Job');
    expect(invoice).not.toContain('SGST/UTGST');
    expect(quotation).toContain('word-quote-page');
    expect(invoice).toContain('rs-reference-document invoice-document');
    expect(invoice).toContain('no dashboard, browser URL, date/time header or controls');
  });

  it('prints a fixed two-page quotation and separate invoice GST lines', () => {
    expect(quotation).toContain('SYSTEM BILL OF MATERIALS (BOM)');
    expect(quotation).toContain('Online Monitoring System');
    expect(quotationEngine).toContain("drawPageOne(doc,input,logo);doc.addPage('a4','portrait');drawPageTwo(doc,input,logo,signature)");
    expect(quotationEngine).toContain("ratneswar-authorised-signature.png");
    expect(invoice).toContain("line.lineType==='supply'");
    expect(invoiceEngine).toContain('line.gstRate/2');
    expect(invoiceEngine).toContain('splitLines.forEach');
    expect(quotation).toContain('Total Subsidy');
    expect(quotation).not.toContain('INFORMATIONAL ONLY');
    expect(quotation).not.toContain('Subject to authority approval');
    expect(quotation).not.toContain('Loan Commercials');
    expect(quotationEngine).not.toContain('Loan Commercials');
    expect(quotationEngine).not.toContain('Total Informational Subsidy');
    expect(quotationEngine).not.toContain('not deducted from this quotation value');
  });

  it('defaults invoice generation to the exact feasibility signature and preserves the selected choice', () => {
    expect(projectFeature).toContain('includeSignature:true');
    expect(projectFeature).toContain('With Digital Stamp &amp; Signature');
    expect(projectFeature).toContain('Without Signature');
    expect(invoice).toContain("invoice.includeSignature!==false");
    expect(invoiceEngine).toContain("imageData('/brand/ratneswar-authorised-signature.png')");
    expect(invoiceEngine).toContain("invoice.includeSignature!==false");
    expect(invoiceEngine).toContain("114,bottomTop+28.3,35,27.45");
    expect(styles).toContain("width:35mm; height:27.45mm");
    expect(invoiceSignatureMigration).toContain("'{includeSignature}'");
    expect(invoiceSignatureMigration).toContain("details->>'includeSignature'");
  });
});
