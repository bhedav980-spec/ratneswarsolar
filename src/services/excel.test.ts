import { describe, expect, it } from 'vitest';
import * as XLSX from 'xlsx';
import { buildWorkbook } from './excel';

describe('Excel exports', () => {
  it('creates a named worksheet with headings and totals', () => {
    const workbook = buildWorkbook('Projects', [{ project: 'P-1', value: 125000 }], [
      { header: 'Project', key: 'project' }, { header: 'Value', key: 'value', total: true },
    ]);
    expect(workbook.SheetNames).toEqual(['Projects']);
    const rows = XLSX.utils.sheet_to_json(workbook.Sheets.Projects!, { header: 1 });
    expect(rows).toEqual([['Project', 'Value'], ['P-1', 125000], ['TOTAL', 125000]]);
  });
});
