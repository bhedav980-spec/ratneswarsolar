import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const migration = readFileSync('supabase/migrations/202607170006_residential_price_list_source_ranges.sql', 'utf8');
const seededRows = migration.match(/^ \(list_id,'/gm) ?? [];

describe('06.06.2026 residential rooftop source price list', () => {
  it('contains all 97 exact source configurations', () => {
    expect(seededRows).toHaveLength(97);
  });

  it('preserves representative source rows and wattage ranges', () => {
    expect(migration).toContain("'530–550 Wp',6,3.270,167460");
    expect(migration).toContain("'605–620 Wp',12,7.440,300820");
    expect(migration).toContain("'570–580 Wp',16,9.280,420560");
    expect(migration).toContain("'580 Wp',16,9.600,391760");
  });

  it('guards the database row count during deployment', () => {
    expect(migration).toContain("if row_count<>97 then raise exception");
  });
});
