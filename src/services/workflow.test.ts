import { describe, expect, it } from 'vitest';
import {
  allowedNextSimplifiedStages,
  allowedNextStages,
  bomFromQuote,
  canTransition,
  reserveMaterials,
  simplifiedStageFor,
  simplifiedStageLabel,
} from './workflow';
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

  it('groups legacy project stages into six practical workflow stages', () => {
    expect(simplifiedStageFor('project_created')).toBe('quotation_documentation');
    expect(simplifiedStageFor('loan_sanctioned')).toBe('loan_progress');
    expect(simplifiedStageFor('material_reserved')).toBe('material_dispatch');
    expect(simplifiedStageFor('installation_done')).toBe('installation');
    expect(simplifiedStageFor('meter_done')).toBe('inspection_meter');
    expect(simplifiedStageFor('project_closed')).toBe('completed');
    expect(simplifiedStageLabel('subsidy_pending')).toBe('Inspection & Meter');
  });

  it('supports the optional loan branch in the compact workflow', () => {
    expect(allowedNextSimplifiedStages('project_created')).toEqual(['loan_progress', 'material_dispatch']);
    expect(allowedNextSimplifiedStages('loan_progress')).toEqual(['material_dispatch']);
    expect(allowedNextSimplifiedStages('material_dispatched')).toEqual(['installation']);
    expect(allowedNextSimplifiedStages('project_closed')).toEqual([]);
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
