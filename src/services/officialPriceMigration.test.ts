import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const sql = readFileSync('supabase/migrations/202607200014_official_price_match_and_project_cleanup.sql','utf8');
const officialRows = sql.match(/^ \(list_(?:540|580|w610|a550|a610),/gm) ?? [];

describe('final official five-PDF price migration', () => {
  it('publishes exactly 57 verified configurations', () => {
    expect(officialRows).toHaveLength(57);
    expect(sql).toContain('verified_count<>57');
  });
  it('contains representative GST-inclusive source rows', () => {
    expect(sql).toContain("'WAAREE','Bifacial',540,540,540,'540 Wp',6,3.240,156752");
    expect(sql).toContain("'WAAREE','TOPCon',580,580,580,'580 Wp',6,3.480,174023");
    expect(sql).toContain("'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',5,3.050,155742");
    expect(sql).toContain("'ADANI','Bifacial',550,550,550,'550 Wp',6,3.300,161297");
    expect(sql).toContain("'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',5,3.050,158267");
  });
  it('adds audited invoice cancellation before project deletion', () => {
    expect(sql).toContain('function public.cancel_customer_invoice');
    expect(sql).toContain("status='cancelled'");
    expect(sql).toContain("delete from public.customer_invoices where project_id=p.id and status='cancelled'");
  });
});
