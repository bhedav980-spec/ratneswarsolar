import type { CrmSettings, DocumentNumberSettings } from '../types/domain';

export const defaultCrmSettings: CrmSettings = {
  company: {
    legalName: 'RATNESWAR ENGINEERING',
    tradeName: 'Ratneswar Engineering',
    address: 'Office No. 19, Sanghvi Square Complex, Salarinaka, Rapar-Kutch, Rapar, Gujarat - 370165',
    mobilePrimary: '84010 50053',
    mobileSecondary: '78019 56980',
    email: 'ratneswarengineering@gmail.com',
    gstin: '24ABKFR8021K1ZZ',
    pan: 'ABKFR8021K',
    state: 'Gujarat',
    stateCode: '24',
    jurisdiction: 'Kutch',
  },
  bank: {
    accountHolder: 'RATNESWAR ENGINEERING',
    bankName: 'HDFC Bank',
    accountNumber: '99900019052018',
    ifsc: 'HDFC0002295',
    branch: 'Rapar Branch, Kutch',
  },
  quotationNumbering: { prefix: 'RE-RSS-PGVCL-2026', nextNumber: 1, padding: 4 },
  invoiceNumbering: { prefix: 'RE-INV-2026', nextNumber: 1, padding: 4 },
  quotationValidityDays: 15,
  paymentTerms: '10% advance at work order; 90% before material dispatch.',
  warrantyTerms: 'Five-year comprehensive system warranty; component warranties as provided by manufacturers.',
  quotationNotes: 'Subsidy is informational, subject to eligibility, and credited directly to the customer.',
  defaultHsnSac: '8541 / 9954',
  footerText: 'This is a computer-generated document. Subject to Kutch jurisdiction.',
  inactivityMinutes: 30,
};

const numberSettings = (value: unknown, fallback: DocumentNumberSettings): DocumentNumberSettings => {
  const candidate = (value && typeof value === 'object' ? value : {}) as Partial<DocumentNumberSettings>;
  return {
    prefix: String(candidate.prefix ?? fallback.prefix),
    nextNumber: Math.max(1, Number(candidate.nextNumber ?? fallback.nextNumber) || fallback.nextNumber),
    padding: Math.min(10, Math.max(1, Number(candidate.padding ?? fallback.padding) || fallback.padding)),
  };
};

export function mergeCrmSettings(value: unknown): CrmSettings {
  const incoming = (value && typeof value === 'object' ? value : {}) as Partial<CrmSettings>;
  return {
    ...defaultCrmSettings,
    ...incoming,
    company: { ...defaultCrmSettings.company, ...(incoming.company ?? {}) },
    bank: { ...defaultCrmSettings.bank, ...(incoming.bank ?? {}) },
    quotationNumbering: numberSettings(incoming.quotationNumbering, defaultCrmSettings.quotationNumbering),
    invoiceNumbering: numberSettings(incoming.invoiceNumbering, defaultCrmSettings.invoiceNumbering),
    quotationValidityDays: Math.max(1, Number(incoming.quotationValidityDays ?? defaultCrmSettings.quotationValidityDays)),
    inactivityMinutes: Math.max(5, Number(incoming.inactivityMinutes ?? defaultCrmSettings.inactivityMinutes)),
  };
}

export function documentNumberPreview(settings: DocumentNumberSettings) {
  return `${settings.prefix}${String(settings.nextNumber).padStart(settings.padding, '0')}`;
}
