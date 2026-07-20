import { describe, expect, it } from 'vitest';
import type { PriceRow } from '../types/domain';
import { exactCapacityKw, resolveOfficialPriceRow, wattagesForPriceRows } from './priceMatching';

const rows: PriceRow[] = [
  { id:'w540-4',panelBrand:'WAAREE',panelTechnology:'Bifacial',panelWattage:540,panelWattageMin:540,panelWattageMax:540,panelQuantity:4,capacityKw:2.16,price:112615,effectiveFrom:'2026-07-20',active:true },
  { id:'w540-6',panelBrand:'WAAREE',panelTechnology:'Bifacial',panelWattage:540,panelWattageMin:540,panelWattageMax:540,panelQuantity:6,capacityKw:3.24,price:156752,effectiveFrom:'2026-07-20',active:true },
  { id:'a610-4',panelBrand:'ADANI',panelTechnology:'TOPCon',panelWattage:610,panelWattageMin:610,panelWattageMax:625,panelQuantity:4,capacityKw:2.44,price:131502,effectiveFrom:'2026-07-20',active:true },
];

describe('official price matching', () => {
  it('exposes every 5 W option inside a verified source range', () => {
    expect(wattagesForPriceRows(rows,'ADANI','TOPCon')).toEqual([610,615,620,625]);
    expect(wattagesForPriceRows(rows,'WAAREE','Bifacial')).toEqual([540]);
  });
  it('maps requested kW to the nearest valid source quantity without interpolation', () => {
    expect(resolveOfficialPriceRow(rows,'WAAREE','Bifacial',540,3.27)?.panelQuantity).toBe(6);
    expect(exactCapacityKw(540,6)).toBe(3.24);
  });
});
