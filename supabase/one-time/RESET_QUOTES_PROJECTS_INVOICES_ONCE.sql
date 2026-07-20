-- ONE-TIME PRODUCTION RESET REQUESTED BY THE OWNER.
-- Run this file once in Supabase SQL Editor after taking a database backup.
-- It removes quotations, projects, customer invoices and their dependent operational rows.
-- It preserves customers, users, areas, dealers, master price lists, inventory purchase history and settings.

begin;

create temporary table reset_quote_ids on commit drop as select id from public.quotations;
create temporary table reset_project_ids on commit drop as select id from public.projects;
create temporary table reset_invoice_ids on commit drop as select id from public.customer_invoices;
create temporary table reset_agreement_ids on commit drop as select id from public.agreements where quotation_id in(select id from reset_quote_ids);
create temporary table reset_commission_ids on commit drop as select id from public.dealer_commissions where quotation_id in(select id from reset_quote_ids) or project_id in(select id from reset_project_ids);

delete from public.dealer_commission_payments where commission_id in(select id from reset_commission_ids);
delete from public.payments where project_id in(select id from reset_project_ids) or invoice_id in(select id from reset_invoice_ids);
delete from public.expenses where project_id in(select id from reset_project_ids);
delete from public.customer_invoice_items where invoice_id in(select id from reset_invoice_ids);
delete from public.customer_invoices where id in(select id from reset_invoice_ids);
delete from public.installation_materials where project_id in(select id from reset_project_ids);
delete from public.inventory_serials where project_id in(select id from reset_project_ids);
delete from public.stock_transactions where project_id in(select id from reset_project_ids);
delete from public.dealer_commissions where id in(select id from reset_commission_ids);
delete from public.project_documents where project_id in(select id from reset_project_ids);
delete from public.project_material_requirements where project_id in(select id from reset_project_ids);
delete from public.project_stage_history where project_id in(select id from reset_project_ids);
update public.agreements set project_id=null where project_id in(select id from reset_project_ids);
delete from public.projects where id in(select id from reset_project_ids);
delete from public.agreement_signatures where agreement_id in(select id from reset_agreement_ids);
delete from public.agreements where id in(select id from reset_agreement_ids);
delete from public.quotation_overrides where quotation_id in(select id from reset_quote_ids);
delete from public.quotation_status_history where quotation_id in(select id from reset_quote_ids);
delete from public.quotation_items where quotation_version_id in(select id from public.quotation_versions where quotation_id in(select id from reset_quote_ids));
delete from public.quotation_versions where quotation_id in(select id from reset_quote_ids);
delete from public.quotations where id in(select id from reset_quote_ids);

insert into public.document_counters(document_type,financial_year,last_number)
values('quotation',to_char(current_date,'YYYY'),0),('invoice',to_char(current_date,'YYYY'),0),('project',to_char(current_date,'YYYY'),0)
on conflict(document_type) do update set financial_year=excluded.financial_year,last_number=0,updated_at=now();

update public.company_settings
set value=jsonb_set(jsonb_set(value,'{quotationNumbering,nextNumber}','1'::jsonb,true),'{invoiceNumbering,nextNumber}','1'::jsonb,true),updated_at=now()
where key='crm.settings';

insert into public.audit_logs(action,entity_type,reason,metadata)
values('owner_requested_transaction_reset','system','One-time reset of quotations, projects and customer invoices',jsonb_build_object('resetAt',now()));

commit;

-- Expected verification result after the commit: 0 / 0 / 0
select
 (select count(*) from public.quotations) as quotations,
 (select count(*) from public.projects) as projects,
 (select count(*) from public.customer_invoices) as customer_invoices;
