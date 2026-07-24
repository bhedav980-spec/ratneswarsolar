import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

describe('simplified customer form', () => {
  const source = readFileSync('src/features/Customers.tsx', 'utf8');

  it('keeps one address field and district while removing unnecessary inputs', () => {
    expect(source).toContain('Full Address *');
    expect(source).toContain('District *');
    expect(source).not.toContain('Alternate Mobile');
    expect(source).not.toContain('Sanctioned Load (kW)');
    expect(source).not.toContain('Meter Type');
    expect(source).not.toContain('Average Monthly Units');
    expect(source).not.toContain('Average Electricity Bill');
    expect(source).not.toContain('Village / City *');
    expect(source).not.toContain('Taluka');
    expect(source).not.toContain('Area / Territory *');
    expect(source).not.toContain('Roof Type');
    expect(source).not.toContain('Available Roof Area (sq ft)');
    expect(source).not.toContain('GPS / Location Link');
  });
});
