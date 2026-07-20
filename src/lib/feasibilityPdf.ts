import type { jsPDF } from 'jspdf';
import type { Customer, FeasibilityInput, Quotation } from '../types/domain';

interface FeasibilityPdfInput {
  quotation: Quotation;
  customer: Customer;
  feasibility: FeasibilityInput;
}

const BLUE: [number, number, number] = [4, 76, 143];
const clean = (value: unknown) => String(value ?? '__')
  .replace(/[–—]/g, '-').replace(/[’]/g, "'").replace(/[₹]/g, 'INR ')
  .replace(/[^\x20-\x7E]/g, ' ').replace(/\s+/g, ' ').trim() || '__';
const money = (value: number) => `INR ${new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value || 0)}`;

export function quotationSerialNumber(quoteNo: string) {
  const numericParts = quoteNo.match(/\d+/g);
  const raw = numericParts?.at(-1) ?? '';
  const combinedYear = raw.match(/^20\d{2}(\d+)$/);
  const serial = combinedYear?.[1] || raw;
  const parsed = Number.parseInt(serial, 10);
  return Number.isFinite(parsed) ? String(parsed) : clean(quoteNo);
}

const optionalText = (value: string | undefined, fallback: string) => value?.trim() || fallback || '__';
const positiveNumber = (value: number | undefined, fallback: number) => Number.isFinite(value) && Number(value) >= 0 ? Number(value) : fallback;

async function imageData(url: string) {
  const response = await fetch(url);
  if (!response.ok) return null;
  const type = response.headers.get('content-type') || 'image/png';
  const bytes = new Uint8Array(await response.arrayBuffer());
  let binary = '';
  for (let offset = 0; offset < bytes.length; offset += 0x8000) binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  return `data:${type};base64,${btoa(binary)}`;
}

function textInCell(doc: jsPDF, value: string, x: number, y: number, width: number, height: number, options: { bold?: boolean; size?: number; center?: boolean } = {}) {
  doc.setFont('times', options.bold ? 'bold' : 'normal');
  doc.setFontSize(options.size ?? 8.1);
  const lineHeight = options.size && options.size < 7.8 ? 3.25 : 3.55;
  const lines = (doc.splitTextToSize(clean(value), width - 2.6) as string[]).slice(0, Math.max(1, Math.floor((height - 1.4) / lineHeight)));
  const startY = y + Math.max(4.1, (height - (lines.length - 1) * lineHeight) / 2 + 1.35);
  lines.forEach((line, index) => doc.text(line, options.center ? x + width / 2 : x + 1.3, startY + index * lineHeight, { align: options.center ? 'center' : 'left' }));
}

function drawHeader(doc: jsPDF, logo: string | null) {
  doc.setTextColor(...BLUE);
  doc.setFont('helvetica', 'bold'); doc.setFontSize(11.5); doc.text('G.S.T. No. 24ABKFR8021K1ZZ', 12, 13);
  doc.setFontSize(8.2); doc.text('ELECTRICAL, MECHANICAL & CIVIL CONTRACTOR', 12, 21);
  doc.setDrawColor(...BLUE); doc.setLineWidth(1); doc.line(12, 24, 128, 24);
  if (logo) doc.addImage(logo, 'PNG', 140, 7, 57, 19, undefined, 'NONE');
  else { doc.setFontSize(14); doc.text('Ratneswar Engineering', 197, 18, { align: 'right' }); }
  doc.setTextColor(0, 0, 0);
}

function drawFooter(doc: jsPDF) {
  doc.setDrawColor(...BLUE); doc.setLineWidth(1); doc.line(8, 278, 202, 278);
  doc.setTextColor(...BLUE); doc.setFont('helvetica', 'bold'); doc.setFontSize(7.1);
  doc.text('Office No. 19, Sanghvi Square Complex, Salarinaka, Rapar-Kutch, 370165, Gujarat, India', 105, 284, { align: 'center' });
  doc.text('(M) 84010 50053 / 78019 56980    E-mail : ratneswarengineering@gmail.com', 105, 289, { align: 'center' });
  doc.setTextColor(0, 0, 0);
}

function drawReportTable(doc: jsPDF, input: FeasibilityPdfInput) {
  const { quotation, customer, feasibility } = input;
  const x = 15; const widths: [number, number, number] = [7, 73, 100]; const positions: [number, number, number, number] = [x, x + widths[0], x + widths[0] + widths[1], x + 180];
  const defaultAddress = [customer.address, customer.villageCity, customer.taluka, customer.district, customer.state, customer.pinCode].filter(Boolean).join(', ');
  const appliedCapacity = positiveNumber(feasibility.appliedCapacityKw, quotation.dcCapacityKw);
  const actualCapacity = positiveNumber(feasibility.actualCapacityKw, quotation.dcCapacityKw);
  const projectCost = positiveNumber(feasibility.projectCost, quotation.grandTotal);
  const rows: Array<{ no: string; label: string; value: string; height: number }> = [
    { no: '1', label: 'NAME OF APPLICANT', value: optionalText(feasibility.applicantName, customer.fullName), height: 7 },
    { no: '2', label: 'CONSUMER NUMBER', value: optionalText(feasibility.consumerNumber, customer.consumerNumber || '__'), height: 7 },
    { no: '3', label: 'DISCOM ID', value: feasibility.discomId || '__', height: 7 },
    { no: '4', label: 'APPLICATION REFERENCE NUMBER', value: feasibility.applicationReferenceNumber, height: 7 },
    { no: '5', label: 'JAN SAMARTH ID', value: feasibility.janSamarthId || '__', height: 7 },
    { no: '6', label: 'ADDRESS OF PREMISES INSTALLATION', value: optionalText(feasibility.installationAddress, defaultAddress), height: 10 },
    { no: '7', label: 'DISTRICT OF INSTALLATION', value: optionalText(feasibility.districtName, customer.district), height: 7 },
    { no: '8', label: 'STATE OF INSTALLATION', value: optionalText(feasibility.stateName, customer.state || 'GUJARAT'), height: 7 },
    { no: '9', label: 'PINCODE OF INSTALLATION', value: optionalText(feasibility.pinCode, customer.pinCode || '__'), height: 7 },
    { no: '10', label: 'OEM NAME', value: optionalText(feasibility.oemName, quotation.panelBrand), height: 7 },
    { no: '11', label: 'EPC CONTRACTOR ADDRESS', value: 'OFFICE NO.19, SANGHVI SQUARE COMPLEX, SALARINAKA, RAPAR-KUTCH, 370165, GUJARAT, INDIA', height: 11 },
    { no: '12', label: 'EPC CONTRACTOR BANK DETAILS', value: 'NAME: RATNESWAR ENGINEERING  BANK: HDFC BANK\nBRANCH: RAPAR BRANCH, KUTCH  ACCOUNT NUMBER: 99900019052018\nIFSC CODE: HDFC0002295', height: 19 },
    { no: '13', label: 'APPLIED RTS CAPACITY', value: `${appliedCapacity.toFixed(3)} kW`, height: 7 },
    { no: '14', label: 'ACTUAL RTS CAPACITY TO BE INSTALLED', value: `${actualCapacity.toFixed(3)} kW`, height: 7 },
    { no: '15', label: 'IS VENDOR REGISTERED IN MNRE PORTAL', value: 'YES', height: 9 },
    { no: '', label: 'NOTE : ONLY VENDOR REGISTERED IN MNRE PORTAL IS ALLOWED', value: '', height: 9 },
    { no: '16', label: 'FEASIBILITY REPORT STATUS', value: 'YES', height: 7 },
    { no: '17', label: 'PROJECT COST (ALL INCLUSIVE)', value: money(projectCost), height: 7 },
  ];
  let y = 45;
  const headerHeight = 8;
  doc.setDrawColor(20, 20, 20); doc.setLineWidth(.22); doc.rect(x, y, 180, headerHeight);
  textInCell(doc, `EPC NUMBER - ${quotationSerialNumber(quotation.quoteNo)}`, x, y, 180, headerHeight, { bold: true, size: 9, center: true });
  y += headerHeight;
  rows.forEach((row) => {
    doc.rect(x, y, 180, row.height);
    doc.line(positions[1]!, y, positions[1]!, y + row.height);
    doc.line(positions[2]!, y, positions[2]!, y + row.height);
    if (row.no) textInCell(doc, row.no, positions[0]!, y, widths[0], row.height, { size: 8, center: true });
    textInCell(doc, row.label, positions[1]!, y, widths[1], row.height, { size: row.no === '12' ? 7.35 : 8.05 });
    if (row.value) textInCell(doc, row.value, positions[2]!, y, widths[2], row.height, { bold: row.no === '12', size: row.no === '12' ? 7.4 : 8.1 });
    y += row.height;
  });
  return y;
}

export async function createFeasibilityPdf(input: FeasibilityPdfInput) {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF({ unit: 'mm', format: 'a4', orientation: 'portrait', compress: true });
  const [logo, signature] = await Promise.all([
    imageData('/brand/ratneswar-wordmark.png').catch(() => null),
    imageData('/brand/ratneswar-authorised-signature.png').catch(() => null),
  ]);
  drawHeader(doc, logo);
  doc.setFont('times', 'bold'); doc.setFontSize(10.8);
  doc.text('RESIDENTIAL ROOFTOP SOLAR INSTALLATION VENDOR FEASIBILITY REPORT', 105, 36, { align: 'center' });
  doc.setLineWidth(.25); doc.line(48, 37, 162, 37);
  const tableBottom = drawReportTable(doc, input);
  const approvalY = Math.min(Math.max(tableBottom + 10, 211), 219);
  doc.setFont('times', 'bold'); doc.setFontSize(9); doc.text('Approved By :', 17, approvalY);
  doc.text('Authorised Signatory', 17, approvalY + 8); doc.text('RATNESWAR ENGINEERING', 17, approvalY + 13);
  if (signature) doc.addImage(signature, 'PNG', 25, approvalY + 14, 38, 30, undefined, 'NONE');
  drawFooter(doc);
  doc.setProperties({
    title: `Feasibility Report ${input.quotation.quoteNo}`,
    subject: `Residential rooftop solar installation vendor feasibility report for ${input.customer.fullName}`,
    author: 'Ratneswar Engineering', creator: 'Ratneswar Solar CRM',
  });
  return doc;
}

export async function downloadFeasibilityPdf(input: FeasibilityPdfInput) {
  const pdf = await createFeasibilityPdf(input);
  pdf.save(`${input.quotation.quoteNo.replace(/[^A-Za-z0-9_-]+/g, '-')}-feasibility-report.pdf`);
}
