import type { jsPDF } from 'jspdf';
import { amountInWords, formatDate } from '../services/calculations';
import type { CrmSettings, Customer, Invoice, InvoiceTaxLine, Project } from '../types/domain';

interface InvoicePdfInput {
  invoice: Invoice;
  project: Project;
  customer: Customer;
  settings: CrmSettings;
}

const clean = (value: unknown) => String(value ?? '-')
  .replace(/[×]/g, 'x')
  .replace(/[·]/g, ' - ')
  .replace(/[–—]/g, '-')
  .replace(/[’]/g, "'")
  .replace(/[₹]/g, 'INR ')
  .replace(/[^\x20-\x7E]/g, ' ')
  .replace(/\s+/g, ' ')
  .trim();

const money = (value: number) => new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value || 0);

function invoiceLines(input: InvoicePdfInput): InvoiceTaxLine[] {
  const { invoice, project, settings } = input;
  const totalTax = invoice.cgst + invoice.sgst + invoice.igst;
  return invoice.taxLines?.length ? invoice.taxLines : [{ lineType:'supply', description:`Supply & Installation of ${project.acceptedQuoteSnapshot.dcCapacityKw.toFixed(3)} kWp Rooftop Solar Power Plant`, hsnSac:settings.defaultHsnSac, sharePercent:100, gstRate:invoice.taxableValue>0?Number((totalTax/invoice.taxableValue*100).toFixed(3)):0, grossAmount:invoice.grandTotal, taxableValue:invoice.taxableValue, cgst:invoice.cgst, sgst:invoice.sgst, igst:invoice.igst }];
}

function wrapped(doc: jsPDF, text: string, maxWidth: number) {
  return doc.splitTextToSize(clean(text), maxWidth) as string[];
}

function writeLines(doc: jsPDF, lines: string[], x: number, y: number, size = 7.5, style: 'normal'|'bold'|'italic' = 'normal', lineHeight = 3.2, align: 'left'|'right'|'center' = 'left') {
  doc.setFont('helvetica', style);
  doc.setFontSize(size);
  lines.forEach((line, index) => doc.text(line, x, y + index * lineHeight, { align }));
  return y + lines.length * lineHeight;
}

function labeledCell(doc: jsPDF, x: number, y: number, w: number, label: string, value: string) {
  doc.setFont('helvetica', 'normal'); doc.setFontSize(6.4); doc.text(clean(label), x + 1.2, y + 2.7);
  doc.setFont('helvetica', 'bold'); doc.setFontSize(7.4);
  const lines = wrapped(doc, value, w - 2.4).slice(0, 2);
  lines.forEach((line, index) => doc.text(line, x + 1.2, y + 6 + index * 2.8));
}

function drawPartyAndMeta(doc: jsPDF, input: InvoicePdfInput, top: number, height: number) {
  const { invoice, project, customer, settings } = input;
  const { company } = settings;
  const quote = project.acceptedQuoteSnapshot;
  const x = 10.5; const width = 189; const half = width / 2; const splitX = x + half;
  const sellerHeight = 25;
  doc.setLineWidth(.22); doc.rect(x, top, width, height); doc.line(splitX, top, splitX, top + height); doc.line(x, top + sellerHeight, splitX, top + sellerHeight);

  let y = top + 4;
  doc.setFont('helvetica', 'bold'); doc.setFontSize(9.2); doc.text(clean(company.legalName).toUpperCase(), x + 1.5, y);
  y += 3.2;
  y = writeLines(doc, wrapped(doc, company.address, half - 3), x + 1.5, y, 7.2, 'normal', 3);
  y = writeLines(doc, [`GSTIN/UIN: ${clean(company.gstin)}`, `State Name: ${clean(company.state)}, Code: ${clean(company.stateCode)}`, `E-Mail: ${clean(company.email)}`], x + 1.5, y, 7.1, 'normal', 3);

  const buyerTop = top + sellerHeight;
  doc.setFont('helvetica', 'normal'); doc.setFontSize(6.8); doc.text('Buyer (Bill to)', x + 1.5, buyerTop + 3);
  doc.setFont('helvetica', 'bold'); doc.setFontSize(8.8); doc.text(clean(customer.fullName).toUpperCase(), x + 1.5, buyerTop + 7);
  let buyerY = buyerTop + 10.5;
  buyerY = writeLines(doc, wrapped(doc, `${customer.address}, ${customer.villageCity}, ${customer.district}${customer.pinCode ? ` - ${customer.pinCode}` : ''}`, half - 3), x + 1.5, buyerY, 7.2, 'normal', 3);
  const buyerLines = [
    `Mobile: ${customer.mobile}`,
    `Consumer No.: ${customer.consumerNumber || '-'}`,
    `DISCOM: ${customer.discom || '-'} | Category: ${customer.customerType}`,
    `State Name: ${customer.state}, Code: ${company.stateCode}`,
    `Place of Supply: ${invoice.placeOfSupply}`,
  ];
  writeLines(doc, buyerLines.map(clean), x + 1.5, buyerY, 7.1, 'normal', 3);

  const rightX = splitX; const cellW = half / 2; const rows = [10, 10, 10, 10, 10, height - 50];
  let rowY = top;
  rows.slice(0, -1).forEach((rowHeight) => { rowY += rowHeight; doc.line(rightX, rowY, x + width, rowY); });
  doc.line(rightX + cellW, top, rightX + cellW, top + 50);
  const approved = quote.approvedAt ? formatDate(quote.approvedAt) : '-';
  const cells: Array<[string,string,string,string]> = [
    ['Invoice No.', invoice.invoiceNo, 'Dated', formatDate(invoice.invoiceDate)],
    ['GST Treatment', invoice.taxMode==='exclusive'?`Added above quote | Base INR ${money(invoice.quotedAmount??quote.grandTotal)}`:'Included in quotation total', 'Mode/Terms of Payment', quote.paymentTerms || settings.paymentTerms],
    ['Reference No. & Date.', `${quote.quoteNo} | ${approved}`, 'Other References', project.projectNo],
    ["Buyer's Consumer No.", customer.consumerNumber || '-', 'Project Capacity', `${quote.dcCapacityKw.toFixed(3)} kWp`],
    ['Dispatched through', 'EPC Installation', 'Destination', `${customer.villageCity}, ${customer.district}`],
  ];
  cells.forEach((row, index) => {
    const cy = top + index * 10;
    labeledCell(doc, rightX, cy, cellW, row[0], row[1]);
    labeledCell(doc, rightX + cellW, cy, cellW, row[2], row[3]);
  });
  labeledCell(doc, rightX, top + 50, half, 'Terms of Delivery', 'Supply, installation and commissioning of rooftop solar power plant as per accepted quotation.');
}

function drawItems(doc: jsPDF, input: InvoicePdfInput, top: number, height: number) {
  const { invoice, project } = input;
  const quote = project.acceptedQuoteSnapshot;
  const materials = project.installationMaterials;
  const splitLines = invoiceLines(input);
  const x = 10.5; const width = 189; const headerH = 8; const totalH = 9; const bodyBottom = top + height - totalH;
  const widths = [6, 79, 21, 17, 21, 11, 34];
  const positions = [x]; widths.forEach((w) => positions.push((positions.at(-1) ?? x) + w));
  doc.setLineWidth(.22); doc.rect(x, top, width, height); doc.line(x, top + headerH, x + width, top + headerH); doc.line(x, bodyBottom, x + width, bodyBottom);
  positions.slice(1, -1).forEach((px) => doc.line(px, top, px, top + height));
  const headers = ['Sl No.', 'Particulars', 'HSN/SAC', 'Quantity', 'Rate', 'per', 'Amount'];
  doc.setFont('helvetica', 'normal'); doc.setFontSize(7.3);
  headers.forEach((header, index) => doc.text(header, positions[index]! + widths[index]! / 2, top + 5, { align: 'center' }));

  const usableHeight=bodyBottom-(top+headerH); const rowHeights=splitLines.length===1?[usableHeight]:[Math.min(35,usableHeight*.68),usableHeight-Math.min(35,usableHeight*.68)]; let rowTop=top+headerH;
  splitLines.forEach((line,index)=>{const rowHeight=rowHeights[index]??usableHeight/splitLines.length;if(index>0)doc.line(x,rowTop,x+width,rowTop);const textY=rowTop+5;doc.setFont('helvetica','normal');doc.setFontSize(7.4);doc.text(String(index+1),positions[0]!+widths[0]!/2,textY,{align:'center'});let py=textY;doc.setFont('helvetica','bold');py=writeLines(doc,wrapped(doc,line.description,widths[1]!-5),positions[1]!+2.5,py,7.8,'bold',3.2);if(line.lineType==='supply'){py=writeLines(doc,wrapped(doc,`${quote.panelQuantity} x ${quote.panelWattageLabel??`${quote.panelWattage} Wp`} ${quote.panelBrand} ${quote.panelTechnology} PV modules`,widths[1]!-5),positions[1]!+2.5,py+.4,6.9,'italic',2.8);if(materials?.panelSerials.length){const serialText=materials.panelSerials.map((serial,serialIndex)=>`${serialIndex+1}. ${serial}`).join(', ');py=writeLines(doc,wrapped(doc,`Panel Serial Nos.: ${serialText}`,widths[1]!-5),positions[1]!+2.5,py+.4,6.3,'normal',2.5);}const inverterProduct=quote.inverterModel?`${quote.inverterBrand} ${quote.inverterModel}`:`${quote.inverterBrand} ${quote.inverterCapacityKw} kW`;writeLines(doc,wrapped(doc,`${inverterProduct} inverter${materials?.inverterSerial?` | Serial No.: ${materials.inverterSerial}`:''}`,widths[1]!-5),positions[1]!+2.5,py+.4,6.7,'italic',2.7);}doc.setFont('helvetica','normal');doc.setFontSize(7);doc.text(clean(line.hsnSac),positions[2]!+1.3,textY);doc.text('1 Job',positions[3]!+widths[3]!-1.3,textY,{align:'right'});doc.text(money(line.taxableValue),positions[4]!+widths[4]!-1.3,textY,{align:'right'});doc.text('Job',positions[5]!+widths[5]!/2,textY,{align:'center'});doc.setFont('helvetica','bold');doc.text(money(line.taxableValue),positions[6]!+widths[6]!-1.3,textY,{align:'right'});rowTop+=rowHeight;});

  const taxes: Array<[string,number]> = [];
  if (invoice.cgst > 0) taxes.push(['CGST', invoice.cgst]);
  if (invoice.sgst > 0) taxes.push(['SGST', invoice.sgst]);
  if (invoice.igst > 0) taxes.push(['IGST', invoice.igst]);
  taxes.forEach(([label, amount], index) => {
    const ty = bodyBottom - (taxes.length - index) * 6 + 3.8;
    doc.setFont('helvetica', 'bold'); doc.setFontSize(7.7); doc.text(label, positions[2]! - 2, ty, { align: 'right' }); doc.text(money(amount), positions[7]! - 1.3, ty, { align: 'right' });
  });
  doc.setFont('helvetica', 'bold'); doc.setFontSize(8.5); doc.text('Total', positions[6]! - 1.5, bodyBottom + 6, { align: 'right' }); doc.setFontSize(10); doc.text(`INR ${money(invoice.grandTotal)}`, positions[7]! - 1.3, bodyBottom + 6, { align: 'right' });
}

function drawTaxSummary(doc: jsPDF, input: InvoicePdfInput, top: number) {
  const { invoice } = input; const totalTax = invoice.cgst + invoice.sgst + invoice.igst; const splitLines=invoiceLines(input);
  const x = 10.5; const width = 189; const rowH=7; const headerH=8; const totalH=7; const height=headerH+rowH*splitLines.length+totalH;
  doc.setLineWidth(.22); doc.rect(x, top, width, height);
  if (invoice.igst > 0) {
    const widths = [50, 35, 25, 40, 39]; const pos = [x]; widths.forEach((w) => pos.push((pos.at(-1) ?? x) + w));
    pos.slice(1,-1).forEach((px) => doc.line(px, top, px, top + height)); doc.line(x, top + headerH, x + width, top + headerH);splitLines.forEach((_,index)=>doc.line(x,top+headerH+rowH*(index+1),x+width,top+headerH+rowH*(index+1)));
    ['HSN/SAC','Taxable Value','IGST Rate','IGST Amount','Total Tax Amount'].forEach((h,i) => { doc.setFont('helvetica','normal'); doc.setFontSize(7); doc.text(h,pos[i]!+widths[i]!/2,top+4.5,{align:'center'}); });
    splitLines.forEach((line,index)=>{const y=top+headerH+rowH*index+4.8;[line.hsnSac,money(line.taxableValue),`${line.gstRate}%`,money(line.igst),money(line.igst)].forEach((v,i)=>doc.text(clean(v),pos[i]!+widths[i]!-1,y,{align:'right'}));});
    const totalY=top+height-2.3;doc.setFont('helvetica','bold'); doc.text('Total',pos[0]!+widths[0]!-1,totalY,{align:'right'}); [money(invoice.taxableValue),'',money(invoice.igst),money(totalTax)].forEach((v,i)=>doc.text(clean(v),pos[i+1]!+widths[i+1]!-1,totalY,{align:'right'}));
    return;
  }
  const widths=[50,28,12,24,12,24,39]; const pos=[x]; widths.forEach((w)=>pos.push((pos.at(-1)??x)+w)); pos.slice(1,-1).forEach((px)=>doc.line(px,top,px,top+height));
  doc.line(x,top+headerH,x+width,top+headerH); doc.line(pos[2]!,top+3,pos[6]!,top+3); splitLines.forEach((_,index)=>doc.line(x,top+headerH+rowH*(index+1),x+width,top+headerH+rowH*(index+1)));
  doc.setFont('helvetica','normal'); doc.setFontSize(6.8); doc.text('HSN/SAC',pos[0]!+widths[0]!/2,top+4,{align:'center'}); doc.text('Taxable Value',pos[1]!+widths[1]!/2,top+4,{align:'center'}); doc.text('CGST',pos[2]!+(widths[2]!+widths[3]!)/2,top+2.4,{align:'center'}); doc.text('SGST/UTGST',pos[4]!+(widths[4]!+widths[5]!)/2,top+2.4,{align:'center'}); doc.text('Total Tax Amount',pos[6]!+widths[6]!/2,top+4,{align:'center'});
  ['Rate','Amount','Rate','Amount'].forEach((h,i)=>doc.text(h,pos[i+2]!+widths[i+2]!/2,top+5.3,{align:'center'}));
  splitLines.forEach((line,index)=>{const y=top+headerH+rowH*index+4.8;const vals=[line.hsnSac,money(line.taxableValue),`${line.gstRate/2}%`,money(line.cgst),`${line.gstRate/2}%`,money(line.sgst),money(line.cgst+line.sgst)];vals.forEach((v,i)=>doc.text(clean(v),pos[i]!+widths[i]!-1,y,{align:'right'}));});
  const totalY=top+height-2.3;doc.setFont('helvetica','bold'); doc.text('Total',pos[0]!+widths[0]!-1,totalY,{align:'right'}); [money(invoice.taxableValue),'',money(invoice.cgst),'',money(invoice.sgst),money(totalTax)].forEach((v,i)=>doc.text(clean(v),pos[i+1]!+widths[i+1]!-1,totalY,{align:'right'}));
}

export async function createInvoicePdf(input: InvoicePdfInput) {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF({ unit: 'mm', format: 'a4', orientation: 'portrait', compress: true });
  const { invoice, project, customer, settings } = input; const company = settings.company; const bank = settings.bank; const totalTax = invoice.cgst + invoice.sgst + invoice.igst;
  doc.setTextColor(0,0,0); doc.setDrawColor(0,0,0); doc.setLineWidth(.22);
  doc.setFont('helvetica','bold'); doc.setFontSize(13); doc.text('Tax Invoice',105,10,{align:'center'}); doc.setFont('helvetica','italic'); doc.setFontSize(8.5); doc.text('(ORIGINAL FOR RECIPIENT)',197.5,10,{align:'right'});
  drawPartyAndMeta(doc,input,16,65); drawItems(doc,input,81,78);

  doc.rect(10.5,159,189,14); doc.setFont('helvetica','normal'); doc.setFontSize(6.8); doc.text('Amount Chargeable (in words)',11.7,162.5); doc.setFont('helvetica','italic'); doc.text('E. & O.E',198,162.5,{align:'right'}); doc.setFont('helvetica','bold'); doc.setFontSize(8.8); writeLines(doc,wrapped(doc,`INR ${amountInWords(invoice.grandTotal)}`,185),11.7,168,8.8,'bold',3.2);
  drawTaxSummary(doc,input,173);
  doc.rect(10.5,202,189,9); doc.setFont('helvetica','normal'); doc.setFontSize(7.4); doc.text('Tax Amount (in words):',11.7,207); doc.setFont('helvetica','bold'); doc.text(clean(`INR ${amountInWords(totalTax)}`),44,207);

  const bottomTop=211; const bottomHeight=56; const half=94.5; doc.rect(10.5,bottomTop,189,bottomHeight); doc.line(105,bottomTop,105,bottomTop+bottomHeight); doc.line(105,bottomTop+28,199.5,bottomTop+28);
  doc.setFont('helvetica','normal'); doc.setFontSize(7.5); doc.text("Company's PAN:",12,bottomTop+6); doc.setFont('helvetica','bold'); doc.text(clean(company.pan),36,bottomTop+6); doc.setFont('helvetica','normal'); doc.text('Declaration',12,bottomTop+38); doc.line(12,bottomTop+38.5,28,bottomTop+38.5); writeLines(doc,wrapped(doc,'We declare that this invoice shows the actual value of the goods and services described and that all particulars are true and correct.',half-4),12,bottomTop+42,7.2,'normal',3);
  doc.setFont('helvetica','normal'); doc.setFontSize(7.2); doc.text("Company's Bank Details",152.25,bottomTop+4,{align:'center'}); const bankLines=[`Bank Name: ${bank.bankName}`,`A/c No.: ${bank.accountNumber}`,`Branch & IFS Code: ${bank.branch} & ${bank.ifsc}`]; let bankY=bottomTop+9; bankLines.forEach((line)=>{ const [label,...rest]=line.split(':'); doc.setFont('helvetica','normal'); doc.text(`${label}:`,107,bankY); doc.setFont('helvetica','bold'); doc.text(clean(rest.join(':').trim()),132,bankY); bankY+=4; });
  doc.setFont('helvetica','bold'); doc.setFontSize(7.5); doc.text(clean(`for ${company.legalName}`),197.5,bottomTop+32,{align:'right'}); doc.text('Authorised Signatory',197.5,bottomTop+52,{align:'right'});
  doc.setFont('helvetica','normal'); doc.setFontSize(7.8); doc.text(clean(`SUBJECT TO ${company.jurisdiction.toUpperCase()} JURISDICTION`),105,275,{align:'center'}); doc.setFontSize(7.3); doc.text('This is a Computer Generated Invoice',105,282,{align:'center'}); doc.setFontSize(6.6); doc.text(clean(`${invoice.invoiceNo} | ${project.projectNo} | ${customer.customerNo}`),105,288,{align:'center'});
  return doc;
}

export async function downloadVectorInvoicePdf(input: InvoicePdfInput, filename: string) {
  const pdf = await createInvoicePdf(input); pdf.save(filename);
}

export async function openVectorInvoicePdf(input: InvoicePdfInput, filename: string) {
  const popup = window.open('', '_blank');
  if (popup) popup.document.write('<title>Preparing printable invoice...</title><p style="font:16px sans-serif;padding:24px">Preparing selectable A4 invoice PDF...</p>');
  const pdf = await createInvoicePdf(input); const blob = pdf.output('blob'); const url = URL.createObjectURL(blob);
  if (popup) popup.location.href = url; else pdf.save(filename);
  window.setTimeout(() => URL.revokeObjectURL(url),120_000);
}
