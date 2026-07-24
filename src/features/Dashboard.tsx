import {
  AlertTriangle,
  ArrowRight,
  BadgeIndianRupee,
  Boxes,
  FileClock,
  FolderKanban,
  Gauge,
  Plus,
  ReceiptText,
  Users,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { PageHeader, Status } from '../components/Ui';
import { useCrm } from '../lib/CrmContext';
import { formatDate, formatInr } from '../services/calculations';
import {
  simplifiedProjectStages,
  simplifiedStageFor,
  simplifiedStageLabel,
} from '../services/workflow';

type DashboardTarget = 'customers' | 'quotations' | 'projects' | 'inventory';

export function Dashboard({ onNavigate }: { onNavigate: (target: DashboardTarget) => void }) {
  const { data } = useCrm();
  if (!data) return null;

  const dealer = data.profile.role === 'dealer';
  const admin = data.profile.role === 'admin';
  const shortages = data.projects.flatMap((project) => project.materials).filter((item) => item.shortageQty > 0).length;
  const installed = data.projects.filter((project) =>
    ['installation', 'inspection_meter', 'completed'].includes(simplifiedStageFor(project.stage)),
  );
  const capacity = installed.reduce((total, project) => total + project.acceptedQuoteSnapshot.dcCapacityKw, 0);
  const commissions = data.commissions.reduce(
    (total, commission) => ({
      total: total.total + commission.totalCommission,
      paid: total.paid + commission.amountPaid,
    }),
    { total: 0, paid: 0 },
  );
  const sentQuotations = data.quotations.filter((quote) => ['sent', 'pending'].includes(quote.status));
  const activeProjects = data.projects.filter((project) => project.stage !== 'project_closed');
  const recentProjects = [...data.projects]
    .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt))
    .slice(0, 6);
  const recentQuotations = [...data.quotations]
    .sort((left, right) => (right.updatedAt ?? right.createdAt).localeCompare(left.updatedAt ?? left.createdAt))
    .slice(0, 6);

  const cards: Array<readonly [string, string | number, LucideIcon, string]> = dealer
    ? [
        ['My Customers', data.customers.length, Users, 'info'],
        ['My Quotations', data.quotations.length, ReceiptText, 'neutral'],
        ['Draft Quotations', data.quotations.filter((quote) => quote.status === 'draft').length, FileClock, 'warn'],
        ['Sent / Pending', sentQuotations.length, FileClock, 'info'],
      ]
    : [
        ['Customers', data.customers.length, Users, 'info'],
        ['Active Projects', activeProjects.length, FolderKanban, 'good'],
        ['Pending Quotations', sentQuotations.length, FileClock, 'warn'],
        ['Installed Capacity', `${capacity.toFixed(2)} kW`, Gauge, 'good'],
        ['Material Shortages', shortages, Boxes, shortages ? 'bad' : 'good'],
        ...(admin
          ? [['Commission Due', formatInr(commissions.total - commissions.paid), BadgeIndianRupee, 'warn'] as const]
          : []),
      ];

  return <div className="ops-dashboard">
    <PageHeader
      title={dealer ? 'Dealer Workspace' : admin ? 'Operations Command Centre' : 'Area Operations'}
      subtitle={dealer
        ? 'Customers and quotations in one fast workspace.'
        : 'A compact live view of quotations, project delivery and operational alerts.'}
      actions={<>
        <button className="btn" onClick={() => onNavigate('customers')}><Plus size={15}/> New Customer</button>
        <button className="btn btn--primary" onClick={() => onNavigate('quotations')}><ReceiptText size={15}/> New Quotation</button>
      </>}
    />

    <section className="ops-kpi-grid" aria-label="Key business metrics">
      {cards.map(([label, value, Icon, tone]) =>
        <article className={`ops-kpi ops-kpi--${tone}`} key={label}>
          <span className="ops-kpi__icon"><Icon size={18}/></span>
          <div><span>{label}</span><strong>{value}</strong></div>
        </article>,
      )}
    </section>

    {!dealer && <>
      <section className="card ops-workflow">
        <div className="card__title">
          <div><h2>Project Delivery Pipeline</h2><p>Six practical stages only</p></div>
          <button className="btn btn--small" onClick={() => onNavigate('projects')}>Open Projects <ArrowRight size={14}/></button>
        </div>
        <div className="ops-pipeline">
          {simplifiedProjectStages.map((stage, index) => {
            const count = data.projects.filter((project) => simplifiedStageFor(project.stage) === stage.id).length;
            const total = Math.max(data.projects.length, 1);
            return <div className="ops-pipeline__stage" key={stage.id}>
              <div className="ops-pipeline__step"><i>{index + 1}</i><span>{stage.shortLabel}</span><strong>{count}</strong></div>
              <div className="ops-pipeline__bar"><i style={{ width: `${Math.max(count ? 12 : 0, count / total * 100)}%` }}/></div>
            </div>;
          })}
        </div>
      </section>

      <div className="ops-dashboard-grid">
        <section className="card ops-recent">
          <div className="card__title"><div><h2>Recent Projects</h2><p>Latest role-authorised activity</p></div></div>
          {recentProjects.length
            ? <div className="table-card"><table>
                <thead><tr><th>Project</th><th>Customer</th><th>Capacity</th><th>Stage</th><th>Updated</th></tr></thead>
                <tbody>{recentProjects.map((project) => {
                  const customer = data.customers.find((item) => item.id === project.customerId);
                  return <tr key={project.id}>
                    <td><strong>{project.projectNo}</strong></td>
                    <td>{customer?.fullName ?? 'Archived customer'}</td>
                    <td>{project.acceptedQuoteSnapshot.dcCapacityKw.toFixed(3)} kW</td>
                    <td><Status tone={project.stage === 'project_closed' ? 'good' : 'info'}>{simplifiedStageLabel(project.stage)}</Status></td>
                    <td>{formatDate(project.updatedAt)}</td>
                  </tr>;
                })}</tbody>
              </table></div>
            : <p className="ops-empty">Projects appear here after quotation documentation is completed.</p>}
        </section>

        <section className="card ops-attention">
          <div className="card__title"><div><h2>Attention Required</h2><p>Items needing action</p></div></div>
          <div className="attention-list">
            {shortages > 0 && <button onClick={() => onNavigate('inventory')}>
              <AlertTriangle size={17}/><span><strong>Material shortage</strong><small>{shortages} requirement lines need stock.</small></span><Status tone="bad">Action</Status>
            </button>}
            {sentQuotations.slice(0, 5).map((quote) => <button key={quote.id} onClick={() => onNavigate('quotations')}>
              <FileClock size={17}/><span><strong>{quote.quoteNo}</strong><small>Customer follow-up is pending.</small></span><Status tone="warn">{quote.status}</Status>
            </button>)}
            {!shortages && !sentQuotations.length && <div className="ops-all-clear"><span>✓</span><div><strong>All clear</strong><small>No critical pending alert.</small></div></div>}
          </div>
        </section>
      </div>
    </>}

    {dealer && <section className="card ops-recent">
      <div className="card__title"><div><h2>Recent Quotations</h2><p>Your latest customer quotations</p></div><button className="btn btn--small" onClick={() => onNavigate('quotations')}>View All <ArrowRight size={14}/></button></div>
      {recentQuotations.length
        ? <div className="table-card"><table>
            <thead><tr><th>Quotation</th><th>Customer</th><th>Capacity</th><th>Amount</th><th>Status</th></tr></thead>
            <tbody>{recentQuotations.map((quote) => {
              const customer = data.customers.find((item) => item.id === quote.customerId);
              const tone = quote.status === 'rejected' ? 'bad' : quote.status === 'draft' ? 'neutral' : 'info';
              return <tr key={quote.id}><td><strong>{quote.quoteNo}</strong></td><td>{customer?.fullName ?? 'Archived customer'}</td><td>{quote.dcCapacityKw.toFixed(3)} kW</td><td>{formatInr(quote.grandTotal)}</td><td><Status tone={tone}>{quote.status}</Status></td></tr>;
            })}</tbody>
          </table></div>
        : <p className="ops-empty">Create a customer, then prepare the first quotation.</p>}
    </section>}
  </div>;
}
