import { describe, expect, it } from 'vitest';
import { financialYearCode, linkedBillNumber, normaliseLegacyQuotationNumber, quotationSerial } from './documentNumbers';

describe('quote-linked bill numbers', () => {
  it('reuses the serial from a current CRM quotation', () => {
    expect(quotationSerial('RE-RSS-PGVCL-2026038')).toBe(38);
    expect(linkedBillNumber('RE-RSS-PGVCL-2026038', '2026-07-23')).toBe('RE/BILL/26-27/0038');
  });

  it('supports old manually prepared quotation serials', () => {
    expect(linkedBillNumber('18', '2026-07-23')).toBe('RE/BILL/26-27/0018');
    expect(normaliseLegacyQuotationNumber('18', '2026-07-23')).toBe('RE-RSS-PGVCL-2026018');
  });

  it('uses the Indian financial year around April', () => {
    expect(financialYearCode('2026-03-31')).toBe('25-26');
    expect(financialYearCode('2026-04-01')).toBe('26-27');
  });
});
