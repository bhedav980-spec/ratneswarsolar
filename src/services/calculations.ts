import type { CustomerType, InvoiceTaxLine, QuoteItem, SubsidyBreakdown, SubsidyRule, TaxRule } from '../types/domain';

export interface QuoteCalculationInput {
  panelWattage: number;
  panelQuantity: number;
  basePrice: number;
  extraItems: QuoteItem[];
  discount: number;
  taxMode: 'exclusive' | 'inclusive' | 'none';
  taxRate: number;
}

export function roundMoney(value: number): number {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}

export function calculateDcCapacity(wattage: number, quantity: number): number {
  return Math.round(wattage * quantity) / 1000;
}

export function calculateLoanCustomerPrice(basePrice: number, grossUpPercent = 10, fileCharge = 2000) {
  const safeBase = Math.max(0, Number(basePrice) || 0);
  const safePercent = Math.min(99.99, Math.max(0, Number(grossUpPercent) || 0));
  const safeCharge = Math.max(0, Number(fileCharge) || 0);
  const financedEpcPrice = roundMoney(safeBase / (1 - safePercent / 100));
  const grossUpAmount = roundMoney(financedEpcPrice - safeBase);
  return { basePrice: roundMoney(safeBase), grossUpPercent: safePercent, financedEpcPrice, grossUpAmount, fileCharge: roundMoney(safeCharge), total: Math.round(financedEpcPrice + safeCharge) };
}

export function standardInformationalSubsidy(): SubsidyBreakdown {
  return {
    eligible: true,
    central: 78000,
    state: 0,
    total: 78000,
    informationalOnly: true,
    ruleName: 'Standard quotation information',
    referenceLines: [
      { label: 'Central Subsidy (Up to 2 kW)', amount: 30000 },
      { label: 'Central Subsidy (Above 2 kW)', amount: 18000 },
      { label: 'State Subsidy (Above 2 kW)', amount: 30000 },
      { label: 'Agreement Charges', amount: 350 },
    ],
  };
}

export function calculateQuote(input: QuoteCalculationInput) {
  const selectedExtras = input.extraItems
    .filter((item) => item.selected && !item.internalOnly)
    .reduce((sum, item) => sum + item.quantity * item.rate, 0);
  const commercialValue = Math.max(0, input.basePrice + selectedExtras - input.discount);
  let taxableValue = commercialValue;
  let taxAmount = 0;
  if (input.taxMode === 'exclusive') {
    taxAmount = roundMoney(commercialValue * input.taxRate / 100);
  } else if (input.taxMode === 'inclusive' && input.taxRate > 0) {
    taxableValue = roundMoney(commercialValue * 100 / (100 + input.taxRate));
    taxAmount = roundMoney(commercialValue - taxableValue);
  }
  const beforeRound = input.taxMode === 'exclusive' ? taxableValue + taxAmount : commercialValue;
  const grandTotal = Math.round(beforeRound);
  return {
    dcCapacityKw: calculateDcCapacity(input.panelWattage, input.panelQuantity),
    taxableValue: roundMoney(taxableValue),
    taxAmount: roundMoney(taxAmount),
    roundOff: roundMoney(grandTotal - beforeRound),
    grandTotal,
  };
}

export function calculateSubsidy(customerType: CustomerType, kw: number): SubsidyBreakdown {
  if (customerType !== 'Residential' && customerType !== 'RWA/GHS') {
    return { eligible: false, central: 0, state: 0, total: 0 };
  }
  const cappedKw = Math.min(Math.max(kw, 0), 3);
  const central = Math.min(cappedKw, 2) * 30000 + Math.max(0, cappedKw - 2) * 18000;
  return {
    eligible: true,
    central: Math.round(central),
    state: 0,
    total: Math.round(central),
    ruleName: 'Editable PM Surya Ghar default rule',
  };
}

export function calculateSubsidyFromRules(customerType: CustomerType, kw: number, rules: SubsidyRule[], onDate = new Date()): SubsidyBreakdown {
  const iso = onDate.toISOString().slice(0,10);
  const rule = rules.filter((r) => r.active && r.customerCategory === customerType && r.effectiveFrom <= iso && (!r.effectiveTo || r.effectiveTo >= iso) && kw >= r.minKw && (r.maxKw == null || kw <= r.maxKw)).sort((a,b) => b.effectiveFrom.localeCompare(a.effectiveFrom))[0];
  if (!rule) return { eligible: false, central: 0, state: 0, total: 0 };
  const calc = rule.calculation; let total = Number(calc.fixedAmount ?? 0);
  if (!total) { const capped = Math.min(kw, Number(calc.capKw ?? kw)); total = Math.min(capped,2)*Number(calc.upTo2Rate ?? 0)+Math.max(0,capped-2)*Number(calc.above2Rate ?? 0); }
  return { eligible: true, central: Math.round(total), state: 0, total: Math.round(total), ruleName: rule.name };
}

export function formatInr(value: number): string {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value || 0);
}

export function formatDate(value?: string | null): string {
  if (!value) return '-';
  return new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', day: '2-digit', month: '2-digit', year: 'numeric' }).format(new Date(value));
}

export function reverseCalculateGst(gross: number, rate: number, interstate = false) {
  const taxableValue = rate > 0 ? roundMoney(gross * 100 / (100 + rate)) : roundMoney(gross);
  const totalTax = roundMoney(gross - taxableValue);
  return interstate
    ? { taxableValue, cgst: 0, sgst: 0, igst: totalTax, gross: roundMoney(gross) }
    : { taxableValue, cgst: roundMoney(totalTax / 2), sgst: roundMoney(totalTax / 2), igst: 0, gross: roundMoney(gross) };
}

type SplitTaxTreatment = 'inclusive' | 'exclusive';

export function calculateSplitGst(amount: number, rule: Pick<TaxRule, 'intrastate'|'supplyGstRate'|'installationGstRate'|'supplySharePercent'|'installationSharePercent'|'supplyHsn'|'installationSac'>, treatment: SplitTaxTreatment = 'inclusive') {
  const supplyShare = Number(rule.supplySharePercent);
  const installationShare = Number(rule.installationSharePercent);
  if (supplyShare < 0 || installationShare < 0 || roundMoney(supplyShare + installationShare) !== 100) {
    throw new Error('Supply and installation shares must be non-negative and total exactly 100%.');
  }
  const safeAmount = roundMoney(Math.max(0, Number(amount) || 0));
  const makeLine = (
    lineType: InvoiceTaxLine['lineType'], description: string, hsnSac: string,
    sharePercent: number, rate: number, lineAmount: number,
  ): InvoiceTaxLine => {
    const taxableValue = treatment === 'inclusive' && rate > 0
      ? roundMoney(lineAmount * 100 / (100 + rate))
      : roundMoney(lineAmount);
    const tax = treatment === 'inclusive'
      ? roundMoney(lineAmount - taxableValue)
      : roundMoney(taxableValue * rate / 100);
    const lineGross = treatment === 'inclusive' ? roundMoney(lineAmount) : roundMoney(taxableValue + tax);
    const cgst = rule.intrastate ? roundMoney(tax / 2) : 0;
    const sgst = rule.intrastate ? roundMoney(tax - cgst) : 0;
    return { lineType, description, hsnSac, sharePercent, gstRate: rate, grossAmount: lineGross, taxableValue, cgst, sgst, igst: rule.intrastate ? 0 : tax };
  };
  const supplyAmount = roundMoney(safeAmount * supplyShare / 100);
  const installationAmount = roundMoney(safeAmount - supplyAmount);
  const lines = [
    makeLine('supply', 'Solar Power Generation System - Supply', rule.supplyHsn, supplyShare, Number(rule.supplyGstRate), supplyAmount),
    makeLine('installation', 'Installation and Commissioning of Solar Power System', rule.installationSac, installationShare, Number(rule.installationGstRate), installationAmount),
  ].filter((line) => line.sharePercent > 0 || line.grossAmount > 0);
  const total = (field: keyof Pick<InvoiceTaxLine, 'taxableValue'|'cgst'|'sgst'|'igst'|'grossAmount'>) => roundMoney(lines.reduce((sum, line) => sum + Number(line[field]), 0));
  return { treatment, quotedAmount: safeAmount, lines, taxableValue: total('taxableValue'), cgst: total('cgst'), sgst: total('sgst'), igst: total('igst'), gross: total('grossAmount') };
}

export function calculateSplitInclusiveGst(gross: number, rule: Pick<TaxRule, 'intrastate'|'supplyGstRate'|'installationGstRate'|'supplySharePercent'|'installationSharePercent'|'supplyHsn'|'installationSac'>) {
  return calculateSplitGst(gross, rule, 'inclusive');
}

const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
const underHundred = (n: number) => n < 20 ? ones[n] ?? '' : `${tens[Math.floor(n / 10)]}${n % 10 ? ` ${ones[n % 10]}` : ''}`;
const underThousand = (n: number) => n < 100 ? underHundred(n) : `${ones[Math.floor(n / 100)]} Hundred${n % 100 ? ` ${underHundred(n % 100)}` : ''}`;

export function amountInWords(value: number): string {
  let n = Math.round(Math.abs(value));
  if (n === 0) return 'Zero Rupees Only';
  const parts: string[] = [];
  const groups: [number, string][] = [[10000000, 'Crore'], [100000, 'Lakh'], [1000, 'Thousand']];
  for (const [size, label] of groups) {
    const count = Math.floor(n / size);
    if (count) parts.push(`${underThousand(count)} ${label}`);
    n %= size;
  }
  if (n) parts.push(underThousand(n));
  return `${parts.join(' ')} Rupees Only`;
}

export function pendingBalance(total: number, received: number): number {
  return Math.max(0, roundMoney(total - received));
}
