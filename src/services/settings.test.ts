import { describe, expect, it } from 'vitest';
import { defaultCrmSettings, documentNumberPreview, mergeCrmSettings } from './settings';

describe('editable CRM settings', () => {
  it('merges saved company and numbering values with safe defaults', () => {
    const result = mergeCrmSettings({
      company: { tradeName: 'Updated Solar Company' },
      quotationNumbering: { prefix: 'OLD-QUOTE-', nextNumber: 281, padding: 5 },
    });
    expect(result.company.tradeName).toBe('Updated Solar Company');
    expect(result.company.gstin).toBe(defaultCrmSettings.company.gstin);
    expect(result.quotationNumbering).toEqual({ prefix: 'OLD-QUOTE-', nextNumber: 281, padding: 5 });
  });

  it('previews the exact configured next document number', () => {
    expect(documentNumberPreview({ prefix: 'RE-RSS-PGVCL-', nextNumber: 42, padding: 4 })).toBe('RE-RSS-PGVCL-0042');
  });

  it('clamps unsafe numbering values', () => {
    const result = mergeCrmSettings({ quotationNumbering: { prefix: 'Q-', nextNumber: -4, padding: 99 } });
    expect(result.quotationNumbering.nextNumber).toBe(1);
    expect(result.quotationNumbering.padding).toBe(10);
  });
});
