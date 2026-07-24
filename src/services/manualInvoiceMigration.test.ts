import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const sql = readFileSync('supabase/migrations/202607230017_quote_linked_and_manual_invoices.sql','utf8');
const invoices = readFileSync('src/features/Invoices.tsx','utf8');
const customers = readFileSync('src/features/Customers.tsx','utf8');

describe('manual and quote-linked invoice release', () => {
  it('creates secured manual invoice persistence and cancellation', () => {
    expect(sql).toContain('create table if not exists public.manual_invoices');
    expect(sql).toContain('create or replace function public.save_manual_invoice');
    expect(sql).toContain('create or replace function public.cancel_manual_invoice');
    expect(sql).toContain("public.current_role()<>'admin'");
  });

  it('forces CRM invoice numbers to follow the accepted quote serial', () => {
    expect(sql).toContain('customer_invoice_quote_linked_number');
    expect(sql).toContain('public.linked_bill_number(quote_no,new.invoice_date)');
    expect(invoices).toContain('Manual Invoice Register');
    expect(invoices).toContain('linkedBillNumber(form.legacyQuoteNo,form.invoiceDate)');
  });

  it('removes the site survey workflow from customer screens', () => {
    expect(customers).not.toContain('SurveyForm');
    expect(customers).not.toContain('Customers and Site Surveys');
    expect(customers).not.toContain('Survey Scheduled');
  });
});
