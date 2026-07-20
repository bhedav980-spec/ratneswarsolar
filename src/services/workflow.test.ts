import { describe, expect, it } from 'vitest';
import { allowedNextStages, bomFromQuote, canTransition, reserveMaterials } from './workflow';
import type { Quotation } from '../types/domain';

const quote = { status: 'draft', items: [], panelBrand: 'WAAREE', panelTechnology: 'TOPCon', panelWattage: 580, panelQuantity: 7 } as unknown as Quotation;

describe('workflow controls', () => {
  it('allows only valid project stage transitions and models the loan branch', () => {
    expect(canTransition('project_created','planning_done')).toBe(true);
    expect(canTransition('planning_done','loan_required')).toBe(true);
    expect(canTransition('planning_done','loan_not_required')).toBe(true);
    expect(canTransition('project_created','installation_done')).toBe(false);
    expect(allowedNextStages('project_closed')).toEqual([]);
  });

  it('creates a material snapshot and identifies shortages', () => {
    const requirements = bomFromQuote(quote);
    const panel = requirements[0]!;
    expect(panel.requiredQty).toBe(7);
    const reserved = reserveMaterials(requirements, { [panel.itemCode]: 5 });
    expect(reserved[0]!.reservedQty).toBe(5);
    expect(reserved[0]!.shortageQty).toBe(2);
  });
});
