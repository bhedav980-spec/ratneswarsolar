import * as XLSX from 'xlsx';

export interface ExcelColumn<T> { header: string; key: keyof T; width?: number; total?: boolean; }

export function buildWorkbook<T extends Record<string, unknown>>(sheetName: string, rows: T[], columns: ExcelColumn<T>[]) {
  const data: Record<string, unknown>[] = rows.map((row) => Object.fromEntries(columns.map((column) => [column.header, row[column.key] ?? ''])));
  if (rows.length && columns.some((column) => column.total)) {
    data.push(Object.fromEntries(columns.map((column, index) => [column.header, column.total ? rows.reduce((sum, row) => sum + Number(row[column.key] ?? 0), 0) : index === 0 ? 'TOTAL' : ''])));
  }
  const worksheet = XLSX.utils.json_to_sheet(data);
  worksheet['!cols'] = columns.map((column) => ({ wch: column.width ?? Math.min(40, Math.max(column.header.length + 2, ...rows.map((row) => String(row[column.key] ?? '').length + 2))) }));
  worksheet['!autofilter'] = { ref: worksheet['!ref'] ?? 'A1:A1' };
  worksheet['!freeze'] = { xSplit: 0, ySplit: 1 } as never;
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, sheetName.slice(0, 31));
  return workbook;
}

export function downloadWorkbook<T extends Record<string, unknown>>(filename: string, sheetName: string, rows: T[], columns: ExcelColumn<T>[]) {
  XLSX.writeFile(buildWorkbook(sheetName, rows, columns), filename, { compression: true });
}
