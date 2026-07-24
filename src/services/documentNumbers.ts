const trailingDigits = (value: string) => value.trim().match(/(\d+)$/)?.[1] ?? '';

export function quotationSerial(value: string): number {
  let digits = trailingDigits(value);
  if (!digits) throw new Error('Quotation number must end with a numeric serial.');
  if (/^20\d{2}\d+$/.test(digits)) digits = digits.slice(4);
  const serial = Number.parseInt(digits, 10);
  if (!Number.isSafeInteger(serial) || serial < 1) throw new Error('Quotation serial must be greater than zero.');
  return serial;
}

export function financialYearCode(value: string | Date): string {
  const date = value instanceof Date ? value : new Date(`${value}T00:00:00`);
  if (Number.isNaN(date.getTime())) throw new Error('A valid invoice date is required.');
  const calendarYear = date.getFullYear();
  const startYear = date.getMonth() >= 3 ? calendarYear : calendarYear - 1;
  return `${String(startYear).slice(-2)}-${String(startYear + 1).slice(-2)}`;
}

export function linkedBillNumber(quotationNumber: string, invoiceDate: string | Date): string {
  return `RE/BILL/${financialYearCode(invoiceDate)}/${String(quotationSerial(quotationNumber)).padStart(4, '0')}`;
}

export function linkedWorkReference(quotationNumber: string, invoiceDate: string | Date): string {
  return `RE/JOB/${financialYearCode(invoiceDate)}/${String(quotationSerial(quotationNumber)).padStart(4, '0')}`;
}

export function normaliseLegacyQuotationNumber(value: string, invoiceDate: string | Date): string {
  const date = invoiceDate instanceof Date ? invoiceDate : new Date(`${invoiceDate}T00:00:00`);
  return `RE-RSS-PGVCL-${date.getFullYear()}${String(quotationSerial(value)).padStart(3, '0')}`;
}
