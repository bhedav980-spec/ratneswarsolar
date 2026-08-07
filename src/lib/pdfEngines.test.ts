import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { readFileSync, writeFileSync } from 'node:fs';
import { createInvoicePdf } from './invoicePdf';
import { createQuotationPdf } from './quotationPdf';
import type { CrmSettings, Customer, Invoice, Project, Quotation } from '../types/domain';

beforeAll(() => {
  vi.stubGlobal('fetch', vi.fn(async (input: string | URL | Request) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.pathname : new URL(input.url).pathname;
    if (url.startsWith('/brand/')) {
      return new Response(new Uint8Array(readFileSync(`public${url}`)), { status: 200, headers: { 'content-type': 'image/png' } });
    }
    return new Response(null, { status: 404 });
  }));
});

afterAll(() => vi.unstubAllGlobals());

const settings: CrmSettings = {
  company: {
    legalName: 'Ratneswar Engineering', tradeName: 'Ratneswar Engineering',
    address: 'Office No. 19, Sanghvi Square Complex, Rapar-Kutch, Gujarat - 370165',
    mobilePrimary: '9999999999', mobileSecondary: '8888888888', email: 'accounts@example.com',
    gstin: '24ABKFR8021K1ZZ', pan: 'ABKFR8021K', state: 'Gujarat', stateCode: '24', jurisdiction: 'Rapar-Kutch',
  },
  bank: { accountHolder: 'Ratneswar Engineering', bankName: 'Test Bank', accountNumber: '1234567890', ifsc: 'TEST0000123', branch: 'Rapar' },
  quotationNumbering: { prefix: 'RE-RSS-PGVCL-', nextNumber: 1, padding: 4 },
  invoiceNumbering: { prefix: 'RE-INV-', nextNumber: 1, padding: 4 },
  quotationValidityDays: 15, paymentTerms: 'Advance payment; Balance before dispatch', warrantyTerms: 'As per OEM',
  quotationNotes: '', defaultHsnSac: '854140', footerText: '', inactivityMinutes: 30,
};

const customer: Customer = {
  id: 'customer-1', customerNo: 'CUS-0001', fullName: 'Long Customer Name for A4 Layout Verification', mobile: '9999999999',
  address: 'Long customer address used to verify wrapping without clipping', villageCity: 'Rapar', taluka: 'Rapar', district: 'Kutch',
  state: 'Gujarat', pinCode: '370165', customerType: 'Residential', discom: 'PGVCL', consumerNumber: '12345678901',
  leadStatus: 'New', createdAt: '2026-07-19T10:00:00+05:30', updatedAt: '2026-07-19T10:00:00+05:30', rowVersion: 1,
};

const quote: Quotation = {
  id: 'quote-1', quoteNo: 'RE-RSS-PGVCL-20260001', customerId: customer.id, versionNo: 1, status: 'approved',
  systemType: 'On-grid', dcrType: 'DCR', scheme: 'PM Surya Ghar', panelTechnology: 'TOPCon', panelBrand: 'WAAREE',
  panelWattage: 580, panelWattageLabel: '580 Wp', panelQuantity: 6, dcCapacityKw: 3.48, inverterBrand: 'Polycab',
  inverterModel: 'PCU-3K', inverterCapacityKw: 3, structureType: 'Hot Dip GI',
  items: [
    { id: '1', description: 'PV Modules', brand: 'WAAREE', specification: '580 Wp TOPCon', quantity: 6, unit: 'Nos', rate: 0, taxRate: 0, selected: true },
    { id: '2', description: 'Inverter', brand: 'Polycab', specification: '3 kW On-grid', quantity: 1, unit: 'No', rate: 0, taxRate: 0, selected: true },
    { id: '3', description: 'Online Monitoring System', specification: 'Mobile App + Remote Monitoring', quantity: 1, unit: 'No', rate: 0, taxRate: 0, selected: true },
  ],
  basePrice: 200000, suggestedPrice: 200000, discount: 0, taxMode: 'inclusive', taxRate: 0, taxableValue: 184065.93,
  taxAmount: 15934.07, roundOff: 0, grandTotal: 224222, loanRequired: true, loanBasePrice: 200000, loanGrossUpPercent: 10, loanGrossUpAmount: 22222.22, loanFileCharge: 2000,
  subsidy: { eligible: true, central: 78000, state: 0, total: 78000, informationalOnly: true, referenceLines: [{label:'Central Subsidy (Up to 2 kW)',amount:30000},{label:'Central Subsidy (Above 2 kW)',amount:18000},{label:'State Subsidy (Above 2 kW)',amount:30000},{label:'Agreement Charges',amount:350}] },
  paymentTerms: 'Advance payment; Balance before dispatch', warrantyTerms: 'As per OEM', validityDays: 15,
  createdAt: '2026-07-19T10:00:00+05:30', approvedAt: '2026-07-19T11:00:00+05:30', priceSnapshot: {},
};

const project: Project = {
  id: 'project-1', projectNo: 'RE/PR/2026/0001', customerId: customer.id, quotationId: quote.id,
  acceptedQuoteSnapshot: quote, stage: 'installation_done', stageHistory: [], materials: [], district: 'Kutch',
  paymentReceived: 0, expensesTotal: 0, createdAt: quote.createdAt, updatedAt: quote.createdAt,
  installationMaterials: {
    panelBrand: 'WAAREE', panelTechnology: 'TOPCon', panelWattage: 580,
    panelSerials: ['W580-0001', 'W580-0002', 'W580-0003', 'W580-0004', 'W580-0005', 'W580-0006'],
    inverterBrand: 'Polycab', inverterModel: 'PCU-3K', inverterCapacityKw: 3, inverterSerial: 'INV-0001',
  },
};

const invoice: Invoice = {
  id: 'invoice-1', invoiceNo: 'RE-INV-20260001', customerId: customer.id, projectId: project.id,
  invoiceDate: '2026-07-19', placeOfSupply: 'Gujarat (24)', status: 'issued', taxMode: 'inclusive',
  quotedAmount: 160000, taxableValue: 147344.64, cgst: 6327.68, sgst: 6327.68, igst: 0, roundOff: 0, grandTotal: 160000,
  taxRuleName: 'Solar EPC 70/30 - Supply 5% / Installation 18%',
  includeSignature: true,
  taxLines: [
    { lineType: 'supply', description: 'Solar Rooftop Power Generation System (PV Modules and Inverter)', hsnSac: '854140', sharePercent: 70, gstRate: 5, grossAmount: 112000, taxableValue: 106666.67, cgst: 2666.67, sgst: 2666.66, igst: 0 },
    { lineType: 'installation', description: 'Mounting Structure and Balance of System (BOS) Materials for Solar Installation', hsnSac: '995442', sharePercent: 30, gstRate: 18, grossAmount: 48000, taxableValue: 40677.97, cgst: 3661.01, sgst: 3661.02, igst: 0 },
  ],
};

const exclusiveInvoice: Invoice = {
  ...invoice,
  id: 'invoice-2', invoiceNo: 'RE-INV-20260002', taxMode: 'exclusive', quotedAmount: 200000,
  taxableValue: 200000, cgst: 8900, sgst: 8900, grandTotal: 217800,
  taxLines: [
    { lineType: 'supply', description: 'Solar Rooftop Power Generation System (PV Modules and Inverter)', hsnSac: '854140', sharePercent: 70, gstRate: 5, grossAmount: 147000, taxableValue: 140000, cgst: 3500, sgst: 3500, igst: 0 },
    { lineType: 'installation', description: 'Mounting Structure and Balance of System (BOS) Materials for Solar Installation', hsnSac: '995442', sharePercent: 30, gstRate: 18, grossAmount: 70800, taxableValue: 60000, cgst: 5400, sgst: 5400, igst: 0 },
  ],
};

describe('vector A4 document engines', () => {
  it('keeps invoice issuance retries visible and database-safe', () => {
    const projectFeature = readFileSync('src/features/Projects.tsx', 'utf8');
    const retryMigration = readFileSync('supabase/migrations/202608020021_retry_safe_invoice_issuance.sql', 'utf8');
    expect(projectFeature).toContain("setError(cause instanceof Error?cause.message:'Invoice generation failed.')");
    expect(retryMigration).toContain("if existing_invoice.id is not null then return existing_invoice.id");
    expect(retryMigration).toContain('existing_serial_project is distinct from p.id');
    expect(retryMigration).toContain('on conflict(project_id) do update');
  });
  it('creates an exact two-page quotation PDF', async () => {
    const pdf = await createQuotationPdf({ quote, customer, settings, copyType: 'customer' });
    expect(pdf.getNumberOfPages()).toBe(2);
    expect(pdf.output('arraybuffer').byteLength).toBeGreaterThan(5000);
    if (process.env.WRITE_PDF_FIXTURES) writeFileSync(`${process.env.WRITE_PDF_FIXTURES}/quotation.pdf`, Buffer.from(pdf.output('arraybuffer')));
  });

  it('creates a single-page split-GST invoice PDF', async () => {
    const pdf = await createInvoicePdf({ invoice, project, customer, settings });
    expect(pdf.getNumberOfPages()).toBe(1);
    expect(pdf.output('arraybuffer').byteLength).toBeGreaterThan(5000);
    if (process.env.WRITE_PDF_FIXTURES) writeFileSync(`${process.env.WRITE_PDF_FIXTURES}/invoice.pdf`, Buffer.from(pdf.output('arraybuffer')));
  });

  it('uses the sharp feasibility signature by default and supports an unsigned invoice', async () => {
    const signed = await createInvoicePdf({ invoice, project, customer, settings });
    const unsigned = await createInvoicePdf({ invoice: { ...invoice, includeSignature: false }, project, customer, settings });
    expect(signed.getNumberOfPages()).toBe(1);
    expect(unsigned.getNumberOfPages()).toBe(1);
    expect(signed.output('arraybuffer').byteLength).toBeGreaterThan(unsigned.output('arraybuffer').byteLength + 20_000);
    if (process.env.WRITE_PDF_FIXTURES) {
      writeFileSync(`${process.env.WRITE_PDF_FIXTURES}/invoice-signed.pdf`, Buffer.from(signed.output('arraybuffer')));
      writeFileSync(`${process.env.WRITE_PDF_FIXTURES}/invoice-unsigned.pdf`, Buffer.from(unsigned.output('arraybuffer')));
    }
  });

  it('creates a single-page GST-extra invoice PDF without changing the accepted quote snapshot', async () => {
    const pdf = await createInvoicePdf({ invoice: exclusiveInvoice, project, customer, settings });
    expect(pdf.getNumberOfPages()).toBe(1);
    expect(pdf.output('arraybuffer').byteLength).toBeGreaterThan(5000);
    if (process.env.WRITE_PDF_FIXTURES) writeFileSync(`${process.env.WRITE_PDF_FIXTURES}/invoice-gst-extra.pdf`, Buffer.from(pdf.output('arraybuffer')));
  });
});
