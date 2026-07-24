import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { CommissionPayment, CrmSettings, Customer, Dealer, Expense, FeasibilityInput, InstallationDetails, Invoice, ManualInvoiceRecord, MaterialRequirement, Payment, Quotation, SiteSurvey, CrmSnapshot, StockTransaction } from '../types/domain';
import * as repo from '../services/repository';
import type { SimplifiedProjectStage } from '../services/workflow';

interface CrmContextValue {
  data: CrmSnapshot | null; loading: boolean; saving: boolean; error: string; refresh: () => Promise<void>;
  saveCustomer: (value: Partial<Customer>) => Promise<void>; saveSurvey: (value: SiteSurvey) => Promise<void>;
  saveQuotation: (value: Quotation) => Promise<void>; setQuotationStatus: (quoteId: string, status: Quotation['status'], reason?: string) => Promise<void>;
  saveAgreementDocument: (quoteId: string, generatedFilePath: string) => Promise<void>;
  saveFeasibilityAndCreateProject: (quoteId: string, input: FeasibilityInput) => Promise<void>;
  updateFeasibilityReport: (quoteId: string, input: FeasibilityInput) => Promise<void>;
  changeProjectStage: (projectId: string, stage: SimplifiedProjectStage, note: string, overrideReason?: string) => Promise<void>;
  addDealer: (value: Dealer) => Promise<void>; addPayment: (value: Payment) => Promise<void>; addExpense: (value: Expense) => Promise<void>;
  issueInvoice: (value: Invoice) => Promise<void>; postStockTransaction: (value: StockTransaction) => Promise<void>;
  saveInstallationAndIssueInvoice: (projectId: string, details: InstallationDetails) => Promise<void>;
  saveManualInvoice: (invoice: ManualInvoiceRecord) => Promise<void>;
  cancelManualInvoice: (invoiceId: string, reason: string) => Promise<void>;
  payCommission: (value: CommissionPayment) => Promise<void>; archiveCustomer: (customerId: string, reason: string) => Promise<void>;
  updateInventoryItem: (value: Record<string, unknown>) => Promise<void>; archiveInventoryItem: (itemId: string, reason: string) => Promise<void>;
  saveProjectMaterials: (projectId: string, materials: MaterialRequirement[], reason: string) => Promise<void>;
  deleteProject: (projectId: string, reason: string) => Promise<void>;
  cancelCustomerInvoice: (invoiceId: string, reason: string) => Promise<void>;
  saveSettings: (settings: CrmSettings) => Promise<void>;
}

const CrmContext = createContext<CrmContextValue | null>(null);

export function CrmProvider({ children }: { children: React.ReactNode }) {
  const [data, setData] = useState<CrmSnapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const refresh = useCallback(async () => {
    setLoading(true); setError('');
    try { setData(await repo.loadSnapshot()); } catch (e) { setError(e instanceof Error ? e.message : 'Unable to load CRM data.'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { void refresh(); }, [refresh]);

  const run = useCallback(async (operation: (current: CrmSnapshot) => Promise<CrmSnapshot>) => {
    if (!data) return;
    setSaving(true); setError('');
    try { setData(await operation(data)); } catch (e) { setError(e instanceof Error ? e.message : 'Save failed.'); throw e; }
    finally { setSaving(false); }
  }, [data]);

  const value = useMemo<CrmContextValue>(() => ({
    data, loading, saving, error, refresh,
    saveCustomer: (v) => run((d) => repo.saveCustomer(d, v)), saveSurvey: (v) => run((d) => repo.saveSurvey(d, v)),
    saveQuotation: (v) => run((d) => repo.saveQuotation(d, v)), setQuotationStatus: (id, status, reason) => run((d) => repo.setQuotationStatus(d, id, status, reason)),
    saveAgreementDocument: (id, path) => run((d) => repo.saveAgreementDocument(d, id, path)),
    saveFeasibilityAndCreateProject: (id, input) => run((d) => repo.saveFeasibilityAndCreateProject(d, id, input)),
    updateFeasibilityReport: (id, input) => run((d) => repo.updateFeasibilityReport(d, id, input)),
    changeProjectStage: (id, stage, note, override) => run((d) => repo.changeProjectStage(d, id, stage, note, override)),
    addDealer: (v) => run((d) => repo.addDealer(d, v)), addPayment: (v) => run((d) => repo.addPayment(d, v)),
    addExpense: (v) => run((d) => repo.addExpense(d, v)),
    issueInvoice: (v) => run((d) => repo.issueInvoice(d, v)), postStockTransaction: (v) => run((d) => repo.postStockTransaction(d, v)),
    saveInstallationAndIssueInvoice: (id, details) => run((d) => repo.saveInstallationAndIssueInvoice(d, id, details)),
    saveManualInvoice: (invoice) => run((d) => repo.saveManualInvoice(d, invoice)),
    cancelManualInvoice: (id, reason) => run((d) => repo.cancelManualInvoice(d, id, reason)),
    payCommission: (v) => run((d) => repo.payCommission(d, v)), archiveCustomer: (id, reason) => run((d) => repo.archiveCustomer(d, id, reason)),
    updateInventoryItem: (v) => run(async () => { await repo.updateInventoryItem(v); return repo.loadSnapshot(); }),
    archiveInventoryItem: (id, reason) => run(async () => { await repo.archiveInventoryItem(id, reason); return repo.loadSnapshot(); }),
    saveProjectMaterials: (id, materials, reason) => run(async () => { await repo.saveProjectMaterials(id, materials, reason); return repo.loadSnapshot(); }),
    deleteProject: (id, reason) => run(() => repo.deleteProject(id, reason)),
    cancelCustomerInvoice: (id, reason) => run(() => repo.cancelCustomerInvoice(id, reason)),
    saveSettings: (settings) => run(async () => { await repo.saveCrmSettings(settings); return repo.loadSnapshot(); }),
  }), [data, error, loading, refresh, run, saving]);
  return <CrmContext.Provider value={value}>{children}</CrmContext.Provider>;
}

export function useCrm() {
  const context = useContext(CrmContext);
  if (!context) throw new Error('useCrm must be used within CrmProvider');
  return context;
}
