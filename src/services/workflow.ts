import type { MaterialRequirement, ProjectStage, Quotation, StageHistory } from '../types/domain';

export const projectStages: { id: ProjectStage; label: string }[] = [
  { id: 'project_created', label: 'Project Created' }, { id: 'planning_done', label: 'Project Planning Done' },
  { id: 'loan_required', label: 'Loan Required' }, { id: 'loan_not_required', label: 'Loan Not Required' },
  { id: 'loan_application_pending', label: 'Loan Application Pending' }, { id: 'loan_applied', label: 'Applied for Loan' },
  { id: 'loan_sanctioned', label: 'Loan Sanctioned' }, { id: 'loan_rejected', label: 'Loan Rejected' },
  { id: 'documentation_pending', label: 'Documentation Pending' }, { id: 'documentation_completed', label: 'Documentation Completed' },
  { id: 'material_requirement_generated', label: 'Material Requirement Generated' }, { id: 'material_reserved', label: 'Material Reserved' },
  { id: 'material_dispatched', label: 'Material Dispatched to Site' }, { id: 'installation_in_progress', label: 'Installation In Progress' },
  { id: 'installation_done', label: 'Project Installation Done' }, { id: 'inspection_pending', label: 'PGVCL Inspection Pending' },
  { id: 'inspection_done', label: 'PGVCL Inspection Done' }, { id: 'meter_pending', label: 'Meter Installation Pending' },
  { id: 'meter_done', label: 'Meter Installation Done' }, { id: 'commissioning_done', label: 'Commissioning Done' },
  { id: 'subsidy_pending', label: 'Subsidy Pending' }, { id: 'subsidy_passed', label: 'Subsidy Passed' },
  { id: 'handover_completed', label: 'Handover Completed' }, { id: 'project_closed', label: 'Project Closed' },
];

const transitions: Record<ProjectStage, ProjectStage[]> = {
  project_created: ['planning_done'], planning_done: ['loan_required', 'loan_not_required'],
  loan_required: ['loan_application_pending'], loan_application_pending: ['loan_applied'],
  loan_applied: ['loan_sanctioned', 'loan_rejected'], loan_rejected: ['loan_application_pending', 'documentation_pending'],
  loan_sanctioned: ['documentation_pending'], loan_not_required: ['documentation_pending'],
  documentation_pending: ['documentation_completed'], documentation_completed: ['material_requirement_generated'],
  material_requirement_generated: ['material_reserved'], material_reserved: ['material_dispatched'],
  material_dispatched: ['installation_in_progress'], installation_in_progress: ['installation_done'],
  installation_done: ['inspection_pending'], inspection_pending: ['inspection_done'], inspection_done: ['meter_pending'],
  meter_pending: ['meter_done'], meter_done: ['commissioning_done'], commissioning_done: ['subsidy_pending', 'handover_completed'],
  subsidy_pending: ['subsidy_passed'], subsidy_passed: ['handover_completed'], handover_completed: ['project_closed'], project_closed: [],
};

export function canTransition(from: ProjectStage, to: ProjectStage): boolean {
  return transitions[from].includes(to);
}

export function allowedNextStages(from: ProjectStage): ProjectStage[] { return transitions[from]; }

export function createStageHistory(fromStage: ProjectStage | null, toStage: ProjectStage, userId: string, note = ''): StageHistory {
  return {
    id: crypto.randomUUID(), fromStage, toStage, changedBy: userId, note,
    changedAt: new Date().toISOString(),
  };
}

export function bomFromQuote(quote: Quotation): MaterialRequirement[] {
  const requirements = quote.items.filter((item) => item.selected && !item.internalOnly).map((item) => ({
    id: crypto.randomUUID(), itemCode: item.description.toUpperCase().replace(/[^A-Z0-9]+/g, '-').slice(0, 30),
    itemName: item.description, specification: [item.brand, item.specification].filter(Boolean).join(' - '),
    requiredQty: item.quantity, reservedQty: 0, issuedQty: 0, unit: item.unit, shortageQty: item.quantity,
  }));
  if (!requirements.some((item) => item.itemName.toLowerCase().includes('panel'))) {
    requirements.unshift({
      id: crypto.randomUUID(), itemCode: `PV-${quote.panelBrand}-${quote.panelWattage}`,
      itemName: `${quote.panelBrand} ${quote.panelTechnology} Solar Panel`,
      specification: `${quote.panelWattage} Wp`, requiredQty: quote.panelQuantity,
      reservedQty: 0, issuedQty: 0, unit: 'Nos', shortageQty: quote.panelQuantity,
    });
  }
  return requirements;
}

export function reserveMaterials(requirements: MaterialRequirement[], stockByCode: Record<string, number>): MaterialRequirement[] {
  return requirements.map((item) => {
    const available = Math.max(0, stockByCode[item.itemCode] ?? 0);
    const reservedQty = Math.min(item.requiredQty, available);
    return { ...item, reservedQty, shortageQty: Math.max(0, item.requiredQty - reservedQty) };
  });
}
