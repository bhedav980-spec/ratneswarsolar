import { readFile } from 'node:fs/promises';
import { describe, expect, it } from 'vitest';
import JSZip from 'jszip';
import { populateAgreementXml } from './agreementDocx';
import { createFeasibilityPdf } from './feasibilityPdf';
import type { Customer, Quotation } from '../types/domain';

const customer = {
  id:'11111111-1111-4111-8111-111111111111',customerNo:'RE/CU/2026/0001',fullName:'Test Customer',mobile:'9876543210',address:'Long Test Address',villageCity:'Rapar',taluka:'Rapar',district:'Kutch',state:'Gujarat',pinCode:'370165',customerType:'Residential',discom:'PGVCL',consumerNumber:'12345678901',leadStatus:'New',createdAt:'2026-07-20T00:00:00Z',updatedAt:'2026-07-20T00:00:00Z',rowVersion:1,
} as Customer;
const quotation = {
  id:'22222222-2222-4222-8222-222222222222',quoteNo:'RE-RSS-PGVCL-2026999',customerId:customer.id,versionNo:1,status:'approved',systemType:'On-grid',dcrType:'DCR',scheme:'PM Surya Ghar',panelTechnology:'Bifacial',panelBrand:'WAAREE',panelWattage:540,panelQuantity:6,dcCapacityKw:3.24,inverterBrand:'Polycab',inverterCapacityKw:3,structureType:'HDG',items:[],basePrice:150000,discount:0,taxMode:'inclusive',taxRate:0,taxableValue:150000,taxAmount:0,roundOff:0,grandTotal:150000,subsidy:{eligible:true,central:78000,state:0,total:78000},paymentTerms:'Standard',warrantyTerms:'Standard',validityDays:15,createdAt:'2026-07-20T05:30:00Z',priceSnapshot:{},
} as Quotation;

describe('Agreement and feasibility workflow documents', () => {
  it('replaces only the dynamic agreement party/date fields in the official DOCX XML', async () => {
    const source = await readFile('public/templates/agreement-template.docx');
    const zip = await JSZip.loadAsync(source);
    const file = zip.file('word/document.xml');
    expect(file).toBeTruthy();
    const populated = populateAgreementXml(await file!.async('string'), quotation, customer);
    expect(populated).toContain('Test Customer');
    expect(populated).toContain('Long Test Address');
    expect(populated).toContain('20-07-2026');
    expect(populated).toContain('Ratneswar Engineering');
    expect(populated).toContain('continuous');
  });

  it('creates exactly one A4 feasibility PDF page from quote/customer data', async () => {
    const pdf = await createFeasibilityPdf({ quotation, customer, feasibility:{ applicationReferenceNumber:'APP-123',janSamarthId:'',discomId:'PGVCL-RAPAR' } });
    expect(pdf.getNumberOfPages()).toBe(1);
    const page = pdf.internal.pageSize;
    expect(page.getWidth()).toBeCloseTo(210, 0);
    expect(page.getHeight()).toBeCloseTo(297, 0);
  });
});
