-- Ratneswar Engineering Solar CRM - complete clean-project setup
-- Generated from the ordered, idempotent migrations below. Keep this file in GitHub for deployment and audit.

-- ==================================================
-- 202607120001_production_schema.sql
-- ==================================================
-- Ratneswar Engineering Solar EPC CRM - clean production schema
-- Safe for a new Supabase project. All business access requires an authenticated, active profile.
begin;
create extension if not exists pgcrypto;

create type public.app_role as enum ('admin','district_partner','dealer');
create type public.quote_status as enum ('draft','sent','pending','approved','rejected','project_created');
create type public.project_stage as enum ('project_created','planning_done','loan_required','loan_not_required','loan_application_pending','loan_applied','loan_sanctioned','loan_rejected','documentation_pending','documentation_completed','material_requirement_generated','material_reserved','material_dispatched','installation_in_progress','installation_done','inspection_pending','inspection_done','meter_pending','meter_done','commissioning_done','subsidy_pending','subsidy_passed','handover_completed','project_closed');
create type public.stock_transaction_type as enum ('purchase','opening','reservation','issue','return','damage','adjustment','consumption');

create table public.districts (
 id uuid primary key default gen_random_uuid(), code text not null unique, name text not null unique, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade, full_name text not null, role public.app_role not null default 'dealer',
 district_id uuid references public.districts(id), dealer_id uuid, active boolean not null default true,
 last_login_at timestamptz, suspended_at timestamptz, suspended_reason text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint profile_scope check ((not active) or (role='admin' and district_id is null and dealer_id is null) or (role='district_partner' and district_id is not null and dealer_id is null) or (role='dealer' and district_id is not null and dealer_id is not null)) not valid
);
create table public.dealers (
 id uuid primary key default gen_random_uuid(), dealer_no text not null unique, name text not null, mobile text not null, email text, address text,
 district_id uuid not null references public.districts(id), login_user_id uuid unique references public.profiles(id) on delete set null,
 default_commission_type text not null default 'fixed' check(default_commission_type in ('fixed','percentage')),
 default_commission_value numeric(14,2) not null default 0 check(default_commission_value>=0), active boolean not null default true,
 created_by uuid references public.profiles(id), updated_by uuid references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
 unique(district_id,mobile)
);
alter table public.profiles add constraint profiles_dealer_fk foreign key(dealer_id) references public.dealers(id) on delete set null;
alter table public.profiles validate constraint profile_scope;

create table public.document_counters (document_type text primary key, financial_year text not null, last_number bigint not null default 0, updated_at timestamptz not null default now());
create table public.customers (
 id uuid primary key default gen_random_uuid(), customer_no text not null unique, full_name text not null, mobile text not null, alternate_mobile text, email text,
 full_address text not null, village_city text not null, taluka text, district_id uuid not null references public.districts(id), district_name text not null,
 state text not null default 'Gujarat', pin_code text, customer_category text not null check(customer_category in ('Residential','Commercial','Agricultural','Industrial','Institutional','RWA/GHS')),
 discom text not null, consumer_number text, sanctioned_load_kw numeric(10,3), phase text, meter_type text, average_monthly_units numeric(12,2), average_bill numeric(14,2),
 roof_type text, available_roof_area_sq_ft numeric(12,2), gps_link text, assigned_partner_id uuid references public.profiles(id), dealer_id uuid references public.dealers(id),
 lead_status text not null default 'New', notes text, created_by uuid not null references public.profiles(id), updated_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), row_version bigint not null default 1, archived_at timestamptz, archived_by uuid references public.profiles(id), archive_reason text
);
create unique index customer_mobile_active_uq on public.customers(regexp_replace(mobile,'\D','','g')) where archived_at is null;
create unique index customer_consumer_active_uq on public.customers(discom,consumer_number) where archived_at is null and consumer_number is not null and consumer_number<>'';
create index customers_scope_idx on public.customers(district_id,dealer_id,created_at desc);
create index customers_search_idx on public.customers(lower(full_name),mobile,consumer_number);

create table public.customer_documents (
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id), document_type text not null, file_name text not null,
 storage_bucket text not null default 'customer-documents', storage_path text not null unique, file_hash text, masked_identifier text,
 uploaded_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), deleted_at timestamptz
);
create table public.site_surveys (
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id), survey_date date not null, status text not null check(status in ('draft','completed')),
 payload jsonb not null, created_by uuid not null default auth.uid() references public.profiles(id), updated_by uuid default auth.uid() references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);

create table public.price_lists (
 id uuid primary key default gen_random_uuid(), name text not null, version_no integer not null, effective_from date not null, status text not null check(status in ('draft','published','inactive')),
 source_document text not null, created_by uuid references public.profiles(id), published_by uuid references public.profiles(id), created_at timestamptz not null default now(), published_at timestamptz,
 unique(name,version_no)
);
create table public.price_list_items (
 id uuid primary key default gen_random_uuid(), price_list_id uuid not null references public.price_lists(id), panel_brand text not null, panel_technology text not null check(panel_technology in ('Bifacial','TOPCon')),
 panel_wattage integer not null check(panel_wattage>0), panel_quantity integer not null check(panel_quantity>0), dc_capacity_kw numeric(10,3) not null check(dc_capacity_kw>0),
 gross_price numeric(14,2) not null check(gross_price>0), expected_subsidy numeric(14,2), after_subsidy numeric(14,2), active boolean not null default true,
 created_at timestamptz not null default now(), unique(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity)
);
create index price_exact_lookup_idx on public.price_list_items(panel_brand,panel_technology,panel_wattage,panel_quantity) where active;
create table public.inverter_products (id uuid primary key default gen_random_uuid(), brand text not null, model text not null default '', capacity_kw numeric(10,3), active boolean not null default true, created_by uuid references public.profiles(id), created_at timestamptz not null default now(), unique(brand,model,capacity_kw));
create table public.subsidy_rules (
 id uuid primary key default gen_random_uuid(), name text not null, customer_category text not null, effective_from date not null, effective_to date,
 min_kw numeric(10,3) not null default 0, max_kw numeric(10,3), calculation jsonb not null, active boolean not null default true,
 created_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
create table public.tax_rules (
 id uuid primary key default gen_random_uuid(), name text not null, effective_from date not null, effective_to date, gst_rate numeric(7,3) not null check(gst_rate>=0),
 intrastate boolean not null default true, active boolean not null default true, created_by uuid references public.profiles(id), created_at timestamptz not null default now()
);

create table public.quotations (
 id uuid primary key default gen_random_uuid(), quotation_no text not null unique, customer_id uuid not null references public.customers(id), district_id uuid not null references public.districts(id), dealer_id uuid references public.dealers(id),
 current_version integer not null default 1, current_status public.quote_status not null default 'draft', sent_at timestamptz, approved_at timestamptz, rejected_at timestamptz, project_created_at timestamptz,
 created_by uuid not null references public.profiles(id), updated_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table public.quotation_versions (
 id uuid primary key default gen_random_uuid(), quotation_id uuid not null references public.quotations(id), version_no integer not null, price_list_item_id uuid references public.price_list_items(id),
 system_type text not null check(system_type in ('On-grid','Off-grid','Hybrid')), dcr_type text not null check(dcr_type in ('DCR','Non-DCR')), scheme text,
 panel_brand text not null, panel_technology text not null, panel_wattage integer not null, panel_quantity integer not null, dc_capacity_kw numeric(10,3) not null,
 suggested_price numeric(14,2) not null, final_price numeric(14,2) not null, price_override_reason text, gst_included boolean not null default true,
 dealer_commission numeric(14,2) not null default 0, internal_cost numeric(14,2) not null default 0, immutable_snapshot jsonb not null,
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), unique(quotation_id,version_no),
 check(final_price=suggested_price or nullif(trim(price_override_reason),'') is not null)
);
create table public.quotation_items (
 id uuid primary key default gen_random_uuid(), quotation_version_id uuid not null references public.quotation_versions(id), description text not null, brand text, specification text,
 quantity numeric(14,3) not null, unit text not null, rate numeric(14,2) not null default 0, selected boolean not null default true, internal_only boolean not null default false
);
create table public.quotation_status_history (id uuid primary key default gen_random_uuid(), quotation_id uuid not null references public.quotations(id), from_status public.quote_status, to_status public.quote_status not null, reason text, changed_by uuid not null references public.profiles(id), changed_at timestamptz not null default now());
create table public.quotation_overrides (id uuid primary key default gen_random_uuid(), quotation_id uuid not null references public.quotations(id), version_no integer not null, suggested_price numeric(14,2) not null, final_price numeric(14,2) not null, reason text not null, created_by uuid not null references public.profiles(id), created_at timestamptz not null default now());

create table public.agreements (
 id uuid primary key default gen_random_uuid(), agreement_no text not null unique, customer_id uuid not null references public.customers(id), quotation_id uuid not null unique references public.quotations(id), project_id uuid,
 agreement_date date not null, status text not null check(status in ('draft','generated','superseded')), capacity_kw numeric(10,3) not null, gross_price numeric(14,2) not null,
 signature_path text, generated_file_path text not null, snapshot jsonb not null, generated_by uuid not null references public.profiles(id), created_at timestamptz not null default now()
);
create table public.agreement_signatures (id uuid primary key default gen_random_uuid(), agreement_id uuid not null references public.agreements(id), party text not null, storage_path text not null, file_hash text, crop_metadata jsonb, uploaded_by uuid not null references public.profiles(id), created_at timestamptz not null default now());
create table public.projects (
 id uuid primary key default gen_random_uuid(), project_no text not null unique, customer_id uuid not null references public.customers(id), quotation_id uuid not null unique references public.quotations(id), agreement_id uuid not null unique references public.agreements(id),
 district_id uuid not null references public.districts(id), dealer_id uuid references public.dealers(id), current_stage public.project_stage not null default 'project_created', accepted_quotation_snapshot jsonb not null,
 assigned_partner_id uuid references public.profiles(id), created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), closed_at timestamptz, row_version bigint not null default 1
);
alter table public.agreements add constraint agreement_project_fk foreign key(project_id) references public.projects(id);
create table public.project_stage_history (id uuid primary key default gen_random_uuid(), project_id uuid not null references public.projects(id), from_stage public.project_stage, to_stage public.project_stage not null, note text, evidence_path text, override_reason text, changed_by uuid not null references public.profiles(id), changed_at timestamptz not null default now());
create table public.project_documents (id uuid primary key default gen_random_uuid(), project_id uuid not null references public.projects(id), document_type text not null, storage_path text not null unique, file_name text not null, uploaded_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), deleted_at timestamptz);
create table public.project_material_requirements (id uuid primary key default gen_random_uuid(), project_id uuid not null references public.projects(id), inventory_item_id uuid, item_code text not null, item_name text not null, specification text, required_qty numeric(14,3) not null, reserved_qty numeric(14,3) not null default 0, issued_qty numeric(14,3) not null default 0, unit text not null, created_at timestamptz not null default now());
create table public.installation_materials (id uuid primary key default gen_random_uuid(), project_id uuid not null unique references public.projects(id), details jsonb not null, created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table public.inventory_items (
 id uuid primary key default gen_random_uuid(), item_code text not null unique, item_name text not null, category text not null, brand text, model text, specification text, unit text not null,
 district_id uuid references public.districts(id), serialized boolean not null default false, reorder_level numeric(14,3) not null default 0,
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
alter table public.project_material_requirements add constraint requirement_inventory_fk foreign key(inventory_item_id) references public.inventory_items(id);
create table public.inventory_serials (id uuid primary key default gen_random_uuid(), inventory_item_id uuid not null references public.inventory_items(id), serial_number text not null unique, status text not null check(status in ('available','reserved','issued','installed','returned','damaged')), project_id uuid references public.projects(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.stock_transactions (
 id uuid primary key default gen_random_uuid(), inventory_item_id uuid not null references public.inventory_items(id), transaction_type public.stock_transaction_type not null, quantity numeric(14,3) not null check(quantity>0),
 project_id uuid references public.projects(id), purchase_invoice_id uuid, unit_rate numeric(14,2), tax_details jsonb, batch text, reference_no text, reason text,
 idempotency_key text not null unique, occurred_at timestamptz not null default now(), created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(),
 check(transaction_type not in ('damage','adjustment') or nullif(trim(reason),'') is not null)
);
create table public.purchase_invoices (
 id uuid primary key default gen_random_uuid(), vendor_name text not null, vendor_gstin text, invoice_number text not null, invoice_date date not null, gross_total numeric(14,2) not null,
 file_hash text not null unique, storage_path text, status text not null default 'posted' check(status in ('draft','posted','cancelled')), snapshot jsonb not null,
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), unique(vendor_name,invoice_number)
);
alter table public.stock_transactions add constraint stock_purchase_fk foreign key(purchase_invoice_id) references public.purchase_invoices(id);
create table public.purchase_invoice_items (id uuid primary key default gen_random_uuid(), purchase_invoice_id uuid not null references public.purchase_invoices(id), inventory_item_id uuid not null references public.inventory_items(id), description text not null, brand text, model text, hsn_sac text, quantity numeric(14,3) not null, unit text not null, rate numeric(14,2) not null, tax_rate numeric(7,3) not null default 0, total numeric(14,2) not null, serial_numbers text[] not null default '{}');

create table public.dealer_commissions (
 id uuid primary key default gen_random_uuid(), dealer_id uuid not null references public.dealers(id), customer_id uuid not null references public.customers(id), project_id uuid not null unique references public.projects(id), quotation_id uuid not null references public.quotations(id),
 commission_type text not null check(commission_type in ('fixed','percentage')), commission_value numeric(14,3) not null, total_commission numeric(14,2) not null check(total_commission>=0), amount_paid numeric(14,2) not null default 0 check(amount_paid>=0),
 status text not null default 'unpaid' check(status in ('unpaid','partial','paid','cancelled')), created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(amount_paid<=total_commission)
);
create table public.dealer_commission_payments (id uuid primary key default gen_random_uuid(), commission_id uuid not null references public.dealer_commissions(id), payment_date date not null, amount numeric(14,2) not null check(amount>0), mode text not null, reference_no text, notes text, created_by uuid not null references public.profiles(id), created_at timestamptz not null default now());
create table public.customer_invoices (
 id uuid primary key default gen_random_uuid(), invoice_no text not null unique, customer_id uuid not null references public.customers(id), project_id uuid not null references public.projects(id), invoice_date date not null, place_of_supply text not null,
 status text not null check(status in ('issued','paid','cancelled','credited')), tax_rule_id uuid references public.tax_rules(id), taxable_value numeric(14,2) not null, cgst numeric(14,2) not null default 0, sgst numeric(14,2) not null default 0, igst numeric(14,2) not null default 0, round_off numeric(14,2) not null default 0, grand_total numeric(14,2) not null,
 snapshot jsonb not null, issued_by uuid not null references public.profiles(id), issued_at timestamptz not null default now(), cancelled_at timestamptz, cancellation_reason text
);
create unique index one_active_invoice_per_project on public.customer_invoices(project_id) where status in ('issued','paid');
create table public.customer_invoice_items (id uuid primary key default gen_random_uuid(), invoice_id uuid not null references public.customer_invoices(id), description text not null, hsn_sac text, quantity numeric(14,3) not null, unit text not null, taxable_value numeric(14,2) not null, tax_rate numeric(7,3) not null, serial_numbers text[] not null default '{}');
create table public.payments (id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id), project_id uuid references public.projects(id), invoice_id uuid references public.customer_invoices(id), payment_type text not null, amount numeric(14,2) not null check(amount>0), payment_date date not null, mode text not null, reference_no text, notes text, payload jsonb not null, idempotency_key text not null unique, created_by uuid not null default auth.uid() references public.profiles(id), created_at timestamptz not null default now(), deleted_at timestamptz);
create table public.expenses (id uuid primary key default gen_random_uuid(), project_id uuid references public.projects(id), expense_date date not null, category text not null, amount numeric(14,2) not null check(amount>0), vendor text, notes text, payload jsonb not null, created_by uuid not null default auth.uid() references public.profiles(id), created_at timestamptz not null default now(), deleted_at timestamptz);

create table public.company_settings (key text primary key, value jsonb not null, updated_by uuid references public.profiles(id), updated_at timestamptz not null default now());
create table public.audit_logs (id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id), action text not null, entity_type text not null, entity_id uuid, reason text, metadata jsonb not null default '{}', created_at timestamptz not null default now());
create index audit_logs_date_idx on public.audit_logs(created_at desc,action);
create table public.ai_extraction_logs (id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), extraction_type text not null, file_hash text not null, file_names text[] not null, result jsonb not null, status text not null, confirmed_entity_id uuid, created_at timestamptz not null default now());
create index ai_extraction_hash_idx on public.ai_extraction_logs(file_hash,extraction_type);
commit;

-- ==================================================
-- 202607120002_security_functions_views.sql
-- ==================================================
begin;

create or replace function public.current_role() returns public.app_role language sql stable security definer set search_path=public as $$ select role from profiles where id=auth.uid() and active $$;
create or replace function public.current_district() returns uuid language sql stable security definer set search_path=public as $$ select district_id from profiles where id=auth.uid() and active $$;
create or replace function public.current_dealer() returns uuid language sql stable security definer set search_path=public as $$ select dealer_id from profiles where id=auth.uid() and active $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select coalesce(public.current_role()='admin',false) $$;
create or replace function public.can_access_customer(p_customer uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from customers c where c.id=p_customer and c.archived_at is null and (is_admin() or (public.current_role()='district_partner' and c.district_id=current_district()) or (public.current_role()='dealer' and c.dealer_id=current_dealer())))
$$;
create or replace function public.can_access_project(p_project uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from projects p where p.id=p_project and (is_admin() or (public.current_role()='district_partner' and p.district_id=current_district())))
$$;
grant execute on function public.current_role(),public.current_district(),public.current_dealer(),public.is_admin(),public.can_access_customer(uuid),public.can_access_project(uuid) to authenticated;

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
create trigger districts_touch before update on public.districts for each row execute function public.touch_updated_at();
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger dealers_touch before update on public.dealers for each row execute function public.touch_updated_at();
create trigger inventory_touch before update on public.inventory_items for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into profiles(id,full_name,role,active) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'full_name',''),split_part(new.email,'@',1)),'dealer',false) on conflict(id) do nothing; return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.next_document_number(p_type text,p_prefix text) returns text language plpgsql security definer set search_path=public as $$
declare fy text:=to_char(current_date,'YYYY'); n bigint;
begin insert into document_counters(document_type,financial_year,last_number) values(p_type,fy,1)
 on conflict(document_type) do update set last_number=case when document_counters.financial_year=excluded.financial_year then document_counters.last_number+1 else 1 end,financial_year=excluded.financial_year,updated_at=now()
 returning last_number into n; return format('RE/%s/%s/%s',p_prefix,fy,lpad(n::text,4,'0')); end $$;
revoke all on function public.next_document_number(text,text) from public,anon,authenticated;

create or replace view public.profile_current with (security_invoker=true) as
select p.id,p.full_name,p.role,p.district_id,d.name district_name,p.dealer_id,p.active,p.last_login_at,false mfa_verified from profiles p left join districts d on d.id=p.district_id where p.id=auth.uid() and p.active;

create or replace view public.active_price_rows with (security_invoker=true) as
select distinct on(i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity)
 i.id,i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity,i.dc_capacity_kw,i.gross_price,i.expected_subsidy,i.after_subsidy,i.active,
 l.effective_from,l.version_no,l.source_document
from price_list_items i join price_lists l on l.id=i.price_list_id where i.active and l.status='published' and l.effective_from<=current_date
order by i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity,l.effective_from desc,l.version_no desc;

create or replace view public.inventory_balance with (security_invoker=true) as
select i.id,i.item_code,i.item_name,i.category,i.brand,i.model,i.specification,i.unit,i.district_id,d.name district_name,i.reorder_level,
 coalesce(sum(case when t.transaction_type in('purchase','opening','return','adjustment') then t.quantity when t.transaction_type in('issue','damage','consumption') then -t.quantity else 0 end),0)::numeric(14,3) on_hand,
 greatest(coalesce(sum(case when t.transaction_type='reservation' then t.quantity when t.transaction_type='issue' and t.project_id is not null then -t.quantity else 0 end),0),0)::numeric(14,3) reserved,
 (coalesce(sum(case when t.transaction_type in('purchase','opening','return','adjustment') then t.quantity when t.transaction_type in('issue','damage','consumption') then -t.quantity else 0 end),0)-greatest(coalesce(sum(case when t.transaction_type='reservation' then t.quantity when t.transaction_type='issue' and t.project_id is not null then -t.quantity else 0 end),0),0))::numeric(14,3) available,
 coalesce(sum(case when t.transaction_type in('purchase','opening') then t.quantity*coalesce(t.unit_rate,0) else 0 end)/nullif(sum(case when t.transaction_type in('purchase','opening') then t.quantity else 0 end),0),0)::numeric(14,2) average_rate
from inventory_items i left join districts d on d.id=i.district_id left join stock_transactions t on t.inventory_item_id=i.id where i.deleted_at is null group by i.id,d.name;

create or replace view public.quotation_current with (security_invoker=true) as
select q.id,q.customer_id,q.district_id,q.dealer_id,q.created_at,
 (v.immutable_snapshot || jsonb_build_object('id',q.id,'quoteNo',q.quotation_no,'versionNo',q.current_version,'status',q.current_status,'sentAt',q.sent_at,'approvedAt',q.approved_at,'rejectedAt',q.rejected_at)) payload
from quotations q join quotation_versions v on v.quotation_id=q.id and v.version_no=q.current_version where q.deleted_at is null;

create or replace view public.project_current with (security_invoker=true) as
select p.id,p.customer_id,p.district_id,p.created_at,
 jsonb_build_object('id',p.id,'projectNo',p.project_no,'customerId',p.customer_id,'quotationId',p.quotation_id,'agreementId',p.agreement_id,'acceptedQuoteSnapshot',p.accepted_quotation_snapshot,'stage',p.current_stage,'assignedTo',p.assigned_partner_id,'district',d.name,'paymentReceived',coalesce((select sum(amount) from payments x where x.project_id=p.id and x.deleted_at is null),0),'expensesTotal',coalesce((select sum(amount) from expenses x where x.project_id=p.id and x.deleted_at is null),0),'createdAt',p.created_at,'updatedAt',p.updated_at,
 'stageHistory',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'fromStage',h.from_stage,'toStage',h.to_stage,'note',h.note,'changedBy',h.changed_by,'changedAt',h.changed_at) order by h.changed_at) from project_stage_history h where h.project_id=p.id),'[]'::jsonb),
 'materials',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'itemCode',m.item_code,'itemName',m.item_name,'specification',m.specification,'requiredQty',m.required_qty,'reservedQty',m.reserved_qty,'issuedQty',m.issued_qty,'unit',m.unit,'shortageQty',greatest(m.required_qty-m.reserved_qty,0))) from project_material_requirements m where m.project_id=p.id),'[]'::jsonb),
 'installationMaterials',(select details from installation_materials im where im.project_id=p.id)) payload
from projects p join districts d on d.id=p.district_id;

create or replace function public.record_security_event(p_action text,p_metadata jsonb default '{}') returns void language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null then raise exception 'Authentication required'; end if; update profiles set last_login_at=case when p_action='login' then now() else last_login_at end where id=auth.uid(); insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),p_action,'security',auth.uid(),coalesce(p_metadata,'{}')); end $$;
grant execute on function public.record_security_event(text,jsonb) to authenticated;

create or replace function public.save_customer(p_customer jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid:=coalesce(nullif(p_customer->>'id','')::uuid,gen_random_uuid()); did uuid; dname text; existing customers%rowtype; actor uuid:=auth.uid(); role app_role:=public.current_role();
begin if actor is null or role is null then raise exception 'Not authorised'; end if;
 if role='admin' then select id,name into did,dname from districts where active and name=p_customer->>'district'; else did:=current_district(); select name into dname from districts where id=did; end if;
 if did is null then raise exception 'A valid district is required'; end if;
 select * into existing from customers where id=cid;
 if found then
   if not can_access_customer(cid) then raise exception 'Not authorised'; end if;
   if (p_customer->>'rowVersion') is null or existing.row_version<>(p_customer->>'rowVersion')::bigint then raise exception 'This customer was updated by another user. Refresh and try again'; end if;
   update customers set full_name=trim(p_customer->>'fullName'),mobile=regexp_replace(p_customer->>'mobile','\D','','g'),alternate_mobile=nullif(p_customer->>'alternateMobile',''),email=nullif(lower(p_customer->>'email'),''),full_address=p_customer->>'address',village_city=p_customer->>'villageCity',taluka=nullif(p_customer->>'taluka',''),district_id=did,district_name=dname,state=coalesce(nullif(p_customer->>'state',''),'Gujarat'),pin_code=nullif(p_customer->>'pinCode',''),customer_category=p_customer->>'customerCategory',discom=p_customer->>'discom',consumer_number=nullif(p_customer->>'consumerNumber',''),sanctioned_load_kw=nullif(p_customer->>'sanctionedLoadKw','')::numeric,phase=nullif(p_customer->>'phase',''),meter_type=nullif(p_customer->>'meterType',''),average_monthly_units=nullif(p_customer->>'averageMonthlyUnits','')::numeric,average_bill=nullif(p_customer->>'averageBill','')::numeric,roof_type=nullif(p_customer->>'roofType',''),available_roof_area_sq_ft=nullif(p_customer->>'availableRoofAreaSqFt','')::numeric,gps_link=nullif(p_customer->>'gpsLink',''),dealer_id=case when role='dealer' then current_dealer() else nullif(p_customer->>'dealerId','')::uuid end,assigned_partner_id=case when role='district_partner' then actor else nullif(p_customer->>'assignedPartnerId','')::uuid end,lead_status=coalesce(nullif(p_customer->>'leadStatus',''),'New'),notes=nullif(p_customer->>'notes',''),updated_by=actor,updated_at=now(),row_version=row_version+1 where id=cid;
   insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(actor,'customer_updated','customer',cid,jsonb_build_object('previousVersion',existing.row_version));
 else
   if role='dealer' and current_dealer() is null then raise exception 'Dealer profile is incomplete'; end if;
   insert into customers(id,customer_no,full_name,mobile,alternate_mobile,email,full_address,village_city,taluka,district_id,district_name,state,pin_code,customer_category,discom,consumer_number,sanctioned_load_kw,phase,meter_type,average_monthly_units,average_bill,roof_type,available_roof_area_sq_ft,gps_link,assigned_partner_id,dealer_id,lead_status,notes,created_by,updated_by)
   values(cid,next_document_number('customer','CU'),trim(p_customer->>'fullName'),regexp_replace(p_customer->>'mobile','\D','','g'),nullif(p_customer->>'alternateMobile',''),nullif(lower(p_customer->>'email'),''),p_customer->>'address',p_customer->>'villageCity',nullif(p_customer->>'taluka',''),did,dname,coalesce(nullif(p_customer->>'state',''),'Gujarat'),nullif(p_customer->>'pinCode',''),p_customer->>'customerCategory',p_customer->>'discom',nullif(p_customer->>'consumerNumber',''),nullif(p_customer->>'sanctionedLoadKw','')::numeric,nullif(p_customer->>'phase',''),nullif(p_customer->>'meterType',''),nullif(p_customer->>'averageMonthlyUnits','')::numeric,nullif(p_customer->>'averageBill','')::numeric,nullif(p_customer->>'roofType',''),nullif(p_customer->>'availableRoofAreaSqFt','')::numeric,nullif(p_customer->>'gpsLink',''),case when role='district_partner' then actor else nullif(p_customer->>'assignedPartnerId','')::uuid end,case when role='dealer' then current_dealer() else nullif(p_customer->>'dealerId','')::uuid end,coalesce(nullif(p_customer->>'leadStatus',''),'New'),nullif(p_customer->>'notes',''),actor,actor);
   insert into audit_logs(actor_id,action,entity_type,entity_id) values(actor,'customer_created','customer',cid);
 end if; return cid;
exception when unique_violation then raise exception 'Duplicate mobile number or DISCOM consumer number'; end $$;
grant execute on function public.save_customer(jsonb) to authenticated;

create or replace function public.archive_customer(p_customer_id uuid,p_reason text) returns void language plpgsql security definer set search_path=public as $$
begin if public.current_role() not in('admin','district_partner') or not can_access_customer(p_customer_id) or nullif(trim(p_reason),'') is null then raise exception 'Not authorised or archive reason missing'; end if; update customers set archived_at=now(),archived_by=auth.uid(),archive_reason=p_reason,updated_by=auth.uid(),updated_at=now(),row_version=row_version+1 where id=p_customer_id; insert into audit_logs(actor_id,action,entity_type,entity_id,reason) values(auth.uid(),'customer_archived','customer',p_customer_id,p_reason); end $$;
grant execute on function public.archive_customer(uuid,text) to authenticated;

create or replace function public.save_dealer(p_dealer jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare did uuid; id_ uuid:=coalesce(nullif(p_dealer->>'id','')::uuid,gen_random_uuid());
begin if not is_admin() then raise exception 'Admin access required'; end if; did:=coalesce(nullif(p_dealer->>'districtId','')::uuid,(select id from districts where name=p_dealer->>'district'));
 insert into dealers(id,dealer_no,name,mobile,email,address,district_id,login_user_id,default_commission_type,default_commission_value,active,created_by,updated_by) values(id_,next_document_number('dealer','DL'),p_dealer->>'name',regexp_replace(p_dealer->>'mobile','\D','','g'),nullif(p_dealer->>'email',''),nullif(p_dealer->>'address',''),did,nullif(p_dealer->>'loginUserId','')::uuid,p_dealer->>'commissionType',(p_dealer->>'commissionValue')::numeric,coalesce((p_dealer->>'active')::boolean,true),auth.uid(),auth.uid())
 on conflict(id) do update set name=excluded.name,mobile=excluded.mobile,email=excluded.email,address=excluded.address,district_id=excluded.district_id,login_user_id=excluded.login_user_id,default_commission_type=excluded.default_commission_type,default_commission_value=excluded.default_commission_value,active=excluded.active,updated_by=auth.uid(),updated_at=now();
 insert into audit_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'dealer_saved','dealer',id_); return id_; end $$;
grant execute on function public.save_dealer(jsonb) to authenticated;

create or replace function public.publish_price_row(p_row jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare list_id uuid:=gen_random_uuid(); item_id uuid:=gen_random_uuid(); ver int;
begin if not is_admin() then raise exception 'Admin access required'; end if; select coalesce(max(version_no),0)+1 into ver from price_lists where name='Manual Price Configuration';
 insert into price_lists(id,name,version_no,effective_from,status,source_document,created_by,published_by,published_at) values(list_id,'Manual Price Configuration',ver,(p_row->>'effectiveFrom')::date,'published',p_row->>'sourceDocument',auth.uid(),auth.uid(),now());
 insert into price_list_items(id,price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values(item_id,list_id,upper(p_row->>'panelBrand'),p_row->>'panelTechnology',(p_row->>'panelWattage')::int,(p_row->>'panelQuantity')::int,(p_row->>'capacityKw')::numeric,(p_row->>'price')::numeric,nullif(p_row->>'expectedSubsidy','')::numeric,nullif(p_row->>'afterSubsidy','')::numeric,true);
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'price_published','price_list_item',item_id,p_row); return item_id; end $$;
grant execute on function public.publish_price_row(jsonb) to authenticated;
commit;

-- ==================================================
-- 202607120003_workflow_inventory_rls.sql
-- ==================================================
begin;

create or replace function public.save_quotation_version(p_quote jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare qid uuid; qno text; ver int; old_status quote_status; cid uuid:=(p_quote->>'customerId')::uuid; c customers%rowtype; price active_price_rows%rowtype; final numeric:=(p_quote->>'grandTotal')::numeric; suggested numeric; v_id uuid:=gen_random_uuid(); item jsonb; actor uuid:=auth.uid(); dealer uuid; commission numeric:=0;
begin if not can_access_customer(cid) then raise exception 'Customer is not accessible'; end if; select * into c from customers where id=cid;
 if public.current_role()='dealer' then dealer:=current_dealer(); else dealer:=nullif(p_quote->>'dealerId','')::uuid; end if;
 select * into price from active_price_rows where panel_brand=upper(p_quote->>'panelBrand') and panel_technology=p_quote->>'panelTechnology' and panel_wattage=(p_quote->>'panelWattage')::int and panel_quantity=(p_quote->>'panelQuantity')::int;
 if price.id is null then raise exception 'No exact active price configuration exists'; end if; suggested:=price.gross_price;
 if final<>suggested and nullif(trim(p_quote->>'priceOverrideReason'),'') is null then raise exception 'Price override reason is required'; end if;
 if (p_quote->>'taxMode')<>'inclusive' then raise exception 'Published price is GST-inclusive and cannot be changed to GST-extra'; end if;
 if public.current_role()='dealer' then commission:=0; else commission:=coalesce(nullif(p_quote->>'dealerCommission','')::numeric,0); end if;
 if nullif(p_quote->>'quoteNo','') is not null then select id,quotation_no,current_version+1,current_status into qid,qno,ver,old_status from quotations where quotation_no=p_quote->>'quoteNo' and deleted_at is null; end if;
 if qid is null then qid:=coalesce(nullif(p_quote->>'id','')::uuid,gen_random_uuid());qno:=next_document_number('quotation','QT');ver:=1;insert into quotations(id,quotation_no,customer_id,district_id,dealer_id,current_version,current_status,created_by,updated_by) values(qid,qno,cid,c.district_id,dealer,ver,'draft',actor,actor);insert into quotation_status_history(quotation_id,to_status,changed_by) values(qid,'draft',actor);
 else update quotations set current_version=ver,current_status='draft',dealer_id=dealer,updated_by=actor,updated_at=now(),sent_at=null,approved_at=null,rejected_at=null where id=qid; insert into quotation_status_history(quotation_id,from_status,to_status,reason,changed_by) values(qid,old_status,'draft','Commercial revision created',actor); end if;
 insert into quotation_versions(id,quotation_id,version_no,price_list_item_id,system_type,dcr_type,scheme,panel_brand,panel_technology,panel_wattage,panel_quantity,dc_capacity_kw,suggested_price,final_price,price_override_reason,gst_included,dealer_commission,internal_cost,immutable_snapshot,created_by)
 values(v_id,qid,ver,price.id,p_quote->>'systemType',p_quote->>'dcrType',p_quote->>'scheme',upper(p_quote->>'panelBrand'),p_quote->>'panelTechnology',(p_quote->>'panelWattage')::int,(p_quote->>'panelQuantity')::int,price.dc_capacity_kw,suggested,final,nullif(p_quote->>'priceOverrideReason',''),true,commission,case when public.current_role()='dealer' then 0 else coalesce(nullif(p_quote->>'internalCost','')::numeric,0) end,p_quote||jsonb_build_object('id',qid,'quoteNo',qno,'versionNo',ver,'status','draft','suggestedPrice',suggested,'basePrice',final,'grandTotal',final,'dcCapacityKw',price.dc_capacity_kw,'dealerId',dealer,'dealerCommission',commission,'taxMode','inclusive'),actor);
 for item in select * from jsonb_array_elements(coalesce(p_quote->'items','[]')) loop insert into quotation_items(quotation_version_id,description,brand,specification,quantity,unit,rate,selected,internal_only) values(v_id,item->>'description',nullif(item->>'brand',''),nullif(item->>'specification',''),coalesce((item->>'quantity')::numeric,1),coalesce(item->>'unit','Nos'),coalesce(nullif(item->>'rate','')::numeric,0),coalesce((item->>'selected')::boolean,true),coalesce((item->>'internalOnly')::boolean,false)); end loop;
 if final<>suggested then insert into quotation_overrides(quotation_id,version_no,suggested_price,final_price,reason,created_by) values(qid,ver,suggested,final,p_quote->>'priceOverrideReason',actor); end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(actor,'quotation_version_saved','quotation',qid,nullif(p_quote->>'priceOverrideReason',''),jsonb_build_object('version',ver,'suggested',suggested,'final',final)); return qid; end $$;
grant execute on function public.save_quotation_version(jsonb) to authenticated;

create or replace function public.set_quotation_status(p_quotation_id uuid,p_status quote_status,p_reason text default null) returns void language plpgsql security definer set search_path=public as $$
declare q quotations%rowtype; old quote_status; role app_role:=public.current_role();
begin select * into q from quotations where id=p_quotation_id and deleted_at is null for update; if not can_access_customer(q.customer_id) then raise exception 'Not authorised'; end if; old:=q.current_status;
 if role='dealer' and not(old='draft' and p_status='sent') then raise exception 'Dealer can only send a draft quotation'; end if;
 if role in('admin','district_partner') and not((old='draft' and p_status in('sent','rejected')) or (old in('sent','pending') and p_status in('pending','approved','rejected'))) then raise exception 'Invalid quotation status transition'; end if;
 if p_status='rejected' and nullif(trim(p_reason),'') is null then raise exception 'Rejection reason is required'; end if;
 update quotations set current_status=p_status,updated_by=auth.uid(),updated_at=now(),sent_at=case when p_status='sent' then now() else sent_at end,approved_at=case when p_status='approved' then now() else approved_at end,rejected_at=case when p_status='rejected' then now() else rejected_at end where id=p_quotation_id;
 insert into quotation_status_history(quotation_id,from_status,to_status,reason,changed_by) values(p_quotation_id,old,p_status,p_reason,auth.uid()); insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'quotation_status_changed','quotation',p_quotation_id,p_reason,jsonb_build_object('from',old,'to',p_status)); end $$;
grant execute on function public.set_quotation_status(uuid,quote_status,text) to authenticated;

create or replace function public.can_transition(p_from project_stage,p_to project_stage) returns boolean language sql immutable as $$select case p_from when 'project_created' then p_to='planning_done' when 'planning_done' then p_to in('loan_required','loan_not_required') when 'loan_required' then p_to='loan_application_pending' when 'loan_application_pending' then p_to='loan_applied' when 'loan_applied' then p_to in('loan_sanctioned','loan_rejected') when 'loan_rejected' then p_to in('loan_application_pending','documentation_pending') when 'loan_sanctioned' then p_to='documentation_pending' when 'loan_not_required' then p_to='documentation_pending' when 'documentation_pending' then p_to='documentation_completed' when 'documentation_completed' then p_to='material_requirement_generated' when 'material_requirement_generated' then p_to='material_reserved' when 'material_reserved' then p_to='material_dispatched' when 'material_dispatched' then p_to='installation_in_progress' when 'installation_in_progress' then p_to='installation_done' when 'installation_done' then p_to='inspection_pending' when 'inspection_pending' then p_to='inspection_done' when 'inspection_done' then p_to='meter_pending' when 'meter_pending' then p_to='meter_done' when 'meter_done' then p_to='commissioning_done' when 'commissioning_done' then p_to in('subsidy_pending','handover_completed') when 'subsidy_pending' then p_to='subsidy_passed' when 'subsidy_passed' then p_to='handover_completed' when 'handover_completed' then p_to='project_closed' else false end$$;

create or replace function public.generate_agreement_and_project(p_quotation_id uuid,p_signature_path text,p_generated_file_path text,p_agreement_date date) returns uuid language plpgsql security definer set search_path=public as $$
declare q quotations%rowtype; v quotation_versions%rowtype; c customers%rowtype; aid uuid:=gen_random_uuid(); pid uuid:=gen_random_uuid(); req record; inv record; available numeric; reserve_qty numeric;
begin if public.current_role() not in('admin','district_partner') then raise exception 'Not authorised'; end if; select * into q from quotations where id=p_quotation_id for update; if q.id is null or q.current_status<>'approved' or not can_access_customer(q.customer_id) then raise exception 'Accessible approved quotation required'; end if; if exists(select 1 from projects where quotation_id=q.id) then raise exception 'A project already exists for this quotation'; end if; if nullif(p_generated_file_path,'') is null or nullif(p_signature_path,'') is null then raise exception 'Generated agreement and customer signature are required'; end if; select * into v from quotation_versions where quotation_id=q.id and version_no=q.current_version; select * into c from customers where id=q.customer_id;
 insert into agreements(id,agreement_no,customer_id,quotation_id,agreement_date,status,capacity_kw,gross_price,signature_path,generated_file_path,snapshot,generated_by) values(aid,next_document_number('agreement','AG'),q.customer_id,q.id,p_agreement_date,'generated',v.dc_capacity_kw,v.final_price,p_signature_path,p_generated_file_path,v.immutable_snapshot,auth.uid());
 insert into projects(id,project_no,customer_id,quotation_id,agreement_id,district_id,dealer_id,current_stage,accepted_quotation_snapshot,assigned_partner_id,created_by) values(pid,next_document_number('project','PR'),q.customer_id,q.id,aid,q.district_id,q.dealer_id,'project_created',v.immutable_snapshot,c.assigned_partner_id,auth.uid()); update agreements set project_id=pid where id=aid; update quotations set current_status='project_created',project_created_at=now(),updated_by=auth.uid(),updated_at=now() where id=q.id; insert into quotation_status_history(quotation_id,from_status,to_status,reason,changed_by) values(q.id,'approved','project_created','Agreement generated',auth.uid()); insert into project_stage_history(project_id,to_stage,note,changed_by) values(pid,'project_created','Agreement generated and accepted quotation snapshot locked',auth.uid());
 insert into project_material_requirements(project_id,item_code,item_name,specification,required_qty,unit) values(pid,format('PV-%s-%s',v.panel_brand,v.panel_wattage),format('%s %s Solar Panel',v.panel_brand,v.panel_technology),format('%s Wp',v.panel_wattage),v.panel_quantity,'Nos');
 insert into project_material_requirements(project_id,item_code,item_name,specification,required_qty,unit) select pid,upper(left(regexp_replace(qi.description,'[^A-Za-z0-9]+','-','g'),30)),qi.description,concat_ws(' - ',qi.brand,qi.specification),qi.quantity,qi.unit from quotation_items qi where qi.quotation_version_id=v.id and qi.selected and not qi.internal_only and lower(qi.description) not like '%pv module%';
 for req in select * from project_material_requirements where project_id=pid loop select i.*,b.available into inv from inventory_items i join inventory_balance b on b.id=i.id where i.item_code=req.item_code and (i.district_id is null or i.district_id=q.district_id) limit 1; if inv.id is not null then reserve_qty:=least(req.required_qty,greatest(inv.available,0)); update project_material_requirements set inventory_item_id=inv.id,reserved_qty=reserve_qty where id=req.id; if reserve_qty>0 then insert into stock_transactions(inventory_item_id,transaction_type,quantity,project_id,reference_no,reason,idempotency_key,created_by) values(inv.id,'reservation',reserve_qty,pid,q.quotation_no,'Automatic project reservation',format('project:%s:reserve:%s',pid,req.id),auth.uid()); end if; end if; end loop;
 if q.dealer_id is not null and v.dealer_commission>0 then insert into dealer_commissions(dealer_id,customer_id,project_id,quotation_id,commission_type,commission_value,total_commission,created_by) values(q.dealer_id,q.customer_id,pid,q.id,'fixed',v.dealer_commission,v.dealer_commission,auth.uid()); end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'agreement_generated_project_created','project',pid,jsonb_build_object('agreementId',aid,'quotationId',q.id)); return pid; end $$;
grant execute on function public.generate_agreement_and_project(uuid,text,text,date) to authenticated;

create or replace function public.change_project_stage(p_project_id uuid,p_new_stage project_stage,p_note text default null,p_override_reason text default null) returns void language plpgsql security definer set search_path=public as $$
declare p projects%rowtype; valid boolean;
begin select * into p from projects where id=p_project_id for update; if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if; valid:=can_transition(p.current_stage,p_new_stage); if not valid and (not is_admin() or nullif(trim(p_override_reason),'') is null) then raise exception 'Invalid stage transition'; end if; if nullif(trim(p_note),'') is null then raise exception 'Stage note is required'; end if;
 update projects set current_stage=p_new_stage,updated_at=now(),row_version=row_version+1,closed_at=case when p_new_stage='project_closed' then now() else closed_at end where id=p.id; insert into project_stage_history(project_id,from_stage,to_stage,note,override_reason,changed_by) values(p.id,p.current_stage,p_new_stage,p_note,p_override_reason,auth.uid());
 if p_new_stage='material_dispatched' then insert into stock_transactions(inventory_item_id,transaction_type,quantity,project_id,reference_no,reason,idempotency_key,created_by) select inventory_item_id,'issue',reserved_qty,p.id,p.project_no,'Reserved material dispatched',format('project:%s:issue:%s',p.id,id),auth.uid() from project_material_requirements where project_id=p.id and inventory_item_id is not null and reserved_qty>0 and issued_qty=0 on conflict(idempotency_key) do nothing; update project_material_requirements set issued_qty=reserved_qty where project_id=p.id and reserved_qty>0; end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'project_stage_changed','project',p.id,p_override_reason,jsonb_build_object('from',p.current_stage,'to',p_new_stage,'note',p_note)); end $$;
grant execute on function public.change_project_stage(uuid,project_stage,text,text) to authenticated;

create or replace function public.post_stock_transaction(p_transaction jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare tid uuid:=coalesce(nullif(p_transaction->>'id','')::uuid,gen_random_uuid()); iid uuid:=(p_transaction->>'inventoryItemId')::uuid; typ stock_transaction_type:=(p_transaction->>'transactionType')::stock_transaction_type; qty numeric:=(p_transaction->>'quantity')::numeric; bal inventory_balance%rowtype;
begin if not is_admin() then raise exception 'Admin access required'; end if; if typ in('reservation','issue','consumption') then raise exception 'Project stock transactions must use the project workflow'; end if; if typ in('damage','adjustment') and nullif(trim(p_transaction->>'reason'),'') is null then raise exception 'Adjustment reason is required'; end if; select * into bal from inventory_balance where id=iid; if typ='damage' and coalesce(bal.on_hand,0)<qty then raise exception 'Negative stock is not allowed'; end if;
 insert into stock_transactions(id,inventory_item_id,transaction_type,quantity,project_id,unit_rate,reference_no,reason,idempotency_key,occurred_at,created_by) values(tid,iid,typ,qty,nullif(p_transaction->>'projectId','')::uuid,nullif(p_transaction->>'unitRate','')::numeric,nullif(p_transaction->>'referenceNo',''),nullif(p_transaction->>'reason',''),p_transaction->>'idempotencyKey',coalesce(nullif(p_transaction->>'occurredAt','')::timestamptz,now()),auth.uid()); insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'stock_transaction_posted','inventory_item',iid,p_transaction->>'reason',jsonb_build_object('type',typ,'quantity',qty,'transactionId',tid)); return tid; end $$;
grant execute on function public.post_stock_transaction(jsonb) to authenticated;

create or replace function public.create_inventory_item(p_item jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare iid uuid:=gen_random_uuid();did uuid;
begin if not is_admin() then raise exception 'Admin access required'; end if; did:=nullif(p_item->>'districtId','')::uuid; insert into inventory_items(id,item_code,item_name,category,brand,model,specification,unit,district_id,serialized,reorder_level,created_by) values(iid,upper(trim(p_item->>'itemCode')),trim(p_item->>'itemName'),p_item->>'category',nullif(p_item->>'brand',''),nullif(p_item->>'model',''),nullif(p_item->>'specification',''),p_item->>'unit',did,coalesce((p_item->>'serialized')::boolean,false),coalesce(nullif(p_item->>'reorderLevel','')::numeric,0),auth.uid());insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'inventory_item_created','inventory_item',iid,p_item);return iid;end $$;
grant execute on function public.create_inventory_item(jsonb) to authenticated;

create or replace function public.post_purchase_invoice(p_invoice jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare iid uuid:=gen_random_uuid(); row jsonb; line_total numeric:=0; item_id uuid; idx int:=0; qty numeric;
begin if not is_admin() then raise exception 'Admin access required'; end if; for row in select * from jsonb_array_elements(coalesce(p_invoice->'rows','[]')) loop line_total:=line_total+coalesce((row->>'total')::numeric,0); if nullif(row->>'inventoryItemId','') is null then raise exception 'Every invoice row must be mapped to an inventory item'; end if; end loop; if abs(line_total-(p_invoice->>'total')::numeric)>1 then raise exception 'Invoice row totals do not match the invoice total'; end if;
 insert into purchase_invoices(id,vendor_name,vendor_gstin,invoice_number,invoice_date,gross_total,file_hash,storage_path,snapshot,created_by) values(iid,p_invoice->>'vendorName',nullif(p_invoice->>'gstin',''),p_invoice->>'invoiceNumber',(p_invoice->>'invoiceDate')::date,(p_invoice->>'total')::numeric,p_invoice->>'fileHash',nullif(p_invoice->>'storagePath',''),p_invoice,auth.uid());
 for row in select * from jsonb_array_elements(p_invoice->'rows') loop idx:=idx+1;item_id:=(row->>'inventoryItemId')::uuid;qty:=(row->>'quantity')::numeric;insert into purchase_invoice_items(purchase_invoice_id,inventory_item_id,description,brand,model,hsn_sac,quantity,unit,rate,tax_rate,total,serial_numbers) values(iid,item_id,row->>'description',nullif(row->>'brand',''),nullif(row->>'model',''),nullif(row->>'hsn',''),qty,row->>'unit',(row->>'rate')::numeric,(row->>'tax')::numeric,(row->>'total')::numeric,coalesce(array(select jsonb_array_elements_text(row->'serialNumbers')),'{}'));insert into stock_transactions(inventory_item_id,transaction_type,quantity,purchase_invoice_id,unit_rate,tax_details,reference_no,idempotency_key,created_by) values(item_id,'purchase',qty,iid,(row->>'rate')::numeric,jsonb_build_object('rate',row->>'tax'),p_invoice->>'invoiceNumber',format('purchase:%s:%s',iid,idx),auth.uid()); end loop;
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'purchase_invoice_posted','purchase_invoice',iid,jsonb_build_object('total',p_invoice->>'total','rows',idx)); return iid;
exception when unique_violation then raise exception 'Duplicate vendor invoice number or file upload'; end $$;
grant execute on function public.post_purchase_invoice(jsonb) to authenticated;

create or replace function public.pay_dealer_commission(p_payment jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare pid uuid:=coalesce(nullif(p_payment->>'id','')::uuid,gen_random_uuid()); c dealer_commissions%rowtype; amount numeric:=(p_payment->>'amount')::numeric;
begin if not is_admin() then raise exception 'Admin access required'; end if; select * into c from dealer_commissions where id=(p_payment->>'commissionId')::uuid for update; if c.id is null or amount<=0 or c.amount_paid+amount>c.total_commission then raise exception 'Payment exceeds outstanding commission'; end if; insert into dealer_commission_payments(id,commission_id,payment_date,amount,mode,reference_no,notes,created_by) values(pid,c.id,(p_payment->>'paymentDate')::date,amount,p_payment->>'mode',nullif(p_payment->>'referenceNo',''),nullif(p_payment->>'notes',''),auth.uid()); update dealer_commissions set amount_paid=amount_paid+amount,status=case when amount_paid+amount=total_commission then 'paid' else 'partial' end,updated_at=now() where id=c.id; insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'dealer_commission_paid','dealer_commission',c.id,jsonb_build_object('amount',amount,'paymentId',pid)); return pid; end $$;
grant execute on function public.pay_dealer_commission(jsonb) to authenticated;

create or replace function public.save_installation_and_issue_invoice(p_project_id uuid,p_details jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare p projects%rowtype; q jsonb; expected int; serial_count int; duplicate_count int; tr tax_rules%rowtype; gross numeric; taxable numeric; tax numeric; inv_id uuid:=gen_random_uuid(); inv_no text; serial text; panel_item uuid;
begin select * into p from projects where id=p_project_id for update; if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if; if p.current_stage<>'installation_done' then raise exception 'Invoice is available only after Project Installation Done'; end if; if exists(select 1 from customer_invoices where project_id=p.id and status in('issued','paid')) then raise exception 'An active invoice already exists'; end if; q:=p.accepted_quotation_snapshot;expected:=(q->>'panelQuantity')::int;serial_count:=jsonb_array_length(coalesce(p_details->'panelSerials','[]'));if serial_count<1 then raise exception 'Panel serial numbers are required'; end if;select count(*)-count(distinct value) into duplicate_count from jsonb_array_elements_text(p_details->'panelSerials');if duplicate_count>0 then raise exception 'Duplicate panel serial numbers are not allowed'; end if;if (serial_count<>expected or p_details->>'panelBrand'<>q->>'panelBrand' or (p_details->>'panelWattage')::int<>(q->>'panelWattage')::int) and nullif(trim(p_details->>'overrideReason'),'') is null then raise exception 'Material change reason is required'; end if;
 select inventory_item_id into panel_item from project_material_requirements where project_id=p.id and item_code like 'PV-%' limit 1; if panel_item is null then insert into inventory_items(item_code,item_name,category,brand,model,specification,unit,district_id,serialized,reorder_level,created_by) values(format('PV-%s-%s',p_details->>'panelBrand',p_details->>'panelWattage'),format('%s %s Solar Panel',p_details->>'panelBrand',p_details->>'panelTechnology'),'PV Module',p_details->>'panelBrand',p_details->>'panelTechnology',format('%s Wp',p_details->>'panelWattage'),'Nos',p.district_id,true,0,auth.uid()) on conflict(item_code) do update set item_name=excluded.item_name returning id into panel_item; update project_material_requirements set inventory_item_id=panel_item where project_id=p.id and item_code like 'PV-%'; end if;
 for serial in select jsonb_array_elements_text(p_details->'panelSerials') loop if exists(select 1 from inventory_serials where serial_number=serial) then raise exception 'Installed serial number % already exists',serial; end if; insert into inventory_serials(inventory_item_id,serial_number,status,project_id) values(panel_item,serial,'installed',p.id); end loop;
 insert into installation_materials(project_id,details,created_by) values(p.id,p_details,auth.uid()); select * into tr from tax_rules where active and effective_from<=current_date and (effective_to is null or effective_to>=current_date) order by effective_from desc limit 1; if tr.id is null then raise exception 'No active effective-dated tax rule exists'; end if;gross:=(q->>'grandTotal')::numeric;taxable:=round(gross*100/(100+tr.gst_rate),2);tax:=gross-taxable;inv_no:=next_document_number('invoice','INV');
 insert into customer_invoices(id,invoice_no,customer_id,project_id,invoice_date,place_of_supply,status,tax_rule_id,taxable_value,cgst,sgst,igst,grand_total,snapshot,issued_by) values(inv_id,inv_no,p.customer_id,p.id,current_date,'Gujarat (24)','issued',tr.id,taxable,case when tr.intrastate then round(tax/2,2) else 0 end,case when tr.intrastate then tax-round(tax/2,2) else 0 end,case when tr.intrastate then 0 else tax end,gross,jsonb_build_object('id',inv_id,'invoiceNo',inv_no,'customerId',p.customer_id,'projectId',p.id,'invoiceDate',current_date,'placeOfSupply','Gujarat (24)','status','issued','taxMode','inclusive','taxableValue',taxable,'cgst',case when tr.intrastate then round(tax/2,2) else 0 end,'sgst',case when tr.intrastate then tax-round(tax/2,2) else 0 end,'igst',case when tr.intrastate then 0 else tax end,'roundOff',0,'grandTotal',gross),auth.uid());
 insert into customer_invoice_items(invoice_id,description,hsn_sac,quantity,unit,taxable_value,tax_rate,serial_numbers) values(inv_id,format('Supply and Installation of %s kW Rooftop Solar Power Plant',q->>'dcCapacityKw'),'8541 / 9954',1,'Job',taxable,tr.gst_rate,array(select jsonb_array_elements_text(p_details->'panelSerials'))); insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'customer_invoice_issued','customer_invoice',inv_id,p_details->>'overrideReason',jsonb_build_object('projectId',p.id,'gross',gross,'serialCount',serial_count)); return inv_id; end $$;
grant execute on function public.save_installation_and_issue_invoice(uuid,jsonb) to authenticated;

-- RLS: deny by default, then grant the minimum scoped access needed by the application.
do $$declare t text;begin foreach t in array array['districts','profiles','dealers','document_counters','customers','customer_documents','site_surveys','price_lists','price_list_items','inverter_products','subsidy_rules','tax_rules','quotations','quotation_versions','quotation_items','quotation_status_history','quotation_overrides','agreements','agreement_signatures','projects','project_stage_history','project_documents','project_material_requirements','installation_materials','inventory_items','inventory_serials','stock_transactions','purchase_invoices','purchase_invoice_items','dealer_commissions','dealer_commission_payments','customer_invoices','customer_invoice_items','payments','expenses','company_settings','audit_logs','ai_extraction_logs'] loop execute format('alter table public.%I enable row level security',t);end loop;end$$;
create policy districts_read on districts for select to authenticated using(active or is_admin());
create policy districts_admin on districts for all to authenticated using(is_admin()) with check(is_admin());
create policy profiles_read on profiles for select to authenticated using(id=auth.uid() or is_admin());
create policy profiles_admin on profiles for all to authenticated using(is_admin()) with check(is_admin());
create policy dealers_read on dealers for select to authenticated using(is_admin() or (public.current_role()='district_partner' and district_id=current_district()) or id=current_dealer());
create policy customers_read on customers for select to authenticated using(can_access_customer(id));
create policy customer_documents_access on customer_documents for select to authenticated using(can_access_customer(customer_id));
create policy customer_documents_insert on customer_documents for insert to authenticated with check(can_access_customer(customer_id));
create policy surveys_access on site_surveys for all to authenticated using(can_access_customer(customer_id)) with check(can_access_customer(customer_id));
create policy price_lists_read on price_lists for select to authenticated using(true);create policy price_items_read on price_list_items for select to authenticated using(true);create policy inverters_read on inverter_products for select to authenticated using(true);create policy subsidy_read on subsidy_rules for select to authenticated using(true);create policy tax_read on tax_rules for select to authenticated using(public.current_role() in('admin','district_partner'));
create policy subsidy_admin_write on subsidy_rules for insert to authenticated with check(is_admin());create policy tax_admin_write on tax_rules for insert to authenticated with check(is_admin());
create policy quotations_read on quotations for select to authenticated using(can_access_customer(customer_id));
create policy quote_versions_read on quotation_versions for select to authenticated using(exists(select 1 from quotations q where q.id=quotation_id and can_access_customer(q.customer_id)));
create policy quote_items_read on quotation_items for select to authenticated using(exists(select 1 from quotation_versions v join quotations q on q.id=v.quotation_id where v.id=quotation_version_id and can_access_customer(q.customer_id)));
create policy quote_history_read on quotation_status_history for select to authenticated using(exists(select 1 from quotations q where q.id=quotation_id and can_access_customer(q.customer_id)));
create policy quote_override_internal on quotation_overrides for select to authenticated using(public.current_role() in('admin','district_partner') and exists(select 1 from quotations q where q.id=quotation_id and can_access_customer(q.customer_id)));
create policy agreements_read on agreements for select to authenticated using(public.current_role() in('admin','district_partner') and can_access_customer(customer_id));
create policy agreement_signatures_read on agreement_signatures for select to authenticated using(exists(select 1 from agreements a where a.id=agreement_id and public.current_role() in('admin','district_partner') and can_access_customer(a.customer_id)));
create policy projects_read on projects for select to authenticated using(can_access_project(id));
create policy project_history_read on project_stage_history for select to authenticated using(can_access_project(project_id));
create policy project_documents_read on project_documents for select to authenticated using(can_access_project(project_id));
create policy requirements_read on project_material_requirements for select to authenticated using(can_access_project(project_id));
create policy installation_read on installation_materials for select to authenticated using(can_access_project(project_id));
create policy inventory_read on inventory_items for select to authenticated using(is_admin() or (public.current_role()='district_partner' and (district_id is null or district_id=current_district())));
create policy inventory_serials_read on inventory_serials for select to authenticated using(is_admin() or exists(select 1 from inventory_items i where i.id=inventory_item_id and (i.district_id is null or i.district_id=current_district()) and public.current_role()='district_partner'));
create policy stock_read on stock_transactions for select to authenticated using(is_admin() or (public.current_role()='district_partner' and (can_access_project(project_id) or exists(select 1 from inventory_items i where i.id=inventory_item_id and i.district_id=current_district()))));
create policy purchase_admin_read on purchase_invoices for select to authenticated using(is_admin());create policy purchase_items_admin_read on purchase_invoice_items for select to authenticated using(is_admin());
create policy commissions_internal_read on dealer_commissions for select to authenticated using(is_admin() or (public.current_role()='district_partner' and exists(select 1 from projects p where p.id=project_id and p.district_id=current_district())));
create policy commission_payments_internal_read on dealer_commission_payments for select to authenticated using(is_admin() or (public.current_role()='district_partner' and exists(select 1 from dealer_commissions c join projects p on p.id=c.project_id where c.id=commission_id and p.district_id=current_district())));
create policy invoices_read on customer_invoices for select to authenticated using(public.current_role() in('admin','district_partner') and can_access_customer(customer_id));create policy invoice_items_read on customer_invoice_items for select to authenticated using(exists(select 1 from customer_invoices i where i.id=invoice_id and can_access_customer(i.customer_id) and public.current_role() in('admin','district_partner')));
create policy payments_read on payments for select to authenticated using(public.current_role() in('admin','district_partner') and can_access_customer(customer_id));create policy payments_insert on payments for insert to authenticated with check(public.current_role() in('admin','district_partner') and can_access_customer(customer_id));
create policy expenses_read on expenses for select to authenticated using(is_admin() or (public.current_role()='district_partner' and (project_id is null or can_access_project(project_id))));create policy expenses_insert on expenses for insert to authenticated with check(is_admin() or (public.current_role()='district_partner' and project_id is not null and can_access_project(project_id)));
create policy settings_admin on company_settings for all to authenticated using(is_admin()) with check(is_admin());
create policy audit_admin_read on audit_logs for select to authenticated using(is_admin());
create policy ai_logs_read on ai_extraction_logs for select to authenticated using(user_id=auth.uid() or is_admin());create policy ai_logs_insert on ai_extraction_logs for insert to authenticated with check(user_id=auth.uid());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('customer-documents','customer-documents',false,15728640,array['application/pdf','image/jpeg','image/png']),('agreement-files','agreement-files',false,15728640,array['application/pdf','image/jpeg','image/png']),('project-files','project-files',false,15728640,array['application/pdf','image/jpeg','image/png']),('invoice-files','invoice-files',false,15728640,array['application/pdf']),('inventory-invoices','inventory-invoices',false,15728640,array['application/pdf','image/jpeg','image/png']) on conflict(id) do update set public=false;
create policy storage_customer_read on storage.objects for select to authenticated using(bucket_id='customer-documents' and can_access_customer((storage.foldername(name))[1]::uuid));
create policy storage_customer_insert on storage.objects for insert to authenticated with check(bucket_id='customer-documents' and can_access_customer((storage.foldername(name))[1]::uuid));
create policy storage_agreement_access on storage.objects for select to authenticated using(bucket_id='agreement-files' and public.current_role() in('admin','district_partner'));
create policy storage_agreement_insert on storage.objects for insert to authenticated with check(bucket_id='agreement-files' and public.current_role() in('admin','district_partner'));
create policy storage_project_access on storage.objects for select to authenticated using(bucket_id='project-files' and can_access_project((storage.foldername(name))[1]::uuid));
create policy storage_project_insert on storage.objects for insert to authenticated with check(bucket_id='project-files' and can_access_project((storage.foldername(name))[1]::uuid));
create policy storage_invoice_access on storage.objects for select to authenticated using(bucket_id='invoice-files' and public.current_role() in('admin','district_partner'));
create policy storage_inventory_admin on storage.objects for all to authenticated using(bucket_id='inventory-invoices' and is_admin()) with check(bucket_id='inventory-invoices' and is_admin());

grant select on all tables in schema public to authenticated;grant insert,update on public.site_surveys,public.customer_documents,public.payments,public.expenses,public.ai_extraction_logs,public.company_settings to authenticated;grant insert on public.tax_rules,public.subsidy_rules to authenticated;
revoke insert,update,delete on public.audit_logs,public.quotation_versions,public.quotation_status_history,public.stock_transactions,public.dealer_commission_payments,public.customer_invoices from authenticated;
commit;

-- ==================================================
-- 202607120004_verified_reference_seed.sql
-- ==================================================
begin;
insert into public.districts(code,name) values ('KUT','Kutch'),('JUN','Junagadh'),('RAJ','Rajkot'),('AHM','Ahmedabad'),('JAM','Jamnagar'),('MOR','Morbi') on conflict do nothing;
insert into public.inverter_products(brand,model,capacity_kw,created_by) values ('KSOLE','',null,null),('Solaryan','',null,null),('Suryyan','',null,null),('Polycab','',null,null) on conflict do nothing;

do $$declare l580 uuid:=gen_random_uuid();l610 uuid:=gen_random_uuid();begin
insert into price_lists(id,name,version_no,effective_from,status,source_document,published_at) values
 (l580,'Waaree TOPCon 580 W Official',1,date '2026-07-12','published','Ratneswar_WAREE_TOPCORN_580WP.pdf',now()),
 (l610,'Waaree TOPCon 610/615 W Official',1,date '2026-07-12','published','Ratneswar_WAREE_TOPCORN_610-615WP.pdf',now());
insert into price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy) values
 (l580,'WAAREE','TOPCon',580,4,2.320,124129,65760,58369),(l580,'WAAREE','TOPCon',580,5,2.900,149076,76200,72876),(l580,'WAAREE','TOPCon',580,6,3.480,174023,78000,96023),(l580,'WAAREE','TOPCon',580,7,4.060,203010,78000,125010),(l580,'WAAREE','TOPCon',580,8,4.640,226442,78000,148442),(l580,'WAAREE','TOPCon',580,9,5.220,255934,78000,177934),(l580,'WAAREE','TOPCon',580,10,5.800,277851,78000,199851),(l580,'WAAREE','TOPCon',580,12,6.960,352187,78000,274187),(l580,'WAAREE','TOPCon',580,14,8.120,398950,78000,320950),(l580,'WAAREE','TOPCon',580,17,9.860,472276,78000,394276),(l580,'WAAREE','TOPCon',580,18,10.440,494294,78000,416294),
 (l610,'WAAREE','TOPCon',610,4,2.440,129381,67920,61461),(l610,'WAAREE','TOPCon',615,4,2.460,129381,68280,61101),
 (l610,'WAAREE','TOPCon',610,5,3.050,155742,78000,77742),(l610,'WAAREE','TOPCon',615,5,3.075,155742,78000,77742),(l610,'WAAREE','TOPCon',610,6,3.660,178972,78000,100972),(l610,'WAAREE','TOPCon',615,6,3.690,178972,78000,100972),(l610,'WAAREE','TOPCon',610,7,4.270,212302,78000,134302),(l610,'WAAREE','TOPCon',615,7,4.305,212302,78000,134302),(l610,'WAAREE','TOPCon',610,8,4.880,242198,78000,164198),(l610,'WAAREE','TOPCon',615,8,4.920,242198,78000,164198),(l610,'WAAREE','TOPCon',610,9,5.490,267751,78000,189751),(l610,'WAAREE','TOPCon',615,9,5.535,267751,78000,189751),(l610,'WAAREE','TOPCon',610,10,6.100,315019,78000,237019),(l610,'WAAREE','TOPCon',615,10,6.150,315019,78000,237019),(l610,'WAAREE','TOPCon',610,12,7.320,368044,78000,290044),(l610,'WAAREE','TOPCon',615,12,7.380,368044,78000,290044),(l610,'WAAREE','TOPCon',610,14,8.540,417534,78000,339534),(l610,'WAAREE','TOPCon',615,14,8.610,417534,78000,339534),(l610,'WAAREE','TOPCon',610,16,9.760,471468,78000,393468),(l610,'WAAREE','TOPCon',615,16,9.840,471468,78000,393468),(l610,'WAAREE','TOPCon',610,17,10.370,494698,78000,416698),(l610,'WAAREE','TOPCon',615,17,10.455,494698,78000,416698);
end$$;
insert into company_settings(key,value) values
 ('company.profile','{"name":"Ratneswar Engineering","gstin":"24ABKFR8021K1ZZ","address":"Office No. 19, Sanghvi Square Complex, Salarinaka, Rapar-Kutch, Gujarat 370165","timezone":"Asia/Kolkata"}'::jsonb),
 ('company.bank','{"accountName":"Ratneswar Engineering","bankName":"HDFC Bank","accountNumber":"99900019052018","ifsc":"HDFC0002295","branch":"Rapar Branch, Kutch"}'::jsonb),
 ('security.inactivity_minutes','{"minutes":30}'::jsonb),('security.minimum_password_length','{"length":12}'::jsonb)
on conflict(key) do nothing;
commit;

-- ==================================================
-- 202607160005_simplify_project_invoice_flow.sql
-- ==================================================
begin;

-- New projects are created directly from an approved quotation. The nullable column
-- preserves links for historic agreement-created projects without requiring new agreements.
alter table public.projects alter column agreement_id drop not null;

create or replace function public.approve_quotation_and_create_project(p_quotation_id uuid) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 q quotations%rowtype; v quotation_versions%rowtype; c customers%rowtype;
 pid uuid:=gen_random_uuid(); req record; inv record; reserve_qty numeric; old_status quote_status;
begin
 if public.current_role() <> 'admin' and public.current_role() <> 'district_partner' then raise exception 'Not authorised'; end if;
 select * into q from quotations where id=p_quotation_id and deleted_at is null for update;
 if q.id is null or not can_access_customer(q.customer_id) then raise exception 'Accessible quotation required'; end if;
 if q.current_status <> 'sent' and q.current_status <> 'pending' and q.current_status <> 'approved' then raise exception 'Only a sent, pending or approved quotation can create a project'; end if;
 if exists(select 1 from projects where quotation_id=q.id) then raise exception 'A project already exists for this quotation'; end if;
 select * into v from quotation_versions where quotation_id=q.id and version_no=q.current_version;
 select * into c from customers where id=q.customer_id;
 if v.id is null then raise exception 'Current quotation version is missing'; end if;

 old_status:=q.current_status;
 if old_status<>'approved' then
  update quotations set current_status='approved',approved_at=now(),updated_by=auth.uid(),updated_at=now() where id=q.id;
  insert into quotation_status_history(quotation_id,from_status,to_status,reason,changed_by) values(q.id,old_status,'approved','Quotation approved for project creation',auth.uid());
 end if;

 insert into projects(id,project_no,customer_id,quotation_id,agreement_id,district_id,dealer_id,current_stage,accepted_quotation_snapshot,assigned_partner_id,created_by)
 values(pid,next_document_number('project','PR'),q.customer_id,q.id,null,q.district_id,q.dealer_id,'project_created',v.immutable_snapshot,c.assigned_partner_id,auth.uid());
 update quotations set current_status='project_created',project_created_at=now(),updated_by=auth.uid(),updated_at=now() where id=q.id;
 insert into quotation_status_history(quotation_id,from_status,to_status,reason,changed_by) values(q.id,'approved','project_created','Quotation approved and project created',auth.uid());
 insert into project_stage_history(project_id,to_stage,note,changed_by) values(pid,'project_created','Approved quotation snapshot locked; project created directly',auth.uid());

 insert into project_material_requirements(project_id,item_code,item_name,specification,required_qty,unit)
 values(pid,format('PV-%s-%s',v.panel_brand,v.panel_wattage),format('%s %s Solar Panel',v.panel_brand,v.panel_technology),format('%s Wp',v.panel_wattage),v.panel_quantity,'Nos');
 insert into project_material_requirements(project_id,item_code,item_name,specification,required_qty,unit)
 select pid,upper(left(regexp_replace(qi.description,'[^A-Za-z0-9]+','-','g'),30)),qi.description,concat_ws(' - ',qi.brand,qi.specification),qi.quantity,qi.unit
 from quotation_items qi where qi.quotation_version_id=v.id and qi.selected and not qi.internal_only and lower(qi.description) not like '%pv module%';
 for req in select * from project_material_requirements where project_id=pid loop
  select i.*,b.available into inv from inventory_items i join inventory_balance b on b.id=i.id where i.item_code=req.item_code and (i.district_id is null or i.district_id=q.district_id) limit 1;
  if inv.id is not null then
   reserve_qty:=least(req.required_qty,greatest(inv.available,0));
   update project_material_requirements set inventory_item_id=inv.id,reserved_qty=reserve_qty where id=req.id;
   if reserve_qty>0 then insert into stock_transactions(inventory_item_id,transaction_type,quantity,project_id,reference_no,reason,idempotency_key,created_by) values(inv.id,'reservation',reserve_qty,pid,q.quotation_no,'Automatic project reservation',format('project:%s:reserve:%s',pid,req.id),auth.uid()); end if;
  end if;
 end loop;
 if q.dealer_id is not null and v.dealer_commission>0 then
  insert into dealer_commissions(dealer_id,customer_id,project_id,quotation_id,commission_type,commission_value,total_commission,created_by) values(q.dealer_id,q.customer_id,pid,q.id,'fixed',v.dealer_commission,v.dealer_commission,auth.uid());
 end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'quotation_approved_project_created','project',pid,jsonb_build_object('quotationId',q.id));
 return pid;
end $$;
grant execute on function public.approve_quotation_and_create_project(uuid) to authenticated;

create or replace function public.save_installation_and_issue_invoice(p_project_id uuid,p_details jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare p projects%rowtype; q jsonb; expected int; serial_count int; duplicate_count int; tr tax_rules%rowtype; gross numeric; taxable numeric; tax numeric; inv_id uuid:=gen_random_uuid(); inv_no text; serial text; panel_item uuid;
begin select * into p from projects where id=p_project_id for update; if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if; if not (p.current_stage = any(array['installation_done','inspection_pending','inspection_done','meter_pending','meter_done','commissioning_done','subsidy_pending','subsidy_passed','handover_completed','project_closed']::project_stage[])) then raise exception 'Invoice is available only after Project Installation Done'; end if; if exists(select 1 from customer_invoices where project_id=p.id and status in('issued','paid')) then raise exception 'An active invoice already exists'; end if; q:=p.accepted_quotation_snapshot;expected:=(q->>'panelQuantity')::int;serial_count:=jsonb_array_length(coalesce(p_details->'panelSerials','[]'));if serial_count<1 then raise exception 'Panel serial numbers are required'; end if;select count(*)-count(distinct value) into duplicate_count from jsonb_array_elements_text(p_details->'panelSerials');if duplicate_count>0 then raise exception 'Duplicate panel serial numbers are not allowed'; end if;if (serial_count<>expected or p_details->>'panelBrand'<>q->>'panelBrand' or (p_details->>'panelWattage')::int<>(q->>'panelWattage')::int) and nullif(trim(p_details->>'overrideReason'),'') is null then raise exception 'Material change reason is required'; end if;
 select inventory_item_id into panel_item from project_material_requirements where project_id=p.id and item_code like 'PV-%' limit 1; if panel_item is null then insert into inventory_items(item_code,item_name,category,brand,model,specification,unit,district_id,serialized,reorder_level,created_by) values(format('PV-%s-%s',p_details->>'panelBrand',p_details->>'panelWattage'),format('%s %s Solar Panel',p_details->>'panelBrand',p_details->>'panelTechnology'),'PV Module',p_details->>'panelBrand',p_details->>'panelTechnology',format('%s Wp',p_details->>'panelWattage'),'Nos',p.district_id,true,0,auth.uid()) on conflict(item_code) do update set item_name=excluded.item_name returning id into panel_item; update project_material_requirements set inventory_item_id=panel_item where project_id=p.id and item_code like 'PV-%'; end if;
 for serial in select jsonb_array_elements_text(p_details->'panelSerials') loop if exists(select 1 from inventory_serials where serial_number=serial) then raise exception 'Installed serial number % already exists',serial; end if; insert into inventory_serials(inventory_item_id,serial_number,status,project_id) values(panel_item,serial,'installed',p.id); end loop;
 insert into installation_materials(project_id,details,created_by) values(p.id,p_details,auth.uid()); select * into tr from tax_rules where active and effective_from<=current_date and (effective_to is null or effective_to>=current_date) order by effective_from desc limit 1; if tr.id is null then raise exception 'No active effective-dated tax rule exists'; end if;gross:=(q->>'grandTotal')::numeric;taxable:=round(gross*100/(100+tr.gst_rate),2);tax:=gross-taxable;inv_no:=next_document_number('invoice','INV');
 insert into customer_invoices(id,invoice_no,customer_id,project_id,invoice_date,place_of_supply,status,tax_rule_id,taxable_value,cgst,sgst,igst,grand_total,snapshot,issued_by) values(inv_id,inv_no,p.customer_id,p.id,current_date,'Gujarat (24)','issued',tr.id,taxable,case when tr.intrastate then round(tax/2,2) else 0 end,case when tr.intrastate then tax-round(tax/2,2) else 0 end,case when tr.intrastate then 0 else tax end,gross,jsonb_build_object('id',inv_id,'invoiceNo',inv_no,'customerId',p.customer_id,'projectId',p.id,'invoiceDate',current_date,'placeOfSupply','Gujarat (24)','status','issued','taxMode','inclusive','taxableValue',taxable,'cgst',case when tr.intrastate then round(tax/2,2) else 0 end,'sgst',case when tr.intrastate then tax-round(tax/2,2) else 0 end,'igst',case when tr.intrastate then 0 else tax end,'roundOff',0,'grandTotal',gross),auth.uid());
 insert into customer_invoice_items(invoice_id,description,hsn_sac,quantity,unit,taxable_value,tax_rate,serial_numbers) values(inv_id,format('Supply and Installation of %s kW Rooftop Solar Power Plant',q->>'dcCapacityKw'),'8541 / 9954',1,'Job',taxable,tr.gst_rate,array(select jsonb_array_elements_text(p_details->'panelSerials'))); insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'customer_invoice_issued','customer_invoice',inv_id,p_details->>'overrideReason',jsonb_build_object('projectId',p.id,'gross',gross,'serialCount',serial_count)); return inv_id; end $$;
grant execute on function public.save_installation_and_issue_invoice(uuid,jsonb) to authenticated;

commit;

-- ==================================================
-- 202607170006_residential_price_list_source_ranges.sql
-- ==================================================
begin;

-- Preserve the source document's wattage ranges without changing historic quotation keys.
alter table public.price_list_items add column if not exists panel_wattage_min integer;
alter table public.price_list_items add column if not exists panel_wattage_max integer;
alter table public.price_list_items add column if not exists panel_wattage_label text;

create or replace view public.active_price_rows with (security_invoker=true) as
select distinct on(i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity)
 i.id,i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity,i.dc_capacity_kw,i.gross_price,i.expected_subsidy,i.after_subsidy,i.active,
 l.effective_from,l.version_no,l.source_document,
 coalesce(i.panel_wattage_min,i.panel_wattage) panel_wattage_min,
 coalesce(i.panel_wattage_max,i.panel_wattage) panel_wattage_max,
 coalesce(i.panel_wattage_label,format('%s Wp',i.panel_wattage)) panel_wattage_label
from public.price_list_items i
join public.price_lists l on l.id=i.price_list_id
where i.active and l.status='published' and l.effective_from<=current_date
order by i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity,l.effective_from desc,l.version_no desc;

create or replace function public.publish_price_row(p_row jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare list_id uuid:=gen_random_uuid(); item_id uuid:=gen_random_uuid(); ver int;
begin
 if not is_admin() then raise exception 'Admin access required'; end if;
 select coalesce(max(version_no),0)+1 into ver from price_lists where name='Manual Price Configuration';
 insert into price_lists(id,name,version_no,effective_from,status,source_document,created_by,published_by,published_at)
 values(list_id,'Manual Price Configuration',ver,(p_row->>'effectiveFrom')::date,'published',p_row->>'sourceDocument',auth.uid(),auth.uid(),now());
 insert into price_list_items(id,price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active)
 values(item_id,list_id,upper(p_row->>'panelBrand'),p_row->>'panelTechnology',(p_row->>'panelWattage')::int,
  coalesce(nullif(p_row->>'panelWattageMin','')::int,(p_row->>'panelWattage')::int),
  coalesce(nullif(p_row->>'panelWattageMax','')::int,(p_row->>'panelWattage')::int),
  coalesce(nullif(p_row->>'panelWattageLabel',''),format('%s Wp',p_row->>'panelWattage')),
  (p_row->>'panelQuantity')::int,(p_row->>'capacityKw')::numeric,(p_row->>'price')::numeric,
  nullif(p_row->>'expectedSubsidy','')::numeric,nullif(p_row->>'afterSubsidy','')::numeric,true);
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'price_published','price_list_item',item_id,p_row);
 return item_id;
end $$;
grant execute on function public.publish_price_row(jsonb) to authenticated;

do $$
declare
 list_id uuid;
 row_count integer;
begin
 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Residential Solar Rooftop Master Price List',1,date '2026-07-17','published','Price List_Residential_Solar_Rooftop(2).pdf · Source dated 06.06.2026',now())
 on conflict(name,version_no) do update set effective_from=excluded.effective_from,status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_id;

 update public.price_lists set status='inactive' where status='published' and id<>list_id;
 update public.price_list_items set active=false where price_list_id=list_id;

 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,active) values
 -- BIFACIAL 530-550 WP: exact capacities and prices from page 1.
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',4,2.180,124540,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',5,2.725,146175,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',6,3.270,171310,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',7,3.815,184945,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',8,4.360,208840,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',9,4.905,249715,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',10,5.450,267910,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',11,5.995,298985,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',12,6.540,324620,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',13,7.085,346255,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',14,7.630,367890,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',15,8.175,385125,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',16,8.720,406160,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',17,9.265,429295,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',18,9.810,453430,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',4,2.180,122740,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',5,2.725,145050,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',6,3.270,167460,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',7,3.815,180570,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',8,4.360,202880,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',9,4.905,243240,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',10,5.450,260700,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',11,5.995,291110,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',12,6.540,315720,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',13,7.085,336630,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',14,7.630,357740,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',15,8.175,373550,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',16,8.720,393860,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',17,9.265,416070,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',18,9.810,440180,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',4,2.180,116140,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',5,2.725,136800,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',6,3.270,157560,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',7,3.815,169020,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',8,4.360,189680,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',9,4.905,228390,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',10,5.450,244200,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',11,5.995,272960,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',12,6.540,295920,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',13,7.085,315180,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',14,7.630,334640,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',15,8.175,348800,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',16,8.720,367460,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',17,9.265,388020,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',18,9.810,410480,true),
 -- TOPCON PAHAL 600 W.
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',4,2.400,124300,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',5,3.000,151500,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',6,3.600,172700,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',7,4.200,192400,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',8,4.800,210600,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',9,5.400,236800,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',10,6.000,262600,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',11,6.600,306700,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',12,7.200,334400,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',13,7.800,352100,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',14,8.400,379300,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',15,9.000,396500,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',16,9.600,419200,true),
 -- TOPCON ADANI 605-620 W; capacities follow the source's 620 W column.
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',4,2.480,138040,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',5,3.100,161700,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',6,3.720,183860,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',7,4.340,221020,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',8,4.960,258880,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',9,5.580,276740,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',10,6.200,308600,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',11,6.820,343960,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',12,7.440,300820,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',13,8.060,420480,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',14,8.680,445640,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',15,9.300,473900,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',16,9.920,511060,true),
 -- TOPCON WAAREE 570-580 W.
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',4,2.320,125640,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',5,2.900,148400,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',6,3.480,172360,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',7,4.060,198120,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',8,4.640,219280,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',9,5.220,249940,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',10,5.800,265100,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',11,6.380,317760,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',12,6.960,339920,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',13,7.540,361780,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',14,8.120,383480,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',15,8.700,405900,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',16,9.280,420560,true),
 -- TOPCON APS: source heading is 580 W; exact source-listed capacities are retained.
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',4,2.400,118440,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',5,3.000,139400,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',6,3.600,161560,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',7,4.200,185520,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',8,4.800,204880,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',9,5.400,233740,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',10,6.000,247100,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',11,6.600,297960,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',12,7.200,318320,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',13,7.800,338380,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',14,8.400,358280,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',15,9.000,378900,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',16,9.600,391760,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity)
 do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=null,after_subsidy=null,active=true;

 select count(*) into row_count from public.price_list_items where price_list_id=list_id and active;
 if row_count<>97 then raise exception 'Residential master price list must contain 97 active configurations; found %',row_count; end if;
end $$;

commit;

-- ==================================================
-- 202607170007_operational_controls_and_settings.sql
-- ==================================================
begin;

insert into public.company_settings(key,value)
values('crm.settings',jsonb_build_object(
  'company',jsonb_build_object('legalName','RATNESWAR ENGINEERING','tradeName','Ratneswar Engineering','address','Office No. 19, Sanghvi Square Complex, Salarinaka, Rapar-Kutch, Rapar, Gujarat - 370165','mobilePrimary','84010 50053','mobileSecondary','78019 56980','email','ratneswarengineering@gmail.com','gstin','24ABKFR8021K1ZZ','pan','ABKFR8021K','state','Gujarat','stateCode','24','jurisdiction','Kutch'),
  'bank',jsonb_build_object('accountHolder','RATNESWAR ENGINEERING','bankName','HDFC Bank','accountNumber','99900019052018','ifsc','HDFC0002295','branch','Rapar Branch, Kutch'),
  'quotationNumbering',jsonb_build_object('prefix','RE-RSS-PGVCL-2026','nextNumber',1,'padding',4),
  'invoiceNumbering',jsonb_build_object('prefix','RE-INV-2026','nextNumber',1,'padding',4),
  'quotationValidityDays',15,'paymentTerms','10% advance at work order; 90% before material dispatch.','warrantyTerms','Five-year comprehensive system warranty; component warranties as provided by manufacturers.','quotationNotes','Subsidy is informational, subject to eligibility, and credited directly to the customer.','defaultHsnSac','8541 / 9954','footerText','This is a computer-generated document. Subject to Kutch jurisdiction.','inactivityMinutes',30
)) on conflict(key) do nothing;

drop policy if exists settings_authenticated_read on public.company_settings;
create policy settings_authenticated_read on public.company_settings for select to authenticated using(true);

create or replace function public.next_document_number(p_type text,p_prefix text) returns text
language plpgsql security definer set search_path=public as $$
declare
 fy text:=to_char(current_date,'YYYY'); n bigint; cfg jsonb; prefix_ text; padding_ int;
begin
 select value into cfg from company_settings where key='crm.settings';
 if p_type='quotation' then
  prefix_:=coalesce(nullif(cfg#>>'{quotationNumbering,prefix}',''),p_prefix);
  padding_:=greatest(1,least(10,coalesce((cfg#>>'{quotationNumbering,padding}')::int,4)));
 elsif p_type='invoice' then
  prefix_:=coalesce(nullif(cfg#>>'{invoiceNumbering,prefix}',''),p_prefix);
  padding_:=greatest(1,least(10,coalesce((cfg#>>'{invoiceNumbering,padding}')::int,4)));
 else
  prefix_:=format('RE/%s/%s/',p_prefix,fy); padding_:=4;
 end if;
 insert into document_counters(document_type,financial_year,last_number) values(p_type,fy,1)
 on conflict(document_type) do update set last_number=case when excluded.document_type not in('quotation','invoice') and document_counters.financial_year<>excluded.financial_year then 1 else document_counters.last_number+1 end,financial_year=excluded.financial_year,updated_at=now()
 returning last_number into n;
 if p_type='quotation' then update company_settings set value=jsonb_set(value,'{quotationNumbering,nextNumber}',to_jsonb(n+1),true),updated_at=now() where key='crm.settings'; end if;
 if p_type='invoice' then update company_settings set value=jsonb_set(value,'{invoiceNumbering,nextNumber}',to_jsonb(n+1),true),updated_at=now() where key='crm.settings'; end if;
 return prefix_||lpad(n::text,padding_,'0');
end $$;
revoke all on function public.next_document_number(text,text) from public,anon,authenticated;

create or replace function public.save_crm_settings(p_settings jsonb) returns void
language plpgsql security definer set search_path=public as $$
declare q_next bigint; i_next bigint;
begin
 if not is_admin() then raise exception 'Admin access required'; end if;
 if nullif(trim(p_settings#>>'{company,legalName}'),'') is null then raise exception 'Company legal name is required'; end if;
 if nullif(trim(p_settings#>>'{quotationNumbering,prefix}'),'') is null or nullif(trim(p_settings#>>'{invoiceNumbering,prefix}'),'') is null then raise exception 'Document prefixes are required'; end if;
 q_next:=greatest(1,coalesce((p_settings#>>'{quotationNumbering,nextNumber}')::bigint,1));
 i_next:=greatest(1,coalesce((p_settings#>>'{invoiceNumbering,nextNumber}')::bigint,1));
 if coalesce((p_settings#>>'{quotationNumbering,padding}')::int,0) not between 1 and 10 or coalesce((p_settings#>>'{invoiceNumbering,padding}')::int,0) not between 1 and 10 then raise exception 'Number padding must be between 1 and 10'; end if;
 insert into company_settings(key,value,updated_by,updated_at) values('crm.settings',p_settings,auth.uid(),now()) on conflict(key) do update set value=excluded.value,updated_by=excluded.updated_by,updated_at=now();
 insert into document_counters(document_type,financial_year,last_number) values('quotation',to_char(current_date,'YYYY'),q_next-1) on conflict(document_type) do update set financial_year=excluded.financial_year,last_number=excluded.last_number,updated_at=now();
 insert into document_counters(document_type,financial_year,last_number) values('invoice',to_char(current_date,'YYYY'),i_next-1) on conflict(document_type) do update set financial_year=excluded.financial_year,last_number=excluded.last_number,updated_at=now();
 insert into audit_logs(actor_id,action,entity_type,reason,metadata) values(auth.uid(),'crm_settings_updated','company_settings','Main settings and document counters changed',jsonb_build_object('quotationNext',q_next,'invoiceNext',i_next));
end $$;
grant execute on function public.save_crm_settings(jsonb) to authenticated;

create or replace function public.save_quotation_version(p_quote jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 qid uuid; input_id uuid:=nullif(p_quote->>'id','')::uuid; requested_no text:=nullif(trim(p_quote->>'quoteNo'),''); qno text; ver int; old_status quote_status;
 cid uuid:=(p_quote->>'customerId')::uuid; c customers%rowtype; price active_price_rows%rowtype; final numeric:=(p_quote->>'grandTotal')::numeric; suggested numeric;
 v_id uuid:=gen_random_uuid(); item jsonb; actor uuid:=auth.uid(); dealer uuid; commission numeric:=0; existing quotations%rowtype;
begin
 if not can_access_customer(cid) then raise exception 'Customer is not accessible'; end if; select * into c from customers where id=cid;
 if public.current_role()='dealer' then dealer:=current_dealer(); else dealer:=nullif(p_quote->>'dealerId','')::uuid; end if;
 select * into price from active_price_rows where panel_brand=upper(p_quote->>'panelBrand') and panel_technology=p_quote->>'panelTechnology' and panel_wattage=(p_quote->>'panelWattage')::int and panel_quantity=(p_quote->>'panelQuantity')::int;
 if price.id is null then raise exception 'No exact active price configuration exists'; end if; suggested:=price.gross_price;
 if final<>suggested and nullif(trim(p_quote->>'priceOverrideReason'),'') is null then raise exception 'Price override reason is required'; end if;
 if (p_quote->>'taxMode')<>'inclusive' then raise exception 'Published price is GST-inclusive and cannot be changed to GST-extra'; end if;
 if public.current_role()<>'dealer' then commission:=coalesce(nullif(p_quote->>'dealerCommission','')::numeric,0); end if;

 if input_id is not null then select * into existing from quotations where id=input_id and deleted_at is null; end if;
 if existing.id is null and requested_no is not null then select * into existing from quotations where quotation_no=requested_no and deleted_at is null; end if;
 if existing.id is not null then
  if requested_no is not null and existing.quotation_no=requested_no and input_id<>existing.id and coalesce((p_quote->>'versionNo')::int,1)<=1 then raise exception 'Quotation number already exists'; end if;
  if existing.customer_id<>cid then raise exception 'Quotation customer cannot be changed'; end if;
  qid:=existing.id; qno:=existing.quotation_no; ver:=existing.current_version+1; old_status:=existing.current_status;
  update quotations set current_version=ver,current_status='draft',dealer_id=dealer,updated_by=actor,updated_at=now(),sent_at=null,approved_at=null,rejected_at=null where id=qid;
  insert into quotation_status_history(quotation_id,from_status,to_status,reason,changed_by) values(qid,old_status,'draft','Commercial revision created',actor);
 else
  qid:=coalesce(input_id,gen_random_uuid()); qno:=coalesce(requested_no,next_document_number('quotation','QT')); ver:=1;
  if exists(select 1 from quotations where quotation_no=qno) then raise exception 'Quotation number already exists'; end if;
  insert into quotations(id,quotation_no,customer_id,district_id,dealer_id,current_version,current_status,created_by,updated_by) values(qid,qno,cid,c.district_id,dealer,ver,'draft',actor,actor);
  insert into quotation_status_history(quotation_id,to_status,changed_by) values(qid,'draft',actor);
 end if;
 insert into quotation_versions(id,quotation_id,version_no,price_list_item_id,system_type,dcr_type,scheme,panel_brand,panel_technology,panel_wattage,panel_quantity,dc_capacity_kw,suggested_price,final_price,price_override_reason,gst_included,dealer_commission,internal_cost,immutable_snapshot,created_by)
 values(v_id,qid,ver,price.id,p_quote->>'systemType',p_quote->>'dcrType',p_quote->>'scheme',upper(p_quote->>'panelBrand'),p_quote->>'panelTechnology',(p_quote->>'panelWattage')::int,(p_quote->>'panelQuantity')::int,price.dc_capacity_kw,suggested,final,nullif(p_quote->>'priceOverrideReason',''),true,commission,case when public.current_role()='dealer' then 0 else coalesce(nullif(p_quote->>'internalCost','')::numeric,0) end,p_quote||jsonb_build_object('id',qid,'quoteNo',qno,'versionNo',ver,'status','draft','suggestedPrice',suggested,'basePrice',final,'grandTotal',final,'dcCapacityKw',price.dc_capacity_kw,'dealerId',dealer,'dealerCommission',commission,'taxMode','inclusive'),actor);
 for item in select * from jsonb_array_elements(coalesce(p_quote->'items','[]')) loop
  insert into quotation_items(quotation_version_id,description,brand,specification,quantity,unit,rate,selected,internal_only) values(v_id,item->>'description',nullif(item->>'brand',''),nullif(item->>'specification',''),coalesce((item->>'quantity')::numeric,1),coalesce(item->>'unit','Nos'),coalesce(nullif(item->>'rate','')::numeric,0),coalesce((item->>'selected')::boolean,true),coalesce((item->>'internalOnly')::boolean,false));
 end loop;
 if final<>suggested then insert into quotation_overrides(quotation_id,version_no,suggested_price,final_price,reason,created_by) values(qid,ver,suggested,final,p_quote->>'priceOverrideReason',actor); end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(actor,'quotation_version_saved','quotation',qid,nullif(p_quote->>'priceOverrideReason',''),jsonb_build_object('version',ver,'quotationNo',qno,'suggested',suggested,'final',final));
 return qid;
end $$;
grant execute on function public.save_quotation_version(jsonb) to authenticated;

create or replace function public.update_inventory_item(p_item jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare iid uuid:=(p_item->>'id')::uuid; did uuid:=nullif(p_item->>'districtId','')::uuid;
begin
 if not is_admin() then raise exception 'Admin access required'; end if;
 if not exists(select 1 from inventory_items where id=iid and deleted_at is null) then raise exception 'Inventory item not found'; end if;
 update inventory_items set item_code=upper(trim(p_item->>'itemCode')),item_name=trim(p_item->>'itemName'),category=trim(p_item->>'category'),brand=nullif(trim(p_item->>'brand'),''),model=nullif(trim(p_item->>'model'),''),specification=nullif(trim(p_item->>'specification'),''),unit=trim(p_item->>'unit'),district_id=did,reorder_level=greatest(0,coalesce(nullif(p_item->>'reorderLevel','')::numeric,0)) where id=iid;
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'inventory_item_updated','inventory_item',iid,p_item);
 return iid;
exception when unique_violation then raise exception 'Inventory item code already exists';
end $$;
grant execute on function public.update_inventory_item(jsonb) to authenticated;

create or replace function public.archive_inventory_item(p_item_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare bal inventory_balance%rowtype;
begin
 if not is_admin() then raise exception 'Admin access required'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Archive reason is required'; end if;
 select * into bal from inventory_balance where id=p_item_id;
 if bal.id is null then raise exception 'Inventory item not found'; end if;
 if bal.on_hand<>0 or bal.reserved<>0 then raise exception 'Item can be archived only when on-hand and reserved stock are zero'; end if;
 update inventory_items set deleted_at=now(),updated_at=now() where id=p_item_id;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'inventory_item_archived','inventory_item',p_item_id,p_reason,jsonb_build_object('onHand',bal.on_hand,'reserved',bal.reserved));
end $$;
grant execute on function public.archive_inventory_item(uuid,text) to authenticated;

create or replace function public.save_project_material_requirements(p_project_id uuid,p_materials jsonb,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare p projects%rowtype; row_ jsonb; rid uuid; existing project_material_requirements%rowtype; keep_ids uuid[]:='{}'; qty numeric;
begin
 select * into p from projects where id=p_project_id for update;
 if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Material change reason is required'; end if;
 for row_ in select * from jsonb_array_elements(coalesce(p_materials,'[]')) loop
  rid:=coalesce(nullif(row_->>'id','')::uuid,gen_random_uuid()); qty:=coalesce(nullif(row_->>'requiredQty','')::numeric,0);
  if qty<=0 or nullif(trim(row_->>'itemName'),'') is null or nullif(trim(row_->>'unit'),'') is null then raise exception 'Every material needs a name, positive quantity and unit'; end if;
  select * into existing from project_material_requirements where id=rid;
  if existing.id is not null then
   if existing.project_id<>p.id then raise exception 'Invalid material row'; end if;
   if qty<greatest(existing.reserved_qty,existing.issued_qty) then raise exception 'Required quantity cannot be below reserved or issued quantity for %',existing.item_name; end if;
   update project_material_requirements set item_code=upper(trim(row_->>'itemCode')),item_name=trim(row_->>'itemName'),specification=nullif(trim(row_->>'specification'),''),required_qty=qty,unit=trim(row_->>'unit') where id=rid;
  else
   insert into project_material_requirements(id,project_id,item_code,item_name,specification,required_qty,unit) values(rid,p.id,coalesce(nullif(upper(trim(row_->>'itemCode')),''),'MANUAL'),trim(row_->>'itemName'),nullif(trim(row_->>'specification'),''),qty,trim(row_->>'unit'));
  end if;
  keep_ids:=array_append(keep_ids,rid); existing:=null;
 end loop;
 if exists(select 1 from project_material_requirements where project_id=p.id and not(id=any(keep_ids)) and (reserved_qty>0 or issued_qty>0)) then raise exception 'Reserved or issued material rows cannot be removed'; end if;
 delete from project_material_requirements where project_id=p.id and not(id=any(keep_ids));
 update projects set updated_at=now(),row_version=row_version+1 where id=p.id;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'project_materials_updated','project',p.id,p_reason,jsonb_build_object('rows',jsonb_array_length(p_materials)));
end $$;
grant execute on function public.save_project_material_requirements(uuid,jsonb,text) to authenticated;

create or replace function public.save_installation_and_issue_invoice(p_project_id uuid,p_details jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 p projects%rowtype; q jsonb; expected int; serial_count int; duplicate_count int; tr tax_rules%rowtype; gross numeric; taxable numeric; tax numeric;
 inv_id uuid:=gen_random_uuid(); inv_no text; inv_date date:=coalesce(nullif(p_details->>'invoiceDate','')::date,current_date); place_ text:=coalesce(nullif(trim(p_details->>'placeOfSupply'),''),'Gujarat (24)'); serial text; panel_item uuid; hsn text;
begin
 select * into p from projects where id=p_project_id for update;
 if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if;
 if not (p.current_stage = any(array['installation_done','inspection_pending','inspection_done','meter_pending','meter_done','commissioning_done','subsidy_pending','subsidy_passed','handover_completed','project_closed']::project_stage[])) then raise exception 'Invoice is available only after Project Installation Done'; end if;
 if exists(select 1 from customer_invoices where project_id=p.id and status in('issued','paid')) then raise exception 'An active invoice already exists'; end if;
 q:=p.accepted_quotation_snapshot; expected:=(q->>'panelQuantity')::int; serial_count:=jsonb_array_length(coalesce(p_details->'panelSerials','[]'));
 if serial_count<1 then raise exception 'Panel serial numbers are required'; end if;
 select count(*)-count(distinct value) into duplicate_count from jsonb_array_elements_text(p_details->'panelSerials'); if duplicate_count>0 then raise exception 'Duplicate panel serial numbers are not allowed'; end if;
 if (serial_count<>expected or p_details->>'panelBrand'<>q->>'panelBrand' or (p_details->>'panelWattage')::int<>(q->>'panelWattage')::int) and nullif(trim(p_details->>'overrideReason'),'') is null then raise exception 'Material change reason is required'; end if;
 select inventory_item_id into panel_item from project_material_requirements where project_id=p.id and item_code like 'PV-%' limit 1;
 if panel_item is null then
  insert into inventory_items(item_code,item_name,category,brand,model,specification,unit,district_id,serialized,reorder_level,created_by) values(format('PV-%s-%s',p_details->>'panelBrand',p_details->>'panelWattage'),format('%s %s Solar Panel',p_details->>'panelBrand',p_details->>'panelTechnology'),'PV Module',p_details->>'panelBrand',p_details->>'panelTechnology',format('%s Wp',p_details->>'panelWattage'),'Nos',p.district_id,true,0,auth.uid()) on conflict(item_code) do update set item_name=excluded.item_name returning id into panel_item;
  update project_material_requirements set inventory_item_id=panel_item where project_id=p.id and item_code like 'PV-%';
 end if;
 for serial in select jsonb_array_elements_text(p_details->'panelSerials') loop
  if nullif(trim(serial),'') is null then raise exception 'Panel serial numbers cannot be blank'; end if;
  if exists(select 1 from inventory_serials where serial_number=serial) then raise exception 'Installed serial number % already exists',serial; end if;
  insert into inventory_serials(inventory_item_id,serial_number,status,project_id) values(panel_item,serial,'installed',p.id);
 end loop;
 insert into installation_materials(project_id,details,created_by) values(p.id,p_details,auth.uid());
 select * into tr from tax_rules where active and effective_from<=inv_date and (effective_to is null or effective_to>=inv_date) order by effective_from desc limit 1; if tr.id is null then raise exception 'No active effective-dated tax rule exists'; end if;
 gross:=(q->>'grandTotal')::numeric; taxable:=round(gross*100/(100+tr.gst_rate),2); tax:=gross-taxable;
 inv_no:=coalesce(nullif(trim(p_details->>'invoiceNo'),''),next_document_number('invoice','INV'));
 if exists(select 1 from customer_invoices where invoice_no=inv_no) then raise exception 'Invoice number already exists'; end if;
 select coalesce(value->>'defaultHsnSac','8541 / 9954') into hsn from company_settings where key='crm.settings';
 insert into customer_invoices(id,invoice_no,customer_id,project_id,invoice_date,place_of_supply,status,tax_rule_id,taxable_value,cgst,sgst,igst,grand_total,snapshot,issued_by)
 values(inv_id,inv_no,p.customer_id,p.id,inv_date,place_,'issued',tr.id,taxable,case when tr.intrastate then round(tax/2,2) else 0 end,case when tr.intrastate then tax-round(tax/2,2) else 0 end,case when tr.intrastate then 0 else tax end,gross,jsonb_build_object('id',inv_id,'invoiceNo',inv_no,'customerId',p.customer_id,'projectId',p.id,'invoiceDate',inv_date,'placeOfSupply',place_,'status','issued','taxMode','inclusive','taxableValue',taxable,'cgst',case when tr.intrastate then round(tax/2,2) else 0 end,'sgst',case when tr.intrastate then tax-round(tax/2,2) else 0 end,'igst',case when tr.intrastate then 0 else tax end,'roundOff',0,'grandTotal',gross),auth.uid());
 insert into customer_invoice_items(invoice_id,description,hsn_sac,quantity,unit,taxable_value,tax_rate,serial_numbers) values(inv_id,format('Supply and Installation of %s kW Rooftop Solar Power Plant',q->>'dcCapacityKw'),hsn,1,'Job',taxable,tr.gst_rate,array(select jsonb_array_elements_text(p_details->'panelSerials')));
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'customer_invoice_issued','customer_invoice',inv_id,p_details->>'overrideReason',jsonb_build_object('projectId',p.id,'invoiceNo',inv_no,'gross',gross,'serialCount',serial_count));
 return inv_id;
end $$;
grant execute on function public.save_installation_and_issue_invoice(uuid,jsonb) to authenticated;

commit;

-- ==================================================
-- 202607180008_area_partner_security_and_login_bootstrap.sql
-- ==================================================
-- Area Partner security hardening and known-login bootstrap.
-- The database enum remains district_partner for backward compatibility; the UI calls it Area Partner.
begin;

create or replace function public.can_access_customer(p_customer uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(
  select 1 from customers c
  where c.id=p_customer and c.archived_at is null
    and (
      is_admin()
      or (public.current_role()='district_partner' and c.assigned_partner_id=auth.uid())
      or (public.current_role()='dealer' and c.dealer_id=current_dealer())
    )
 )
$$;

create or replace function public.can_access_project(p_project uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(
  select 1 from projects p
  where p.id=p_project
    and (is_admin() or (public.current_role()='district_partner' and p.assigned_partner_id=auth.uid()))
 )
$$;

grant execute on function public.can_access_customer(uuid),public.can_access_project(uuid) to authenticated;

drop policy if exists dealers_read on public.dealers;
create policy dealers_read on public.dealers for select to authenticated using(
 is_admin()
 or id=current_dealer()
 or (public.current_role()='district_partner' and exists(
   select 1 from customers c where c.dealer_id=dealers.id and c.assigned_partner_id=auth.uid() and c.archived_at is null
 ))
);

drop policy if exists commissions_internal_read on public.dealer_commissions;
create policy commissions_internal_read on public.dealer_commissions for select to authenticated using(
 is_admin() or (public.current_role()='district_partner' and exists(
  select 1 from projects p where p.id=project_id and p.assigned_partner_id=auth.uid()
 ))
);

drop policy if exists commission_payments_internal_read on public.dealer_commission_payments;
create policy commission_payments_internal_read on public.dealer_commission_payments for select to authenticated using(
 is_admin() or (public.current_role()='district_partner' and exists(
  select 1 from dealer_commissions c join projects p on p.id=c.project_id
  where c.id=commission_id and p.assigned_partner_id=auth.uid()
 ))
);

-- Ensure an editable starter territory exists for the supplied test accounts.
insert into public.districts(code,name,active)
values('PRIMARY','Primary Partner Area',true)
on conflict(code) do update set active=true;

-- Promote the supplied Admin account when it already exists in Supabase Auth.
insert into public.profiles(id,full_name,role,district_id,dealer_id,active)
select u.id,coalesce(nullif(u.raw_user_meta_data->>'full_name',''),'Ratneswar Engineering Admin'),'admin',null,null,true
from auth.users u where lower(u.email)=lower('ratneswarengineering@gmail.com')
on conflict(id) do update set full_name=excluded.full_name,role='admin',district_id=null,dealer_id=null,active=true,suspended_at=null,suspended_reason=null;

-- Promote the supplied partner account. Area names can be changed or reassigned by Admin later.
insert into public.profiles(id,full_name,role,district_id,dealer_id,active)
select u.id,coalesce(nullif(u.raw_user_meta_data->>'full_name',''),'Area Partner'),'district_partner',d.id,null,true
from auth.users u cross join public.districts d
where lower(u.email)=lower('bhedav980@gmail.com') and d.code='PRIMARY'
on conflict(id) do update set full_name=excluded.full_name,role='district_partner',district_id=excluded.district_id,dealer_id=null,active=true,suspended_at=null,suspended_reason=null;

-- Connect the supplied Dealer login to one dealer master without inventing business/commission values.
do $$
declare uid uuid; did uuid; dealer_uuid uuid;
begin
 select id into uid from auth.users where lower(email)=lower('bhedavishal79@gmail.com');
 select id into did from public.districts where code='PRIMARY';
 if uid is not null then
  insert into public.profiles(id,full_name,role,district_id,dealer_id,active)
  values(uid,'Dealer User','dealer',did,null,false)
  on conflict(id) do update set role='dealer',district_id=did,dealer_id=null,active=false;
  select id into dealer_uuid from public.dealers where login_user_id=uid limit 1;
  if dealer_uuid is null then
   insert into public.dealers(dealer_no,name,mobile,email,address,district_id,login_user_id,default_commission_type,default_commission_value,active)
   values('DL-'||upper(substr(replace(uid::text,'-',''),1,8)),'Dealer User','PENDING-'||substr(uid::text,1,8),'bhedavishal79@gmail.com','Update from Dealer Master',did,uid,'fixed',0,true)
   returning id into dealer_uuid;
  end if;
  update public.profiles set dealer_id=dealer_uuid,active=true,suspended_at=null,suspended_reason=null where id=uid;
 end if;
end $$;

insert into public.audit_logs(actor_id,action,entity_type,metadata)
select p.id,'area_partner_security_migration','system',jsonb_build_object('scope','assigned customers only')
from public.profiles p where p.role='admin' order by p.created_at limit 1;

commit;

-- ==================================================
-- 202607190009_service_role_profile_privileges.sql
-- ==================================================
begin;
grant usage on schema public to service_role;
grant select, insert, update, delete on table public.profiles to service_role;
grant insert on table public.audit_logs to service_role;
commit;

-- ==================================================
-- 202607190010_admin_deletion_controls.sql
-- ==================================================
begin;

create or replace function public.delete_erroneous_project(p_project_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare p public.projects%rowtype;
begin
 if not public.is_admin() then raise exception 'Only Admin can delete a project'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Deletion reason is required'; end if;
 select * into p from public.projects where id=p_project_id for update;
 if p.id is null then raise exception 'Project not found'; end if;
 if exists(select 1 from public.customer_invoices where project_id=p.id and status<>'cancelled') then raise exception 'Cancel the active invoice before deleting this project'; end if;
 if exists(select 1 from public.stock_transactions where project_id=p.id and transaction_type<>'reservation') then raise exception 'A project with issued or consumed stock cannot be deleted'; end if;
 if exists(select 1 from public.inventory_serials where project_id=p.id) then raise exception 'A project with installed or assigned serial numbers cannot be deleted'; end if;
 if exists(select 1 from public.dealer_commission_payments cp join public.dealer_commissions c on c.id=cp.commission_id where c.project_id=p.id) then raise exception 'A project with dealer commission payments cannot be deleted'; end if;
 if exists(select 1 from public.payments where project_id=p.id and deleted_at is null) or exists(select 1 from public.expenses where project_id=p.id and deleted_at is null) then raise exception 'Remove linked payments and expenses before deleting this project'; end if;
 if exists(select 1 from public.installation_materials where project_id=p.id) then raise exception 'A project with saved installation details cannot be deleted'; end if;

 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,metadata)
 values(auth.uid(),'erroneous_project_deleted','project',p.id,p_reason,jsonb_build_object('projectNo',p.project_no,'quotationId',p.quotation_id));
 delete from public.stock_transactions where project_id=p.id and transaction_type='reservation';
 delete from public.dealer_commissions where project_id=p.id;
 delete from public.project_material_requirements where project_id=p.id;
 delete from public.project_stage_history where project_id=p.id;
 delete from public.project_documents where project_id=p.id;
 update public.agreements set project_id=null where project_id=p.id;
 delete from public.projects where id=p.id;
 update public.quotations set current_status='approved',project_created_at=null,updated_by=auth.uid(),updated_at=now()
 where id=p.quotation_id and deleted_at is null;
end $$;

grant execute on function public.delete_erroneous_project(uuid,text) to authenticated;
grant select,insert,update,delete on public.profiles to service_role;
grant insert on public.audit_logs to service_role;

commit;

-- ==================================================
-- 202607190011_split_gst_invoice_engine.sql
-- ==================================================
begin;

alter table public.tax_rules add column if not exists supply_gst_rate numeric(7,3);
alter table public.tax_rules add column if not exists installation_gst_rate numeric(7,3);
alter table public.tax_rules add column if not exists supply_share_percent numeric(7,3) not null default 70;
alter table public.tax_rules add column if not exists installation_share_percent numeric(7,3) not null default 30;
alter table public.tax_rules add column if not exists supply_hsn text not null default '854140';
alter table public.tax_rules add column if not exists installation_sac text not null default '995442';

update public.tax_rules
set supply_gst_rate=coalesce(supply_gst_rate,gst_rate),
    installation_gst_rate=coalesce(installation_gst_rate,gst_rate)
where supply_gst_rate is null or installation_gst_rate is null;

alter table public.tax_rules alter column supply_gst_rate set not null;
alter table public.tax_rules alter column installation_gst_rate set not null;

do $$
begin
 if not exists(select 1 from pg_constraint where conname='tax_rules_split_share_check') then
  alter table public.tax_rules add constraint tax_rules_split_share_check check(
   supply_share_percent>=0 and installation_share_percent>=0 and
   round(supply_share_percent+installation_share_percent,3)=100
  );
 end if;
 if not exists(select 1 from pg_constraint where conname='tax_rules_split_rate_check') then
  alter table public.tax_rules add constraint tax_rules_split_rate_check check(supply_gst_rate>=0 and installation_gst_rate>=0);
 end if;
end $$;

alter table public.customer_invoice_items add column if not exists line_type text;
alter table public.customer_invoice_items add column if not exists share_percent numeric(7,3) not null default 100;
alter table public.customer_invoice_items add column if not exists gross_value numeric(14,2) not null default 0;
alter table public.customer_invoice_items add column if not exists cgst numeric(14,2) not null default 0;
alter table public.customer_invoice_items add column if not exists sgst numeric(14,2) not null default 0;
alter table public.customer_invoice_items add column if not exists igst numeric(14,2) not null default 0;

drop policy if exists tax_admin_write on public.tax_rules;
drop policy if exists tax_admin_manage on public.tax_rules;
create policy tax_admin_manage on public.tax_rules for all to authenticated using(public.is_admin()) with check(public.is_admin());
grant select,insert,update on public.tax_rules to authenticated;

create or replace function public.save_installation_and_issue_invoice(p_project_id uuid,p_details jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 p projects%rowtype; q jsonb; expected int; serial_count int; duplicate_count int; tr tax_rules%rowtype;
 gross numeric; supply_gross numeric; install_gross numeric; supply_taxable numeric; install_taxable numeric;
 supply_tax numeric; install_tax numeric; supply_cgst numeric:=0; supply_sgst numeric:=0; supply_igst numeric:=0;
 install_cgst numeric:=0; install_sgst numeric:=0; install_igst numeric:=0;
 taxable numeric; cgst_total numeric; sgst_total numeric; igst_total numeric; tax_lines jsonb:='[]'::jsonb;
 inv_id uuid:=gen_random_uuid(); inv_no text; inv_date date:=coalesce(nullif(p_details->>'invoiceDate','')::date,current_date);
 place_ text:=coalesce(nullif(trim(p_details->>'placeOfSupply'),''),'Gujarat (24)'); serial text; panel_item uuid;
begin
 select * into p from projects where id=p_project_id for update;
 if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if;
 if not (p.current_stage = any(array['installation_done','inspection_pending','inspection_done','meter_pending','meter_done','commissioning_done','subsidy_pending','subsidy_passed','handover_completed','project_closed']::project_stage[])) then raise exception 'Invoice is available only after Project Installation Done'; end if;
 if exists(select 1 from customer_invoices where project_id=p.id and status in('issued','paid')) then raise exception 'An active invoice already exists'; end if;
 q:=p.accepted_quotation_snapshot; expected:=(q->>'panelQuantity')::int; serial_count:=jsonb_array_length(coalesce(p_details->'panelSerials','[]'));
 if serial_count<1 then raise exception 'Panel serial numbers are required'; end if;
 select count(*)-count(distinct value) into duplicate_count from jsonb_array_elements_text(p_details->'panelSerials');
 if duplicate_count>0 then raise exception 'Duplicate panel serial numbers are not allowed'; end if;
 if (serial_count<>expected or p_details->>'panelBrand'<>q->>'panelBrand' or (p_details->>'panelWattage')::int<>(q->>'panelWattage')::int) and nullif(trim(p_details->>'overrideReason'),'') is null then raise exception 'Material change reason is required'; end if;

 select inventory_item_id into panel_item from project_material_requirements where project_id=p.id and item_code like 'PV-%' limit 1;
 if panel_item is null then
  insert into inventory_items(item_code,item_name,category,brand,model,specification,unit,district_id,serialized,reorder_level,created_by)
  values(format('PV-%s-%s',p_details->>'panelBrand',p_details->>'panelWattage'),format('%s %s Solar Panel',p_details->>'panelBrand',p_details->>'panelTechnology'),'PV Module',p_details->>'panelBrand',p_details->>'panelTechnology',format('%s Wp',p_details->>'panelWattage'),'Nos',p.district_id,true,0,auth.uid())
  on conflict(item_code) do update set item_name=excluded.item_name returning id into panel_item;
  update project_material_requirements set inventory_item_id=panel_item where project_id=p.id and item_code like 'PV-%';
 end if;
 for serial in select jsonb_array_elements_text(p_details->'panelSerials') loop
  if nullif(trim(serial),'') is null then raise exception 'Panel serial numbers cannot be blank'; end if;
  if exists(select 1 from inventory_serials where serial_number=serial) then raise exception 'Installed serial number % already exists',serial; end if;
  insert into inventory_serials(inventory_item_id,serial_number,status,project_id) values(panel_item,serial,'installed',p.id);
 end loop;
 insert into installation_materials(project_id,details,created_by) values(p.id,p_details,auth.uid());

 select * into tr from tax_rules where active and effective_from<=inv_date and (effective_to is null or effective_to>=inv_date) order by effective_from desc,created_at desc limit 1;
 if tr.id is null then raise exception 'No active effective-dated split GST rule exists'; end if;
 if round(tr.supply_share_percent+tr.installation_share_percent,3)<>100 then raise exception 'Supply and installation shares must total exactly 100 percent'; end if;

 gross:=(q->>'grandTotal')::numeric;
 supply_gross:=round(gross*tr.supply_share_percent/100,2); install_gross:=gross-supply_gross;
 supply_taxable:=case when tr.supply_gst_rate>0 then round(supply_gross*100/(100+tr.supply_gst_rate),2) else supply_gross end;
 install_taxable:=case when tr.installation_gst_rate>0 then round(install_gross*100/(100+tr.installation_gst_rate),2) else install_gross end;
 supply_tax:=supply_gross-supply_taxable; install_tax:=install_gross-install_taxable;
 if tr.intrastate then
  supply_cgst:=round(supply_tax/2,2); supply_sgst:=supply_tax-supply_cgst;
  install_cgst:=round(install_tax/2,2); install_sgst:=install_tax-install_cgst;
 else supply_igst:=supply_tax; install_igst:=install_tax; end if;
 taxable:=supply_taxable+install_taxable; cgst_total:=supply_cgst+install_cgst; sgst_total:=supply_sgst+install_sgst; igst_total:=supply_igst+install_igst;

 if tr.supply_share_percent>0 then tax_lines:=tax_lines||jsonb_build_array(jsonb_build_object('lineType','supply','description','Solar Power Generation System - Supply','hsnSac',tr.supply_hsn,'sharePercent',tr.supply_share_percent,'gstRate',tr.supply_gst_rate,'grossAmount',supply_gross,'taxableValue',supply_taxable,'cgst',supply_cgst,'sgst',supply_sgst,'igst',supply_igst)); end if;
 if tr.installation_share_percent>0 then tax_lines:=tax_lines||jsonb_build_array(jsonb_build_object('lineType','installation','description','Installation and Commissioning of Solar Power System','hsnSac',tr.installation_sac,'sharePercent',tr.installation_share_percent,'gstRate',tr.installation_gst_rate,'grossAmount',install_gross,'taxableValue',install_taxable,'cgst',install_cgst,'sgst',install_sgst,'igst',install_igst)); end if;

 inv_no:=coalesce(nullif(trim(p_details->>'invoiceNo'),''),next_document_number('invoice','INV'));
 if exists(select 1 from customer_invoices where invoice_no=inv_no) then raise exception 'Invoice number already exists'; end if;
 insert into customer_invoices(id,invoice_no,customer_id,project_id,invoice_date,place_of_supply,status,tax_rule_id,taxable_value,cgst,sgst,igst,grand_total,snapshot,issued_by)
 values(inv_id,inv_no,p.customer_id,p.id,inv_date,place_,'issued',tr.id,taxable,cgst_total,sgst_total,igst_total,gross,
  jsonb_build_object('id',inv_id,'invoiceNo',inv_no,'customerId',p.customer_id,'projectId',p.id,'invoiceDate',inv_date,'placeOfSupply',place_,'status','issued','taxMode','inclusive','taxRuleName',tr.name,'taxLines',tax_lines,'taxableValue',taxable,'cgst',cgst_total,'sgst',sgst_total,'igst',igst_total,'roundOff',0,'grandTotal',gross),auth.uid());
 if tr.supply_share_percent>0 then
  insert into customer_invoice_items(invoice_id,line_type,description,hsn_sac,quantity,unit,share_percent,gross_value,taxable_value,tax_rate,cgst,sgst,igst,serial_numbers)
  values(inv_id,'supply',format('Solar Power Generation System - %s kWp',q->>'dcCapacityKw'),tr.supply_hsn,1,'Job',tr.supply_share_percent,supply_gross,supply_taxable,tr.supply_gst_rate,supply_cgst,supply_sgst,supply_igst,array(select jsonb_array_elements_text(p_details->'panelSerials')));
 end if;
 if tr.installation_share_percent>0 then
  insert into customer_invoice_items(invoice_id,line_type,description,hsn_sac,quantity,unit,share_percent,gross_value,taxable_value,tax_rate,cgst,sgst,igst)
  values(inv_id,'installation',format('Installation and Commissioning of %s kWp Solar Power System',q->>'dcCapacityKw'),tr.installation_sac,1,'Job',tr.installation_share_percent,install_gross,install_taxable,tr.installation_gst_rate,install_cgst,install_sgst,install_igst);
 end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata)
 values(auth.uid(),'customer_invoice_issued','customer_invoice',inv_id,p_details->>'overrideReason',jsonb_build_object('projectId',p.id,'invoiceNo',inv_no,'gross',gross,'serialCount',serial_count,'taxRuleId',tr.id,'taxLines',tax_lines));
 return inv_id;
end $$;

grant execute on function public.save_installation_and_issue_invoice(uuid,jsonb) to authenticated;

commit;

-- ==================================================
-- 202607200012_invoice_gst_treatment_and_standard_split.sql
-- ==================================================
begin;

alter table public.customer_invoices add column if not exists quoted_amount numeric(14,2);
alter table public.customer_invoices add column if not exists tax_treatment text;
update public.customer_invoices
set quoted_amount=coalesce(quoted_amount,grand_total),
    tax_treatment=coalesce(tax_treatment,'inclusive')
where quoted_amount is null or tax_treatment is null;
alter table public.customer_invoices alter column quoted_amount set default 0;
alter table public.customer_invoices alter column quoted_amount set not null;
alter table public.customer_invoices alter column tax_treatment set default 'inclusive';
alter table public.customer_invoices alter column tax_treatment set not null;

do $$
begin
 if not exists(select 1 from pg_constraint where conname='customer_invoices_tax_treatment_check') then
  alter table public.customer_invoices add constraint customer_invoices_tax_treatment_check
  check(tax_treatment in('inclusive','exclusive'));
 end if;
end $$;

insert into public.tax_rules(
 name,effective_from,gst_rate,intrastate,active,supply_gst_rate,installation_gst_rate,
 supply_share_percent,installation_share_percent,supply_hsn,installation_sac
)
select 'Solar EPC 70/30 - Supply 5% / Installation 18%',date '2026-07-20',5,true,true,5,18,70,30,'854140','995442'
where not exists(
 select 1 from public.tax_rules
 where name='Solar EPC 70/30 - Supply 5% / Installation 18%' and effective_from=date '2026-07-20'
);

create or replace function public.save_installation_and_issue_invoice(p_project_id uuid,p_details jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 p projects%rowtype; q jsonb; expected int; serial_count int; duplicate_count int; tr tax_rules%rowtype;
 quote_amount numeric; tax_treatment text; gross numeric; supply_amount numeric; install_amount numeric;
 supply_gross numeric; install_gross numeric; supply_taxable numeric; install_taxable numeric;
 supply_tax numeric; install_tax numeric; supply_cgst numeric:=0; supply_sgst numeric:=0; supply_igst numeric:=0;
 install_cgst numeric:=0; install_sgst numeric:=0; install_igst numeric:=0;
 taxable numeric; cgst_total numeric; sgst_total numeric; igst_total numeric; tax_lines jsonb:='[]'::jsonb;
 inv_id uuid:=gen_random_uuid(); inv_no text; inv_date date:=coalesce(nullif(p_details->>'invoiceDate','')::date,current_date);
 place_ text:=coalesce(nullif(trim(p_details->>'placeOfSupply'),''),'Gujarat (24)'); serial text; panel_item uuid;
begin
 select * into p from projects where id=p_project_id for update;
 if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if;
 if not (p.current_stage = any(array['installation_done','inspection_pending','inspection_done','meter_pending','meter_done','commissioning_done','subsidy_pending','subsidy_passed','handover_completed','project_closed']::project_stage[])) then raise exception 'Invoice is available only after Project Installation Done'; end if;
 if exists(select 1 from customer_invoices where project_id=p.id and status in('issued','paid')) then raise exception 'An active invoice already exists'; end if;
 q:=p.accepted_quotation_snapshot; expected:=(q->>'panelQuantity')::int; serial_count:=jsonb_array_length(coalesce(p_details->'panelSerials','[]'));
 if serial_count<1 then raise exception 'Panel serial numbers are required'; end if;
 select count(*)-count(distinct value) into duplicate_count from jsonb_array_elements_text(p_details->'panelSerials');
 if duplicate_count>0 then raise exception 'Duplicate panel serial numbers are not allowed'; end if;
 if (serial_count<>expected or p_details->>'panelBrand'<>q->>'panelBrand' or (p_details->>'panelWattage')::int<>(q->>'panelWattage')::int) and nullif(trim(p_details->>'overrideReason'),'') is null then raise exception 'Material change reason is required'; end if;

 select inventory_item_id into panel_item from project_material_requirements where project_id=p.id and item_code like 'PV-%' limit 1;
 if panel_item is null then
  insert into inventory_items(item_code,item_name,category,brand,model,specification,unit,district_id,serialized,reorder_level,created_by)
  values(format('PV-%s-%s',p_details->>'panelBrand',p_details->>'panelWattage'),format('%s %s Solar Panel',p_details->>'panelBrand',p_details->>'panelTechnology'),'PV Module',p_details->>'panelBrand',p_details->>'panelTechnology',format('%s Wp',p_details->>'panelWattage'),'Nos',p.district_id,true,0,auth.uid())
  on conflict(item_code) do update set item_name=excluded.item_name returning id into panel_item;
  update project_material_requirements set inventory_item_id=panel_item where project_id=p.id and item_code like 'PV-%';
 end if;
 for serial in select jsonb_array_elements_text(p_details->'panelSerials') loop
  if nullif(trim(serial),'') is null then raise exception 'Panel serial numbers cannot be blank'; end if;
  if exists(select 1 from inventory_serials where serial_number=serial) then raise exception 'Installed serial number % already exists',serial; end if;
  insert into inventory_serials(inventory_item_id,serial_number,status,project_id) values(panel_item,serial,'installed',p.id);
 end loop;
 insert into installation_materials(project_id,details,created_by) values(p.id,p_details,auth.uid());

 select * into tr from tax_rules where active and effective_from<=inv_date and (effective_to is null or effective_to>=inv_date) order by effective_from desc,created_at desc limit 1;
 if tr.id is null then raise exception 'No active effective-dated split GST rule exists'; end if;
 if round(tr.supply_share_percent+tr.installation_share_percent,3)<>100 then raise exception 'Supply and installation shares must total exactly 100 percent'; end if;
 tax_treatment:=coalesce(nullif(p_details->>'taxTreatment',''),'inclusive');
 if tax_treatment not in('inclusive','exclusive') then raise exception 'Invoice GST treatment must be inclusive or exclusive'; end if;
 quote_amount:=(q->>'grandTotal')::numeric;
 supply_amount:=round(quote_amount*tr.supply_share_percent/100,2); install_amount:=quote_amount-supply_amount;

 if tax_treatment='inclusive' then
  supply_gross:=supply_amount; install_gross:=install_amount;
  supply_taxable:=case when tr.supply_gst_rate>0 then round(supply_gross*100/(100+tr.supply_gst_rate),2) else supply_gross end;
  install_taxable:=case when tr.installation_gst_rate>0 then round(install_gross*100/(100+tr.installation_gst_rate),2) else install_gross end;
  supply_tax:=supply_gross-supply_taxable; install_tax:=install_gross-install_taxable;
 else
  supply_taxable:=supply_amount; install_taxable:=install_amount;
  supply_tax:=round(supply_taxable*tr.supply_gst_rate/100,2); install_tax:=round(install_taxable*tr.installation_gst_rate/100,2);
  supply_gross:=supply_taxable+supply_tax; install_gross:=install_taxable+install_tax;
 end if;

 if tr.intrastate then
  supply_cgst:=round(supply_tax/2,2); supply_sgst:=supply_tax-supply_cgst;
  install_cgst:=round(install_tax/2,2); install_sgst:=install_tax-install_cgst;
 else supply_igst:=supply_tax; install_igst:=install_tax; end if;
 taxable:=supply_taxable+install_taxable; cgst_total:=supply_cgst+install_cgst; sgst_total:=supply_sgst+install_sgst; igst_total:=supply_igst+install_igst;
 gross:=supply_gross+install_gross;

 if tr.supply_share_percent>0 then tax_lines:=tax_lines||jsonb_build_array(jsonb_build_object('lineType','supply','description','Solar Power Generation System - Supply','hsnSac',tr.supply_hsn,'sharePercent',tr.supply_share_percent,'gstRate',tr.supply_gst_rate,'grossAmount',supply_gross,'taxableValue',supply_taxable,'cgst',supply_cgst,'sgst',supply_sgst,'igst',supply_igst)); end if;
 if tr.installation_share_percent>0 then tax_lines:=tax_lines||jsonb_build_array(jsonb_build_object('lineType','installation','description','Installation and Commissioning of Solar Power System','hsnSac',tr.installation_sac,'sharePercent',tr.installation_share_percent,'gstRate',tr.installation_gst_rate,'grossAmount',install_gross,'taxableValue',install_taxable,'cgst',install_cgst,'sgst',install_sgst,'igst',install_igst)); end if;

 inv_no:=coalesce(nullif(trim(p_details->>'invoiceNo'),''),next_document_number('invoice','INV'));
 if exists(select 1 from customer_invoices where invoice_no=inv_no) then raise exception 'Invoice number already exists'; end if;
 insert into customer_invoices(id,invoice_no,customer_id,project_id,invoice_date,place_of_supply,status,tax_rule_id,quoted_amount,tax_treatment,taxable_value,cgst,sgst,igst,grand_total,snapshot,issued_by)
 values(inv_id,inv_no,p.customer_id,p.id,inv_date,place_,'issued',tr.id,quote_amount,tax_treatment,taxable,cgst_total,sgst_total,igst_total,gross,
  jsonb_build_object('id',inv_id,'invoiceNo',inv_no,'customerId',p.customer_id,'projectId',p.id,'invoiceDate',inv_date,'placeOfSupply',place_,'status','issued','taxMode',tax_treatment,'quotedAmount',quote_amount,'taxRuleName',tr.name,'taxLines',tax_lines,'taxableValue',taxable,'cgst',cgst_total,'sgst',sgst_total,'igst',igst_total,'roundOff',0,'grandTotal',gross),auth.uid());
 if tr.supply_share_percent>0 then
  insert into customer_invoice_items(invoice_id,line_type,description,hsn_sac,quantity,unit,share_percent,gross_value,taxable_value,tax_rate,cgst,sgst,igst,serial_numbers)
  values(inv_id,'supply',format('Solar Power Generation System - %s kWp',q->>'dcCapacityKw'),tr.supply_hsn,1,'Job',tr.supply_share_percent,supply_gross,supply_taxable,tr.supply_gst_rate,supply_cgst,supply_sgst,supply_igst,array(select jsonb_array_elements_text(p_details->'panelSerials')));
 end if;
 if tr.installation_share_percent>0 then
  insert into customer_invoice_items(invoice_id,line_type,description,hsn_sac,quantity,unit,share_percent,gross_value,taxable_value,tax_rate,cgst,sgst,igst)
  values(inv_id,'installation',format('Installation and Commissioning of %s kWp Solar Power System',q->>'dcCapacityKw'),tr.installation_sac,1,'Job',tr.installation_share_percent,install_gross,install_taxable,tr.installation_gst_rate,install_cgst,install_sgst,install_igst);
 end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata)
 values(auth.uid(),'customer_invoice_issued','customer_invoice',inv_id,p_details->>'overrideReason',jsonb_build_object('projectId',p.id,'invoiceNo',inv_no,'quotedAmount',quote_amount,'taxTreatment',tax_treatment,'gross',gross,'serialCount',serial_count,'taxRuleId',tr.id,'taxLines',tax_lines));
 return inv_id;
end $$;

grant execute on function public.save_installation_and_issue_invoice(uuid,jsonb) to authenticated;

commit;

-- ==================================================
-- 202607200013_manual_quote_loan_dealer_receipts.sql
-- ==================================================
-- Manual + automatic quotation controls, fixed dealer commission workflow and material-receipt support.
begin;

create or replace function public.save_dealer(p_dealer jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 role public.app_role:=public.current_role();
 did uuid; id_ uuid:=coalesce(nullif(p_dealer->>'id','')::uuid,gen_random_uuid());
 mobile_ text:=regexp_replace(coalesce(p_dealer->>'mobile',''),'\D','','g');
begin
 if role not in ('admin','district_partner') then raise exception 'Admin or Area Partner access required'; end if;
 if role='district_partner' then did:=public.current_district();
 else did:=coalesce(nullif(p_dealer->>'districtId','')::uuid,(select id from districts where active and name=p_dealer->>'district'));
 end if;
 if did is null then raise exception 'Dealer area is required'; end if;
 if length(mobile_)<>10 then raise exception 'Dealer mobile number must contain exactly 10 digits'; end if;
 if role='district_partner' and exists(select 1 from dealers where id=id_ and district_id<>did) then raise exception 'Dealer is outside your assigned area'; end if;
 insert into dealers(id,dealer_no,name,mobile,email,address,district_id,login_user_id,default_commission_type,default_commission_value,active,created_by,updated_by)
 values(id_,next_document_number('dealer','DL'),trim(p_dealer->>'name'),mobile_,nullif(lower(trim(p_dealer->>'email')),''),nullif(trim(p_dealer->>'address'),''),did,nullif(p_dealer->>'loginUserId','')::uuid,'fixed',greatest(0,coalesce(nullif(p_dealer->>'commissionValue','')::numeric,0)),coalesce((p_dealer->>'active')::boolean,true),auth.uid(),auth.uid())
 on conflict(id) do update set name=excluded.name,mobile=excluded.mobile,email=excluded.email,address=excluded.address,district_id=excluded.district_id,default_commission_type='fixed',default_commission_value=excluded.default_commission_value,active=excluded.active,updated_by=auth.uid(),updated_at=now();
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'dealer_saved','dealer',id_,jsonb_build_object('source','quotation_or_dealer_master','commissionType','fixed'));
 return id_;
exception when unique_violation then raise exception 'A dealer with this mobile number already exists in the selected area';
end $$;
grant execute on function public.save_dealer(jsonb) to authenticated;

create or replace function public.save_quotation_version(p_quote jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 qid uuid; input_id uuid:=nullif(p_quote->>'id','')::uuid; requested_no text:=nullif(trim(p_quote->>'quoteNo'),''); qno text; ver int; old_status quote_status;
 cid uuid:=(p_quote->>'customerId')::uuid; c customers%rowtype; price active_price_rows%rowtype; final numeric:=(p_quote->>'grandTotal')::numeric; suggested numeric;
 quoted_capacity numeric:=coalesce(nullif(p_quote->>'dcCapacityKw','')::numeric,0); quoted_wattage int:=coalesce(nullif(p_quote->>'panelWattage','')::int,0); quoted_quantity int:=coalesce(nullif(p_quote->>'panelQuantity','')::int,0);
 v_id uuid:=gen_random_uuid(); item jsonb; actor uuid:=auth.uid(); dealer uuid; commission numeric:=0; existing quotations%rowtype; source_id uuid:=nullif(p_quote->'priceSnapshot'->>'priceRowId','')::uuid; config_changed boolean:=false;
begin
 if not can_access_customer(cid) then raise exception 'Customer is not accessible'; end if; select * into c from customers where id=cid;
 if quoted_capacity<=0 or quoted_wattage<=0 or quoted_quantity<=0 then raise exception 'Panel wattage, quantity and exact DC capacity must be greater than zero'; end if;
 if upper(trim(p_quote->>'panelBrand'))='WAAREE' and quoted_wattage not in (540,580) then raise exception 'WAAREE quotation wattage must be 540 Wp or 580 Wp'; end if;
 if public.current_role()='dealer' then dealer:=current_dealer(); else dealer:=nullif(p_quote->>'dealerId','')::uuid; end if;
 if dealer is not null and not exists(select 1 from dealers d where d.id=dealer and d.active and d.deleted_at is null and d.district_id=c.district_id) then raise exception 'Selected dealer is not active in the customer area'; end if;
 if source_id is not null then select * into price from active_price_rows where id=source_id; end if;
 if price.id is null then select * into price from active_price_rows where panel_brand=upper(p_quote->>'panelBrand') and panel_technology=p_quote->>'panelTechnology' and panel_wattage=quoted_wattage and panel_quantity=quoted_quantity; end if;
 if price.id is null then raise exception 'A verified source price row is required'; end if; suggested:=price.gross_price;
 config_changed:=upper(trim(p_quote->>'panelBrand'))<>upper(price.panel_brand) or p_quote->>'panelTechnology'<>price.panel_technology or quoted_wattage<>price.panel_wattage or quoted_quantity<>price.panel_quantity or abs(quoted_capacity-price.dc_capacity_kw)>.0005;
 if config_changed and nullif(trim(p_quote->>'configurationOverrideReason'),'') is null then raise exception 'Manual configuration edit reason is required'; end if;
 if final<>suggested and nullif(trim(p_quote->>'priceOverrideReason'),'') is null then raise exception 'Price override reason is required'; end if;
 if (p_quote->>'taxMode')<>'inclusive' then raise exception 'Published price is GST-inclusive and cannot be changed to GST-extra'; end if;
 if public.current_role()<>'dealer' then commission:=greatest(0,coalesce(nullif(p_quote->>'dealerCommission','')::numeric,0)); end if;

 if input_id is not null then select * into existing from quotations where id=input_id and deleted_at is null; end if;
 if existing.id is null and requested_no is not null then select * into existing from quotations where quotation_no=requested_no and deleted_at is null; end if;
 if existing.id is not null then
  if requested_no is not null and existing.quotation_no=requested_no and input_id<>existing.id and coalesce((p_quote->>'versionNo')::int,1)<=1 then raise exception 'Quotation number already exists'; end if;
  if existing.customer_id<>cid then raise exception 'Quotation customer cannot be changed'; end if;
  qid:=existing.id; qno:=existing.quotation_no; ver:=existing.current_version+1; old_status:=existing.current_status;
  update quotations set current_version=ver,current_status='draft',dealer_id=dealer,updated_by=actor,updated_at=now(),sent_at=null,approved_at=null,rejected_at=null where id=qid;
  insert into quotation_status_history(quotation_id,from_status,to_status,reason,changed_by) values(qid,old_status,'draft','Commercial revision created',actor);
 else
  qid:=coalesce(input_id,gen_random_uuid()); qno:=coalesce(requested_no,next_document_number('quotation','QT')); ver:=1;
  if exists(select 1 from quotations where quotation_no=qno) then raise exception 'Quotation number already exists'; end if;
  insert into quotations(id,quotation_no,customer_id,district_id,dealer_id,current_version,current_status,created_by,updated_by) values(qid,qno,cid,c.district_id,dealer,ver,'draft',actor,actor);
  insert into quotation_status_history(quotation_id,to_status,changed_by) values(qid,'draft',actor);
 end if;
 insert into quotation_versions(id,quotation_id,version_no,price_list_item_id,system_type,dcr_type,scheme,panel_brand,panel_technology,panel_wattage,panel_quantity,dc_capacity_kw,suggested_price,final_price,price_override_reason,gst_included,dealer_commission,internal_cost,immutable_snapshot,created_by)
 values(v_id,qid,ver,price.id,p_quote->>'systemType',p_quote->>'dcrType',p_quote->>'scheme',upper(trim(p_quote->>'panelBrand')),p_quote->>'panelTechnology',quoted_wattage,quoted_quantity,quoted_capacity,suggested,final,nullif(p_quote->>'priceOverrideReason',''),true,commission,case when public.current_role()='dealer' then 0 else coalesce(nullif(p_quote->>'internalCost','')::numeric,0) end,p_quote||jsonb_build_object('id',qid,'quoteNo',qno,'versionNo',ver,'status','draft','suggestedPrice',suggested,'basePrice',final,'grandTotal',final,'dcCapacityKw',quoted_capacity,'dealerId',dealer,'dealerCommission',commission,'taxMode','inclusive','subsidy',coalesce(p_quote->'subsidy',jsonb_build_object('eligible',true,'central',78000,'state',0,'total',78000,'informationalOnly',true))),actor);
 for item in select * from jsonb_array_elements(coalesce(p_quote->'items','[]')) loop
  insert into quotation_items(quotation_version_id,description,brand,specification,quantity,unit,rate,selected,internal_only) values(v_id,item->>'description',nullif(item->>'brand',''),nullif(item->>'specification',''),coalesce((item->>'quantity')::numeric,1),coalesce(item->>'unit','Nos'),coalesce(nullif(item->>'rate','')::numeric,0),coalesce((item->>'selected')::boolean,true),coalesce((item->>'internalOnly')::boolean,false));
 end loop;
 if final<>suggested then insert into quotation_overrides(quotation_id,version_no,suggested_price,final_price,reason,created_by) values(qid,ver,suggested,final,p_quote->>'priceOverrideReason',actor); end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(actor,'quotation_version_saved','quotation',qid,coalesce(nullif(p_quote->>'configurationOverrideReason',''),nullif(p_quote->>'priceOverrideReason','')),jsonb_build_object('version',ver,'quotationNo',qno,'suggested',suggested,'final',final,'configurationMode',coalesce(p_quote->>'configurationMode','automatic'),'loanRequired',coalesce((p_quote->>'loanRequired')::boolean,false)));
 return qid;
end $$;
grant execute on function public.save_quotation_version(jsonb) to authenticated;

commit;

-- ==================================================
-- 202607200014_official_price_match_and_project_cleanup.sql
-- ==================================================
-- Official five-PDF price source, internal quotation matching, invoice cancellation and safe project cleanup.
begin;

do $$
declare
 list_540 uuid; list_580 uuid; list_w610 uuid; list_a550 uuid; list_a610 uuid; verified_count integer;
begin
 update public.price_lists set status='inactive' where status='published';

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official WAAREE Bifacial 540 Wp',1,date '2026-07-20','published','Ratneswar_WAAREE BIFACIAL 540WP PRICE LIST.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_540;
 update public.price_list_items set active=false where price_list_id=list_540;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',4,2.160,112615,62880,49735,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',5,2.700,133320,69000,64320,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',6,3.240,156752,78000,78752,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',7,3.780,177154,78000,99154,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',8,4.320,202000,78000,124000,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',9,4.860,227654,78000,149654,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',10,5.400,249066,78000,171066,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',11,5.940,274013,78000,196013,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',12,6.480,318554,78000,240554,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',14,7.560,364105,78000,286105,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',16,8.640,403293,78000,325293,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',18,9.720,442481,78000,364481,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official WAAREE TOPCon 580 Wp',1,date '2026-07-20','published','Ratneswar_WAREE_TOPCORN_580WP.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_580;
 update public.price_list_items set active=false where price_list_id=list_580;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',4,2.320,124129,65760,58369,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',5,2.900,149076,76200,72876,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',6,3.480,174023,78000,96023,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',7,4.060,203010,78000,125010,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',8,4.640,226442,78000,148442,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',9,5.220,255934,78000,177934,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',10,5.800,277851,78000,199851,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',12,6.960,352187,78000,274187,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',14,8.120,398950,78000,320950,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',17,9.860,472276,78000,394276,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',18,10.440,494294,78000,416294,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official WAAREE TOPCon 610-615 Wp',1,date '2026-07-20','published','Ratneswar_WAREE_TOPCORN_610-615WP.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_w610;
 update public.price_list_items set active=false where price_list_id=list_w610;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',4,2.440,129381,67920,61461,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',5,3.050,155742,78000,77742,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',6,3.660,178972,78000,100972,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',7,4.270,212302,78000,134302,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',8,4.880,242198,78000,164198,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',9,5.490,267751,78000,189751,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',10,6.100,315019,78000,237019,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',12,7.320,368044,78000,290044,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',14,8.540,417534,78000,339534,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',16,9.760,471468,78000,393468,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',17,10.370,494698,78000,416698,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official ADANI Bifacial 550 Wp',1,date '2026-07-20','published','Ratneswar_Adani_Bifacial_550WP.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_a550;
 update public.price_list_items set active=false where price_list_id=list_a550;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',4,2.200,117665,63600,54065,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',5,2.750,140996,69000,71996,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',6,3.300,161297,78000,83297,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',7,3.850,186042,78000,108042,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',8,4.400,213514,78000,135514,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',9,4.950,236138,78000,158138,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',10,5.500,262297,78000,184297,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',12,6.600,332189,78000,254189,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',14,7.700,374811,78000,296811,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',16,8.800,423392,78000,345392,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',18,9.900,465105,78000,387105,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',19,10.450,485507,78000,407507,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official ADANI TOPCon 610-625 Wp',1,date '2026-07-20','published','Ratneswar_Adani TOPCON 610-615-620-625WP PRICE LIST.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_a610;
 update public.price_list_items set active=false where price_list_id=list_a610;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',4,2.440,131502,67920,63582,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',5,3.050,158267,78000,80267,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',6,3.660,182002,78000,104002,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',7,4.270,215938,78000,137938,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',8,4.880,246238,78000,168238,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',9,5.490,272397,78000,194397,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',10,6.100,320776,78000,242776,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',12,7.320,374205,78000,296205,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',14,8.540,424705,78000,346705,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',16,9.760,479750,78000,401750,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',17,10.370,503485,78000,425485,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 select count(*) into verified_count from public.price_list_items where active and price_list_id in(list_540,list_580,list_w610,list_a550,list_a610);
 if verified_count<>57 then raise exception 'Official price seed must contain 57 rows; found %',verified_count; end if;
end $$;

create or replace function public.save_quotation_version(p_quote jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 qid uuid; input_id uuid:=nullif(p_quote->>'id','')::uuid; requested_no text:=nullif(trim(p_quote->>'quoteNo'),''); qno text; ver int; old_status quote_status;
 cid uuid:=(p_quote->>'customerId')::uuid; c customers%rowtype; price active_price_rows%rowtype; final numeric:=(p_quote->>'grandTotal')::numeric; suggested numeric;
 quoted_capacity numeric:=coalesce(nullif(p_quote->>'dcCapacityKw','')::numeric,0); quoted_wattage int:=coalesce(nullif(p_quote->>'panelWattage','')::int,0); quoted_quantity int:=coalesce(nullif(p_quote->>'panelQuantity','')::int,0); calculated_capacity numeric;
 v_id uuid:=gen_random_uuid(); item jsonb; actor uuid:=auth.uid(); dealer uuid; commission numeric:=0; existing quotations%rowtype; source_id uuid:=nullif(p_quote->'priceSnapshot'->>'priceRowId','')::uuid; config_changed boolean:=false;
begin
 if not can_access_customer(cid) then raise exception 'Customer is not accessible'; end if; select * into c from customers where id=cid;
 if quoted_capacity<=0 or quoted_wattage<=0 or quoted_quantity<=0 then raise exception 'Panel wattage, quantity and exact DC capacity must be greater than zero'; end if;
 if public.current_role()='dealer' then dealer:=current_dealer(); else dealer:=nullif(p_quote->>'dealerId','')::uuid; end if;
 if dealer is not null and not exists(select 1 from dealers d where d.id=dealer and d.active and d.deleted_at is null and d.district_id=c.district_id) then raise exception 'Selected dealer is not active in the customer area'; end if;
 if source_id is not null then
  select * into price from active_price_rows
  where id=source_id and panel_brand=upper(trim(p_quote->>'panelBrand')) and panel_technology=p_quote->>'panelTechnology'
   and quoted_wattage between panel_wattage_min and panel_wattage_max;
 end if;
 if price.id is null then
  select * into price from active_price_rows
  where panel_brand=upper(trim(p_quote->>'panelBrand')) and panel_technology=p_quote->>'panelTechnology'
   and quoted_wattage between panel_wattage_min and panel_wattage_max and panel_quantity=quoted_quantity
  limit 1;
 end if;
 if price.id is null then raise exception 'No official price configuration exists for this brand, technology and wattage'; end if;
 suggested:=price.gross_price; calculated_capacity:=round(quoted_wattage*quoted_quantity/1000.0,3);
 config_changed:=quoted_quantity<>price.panel_quantity or abs(quoted_capacity-calculated_capacity)>.0005;
 if config_changed and nullif(trim(p_quote->>'configurationOverrideReason'),'') is null then raise exception 'Manual configuration edit reason is required'; end if;
 if final<>suggested and nullif(trim(p_quote->>'priceOverrideReason'),'') is null then raise exception 'Price override reason is required'; end if;
 if (p_quote->>'taxMode')<>'inclusive' then raise exception 'Published price is GST-inclusive and cannot be changed to GST-extra'; end if;
 if public.current_role()<>'dealer' then commission:=greatest(0,coalesce(nullif(p_quote->>'dealerCommission','')::numeric,0)); end if;

 if input_id is not null then select * into existing from quotations where id=input_id and deleted_at is null; end if;
 if existing.id is null and requested_no is not null then select * into existing from quotations where quotation_no=requested_no and deleted_at is null; end if;
 if existing.id is not null then
  if requested_no is not null and existing.quotation_no=requested_no and input_id<>existing.id and coalesce((p_quote->>'versionNo')::int,1)<=1 then raise exception 'Quotation number already exists'; end if;
  if existing.customer_id<>cid then raise exception 'Quotation customer cannot be changed'; end if;
  qid:=existing.id; qno:=existing.quotation_no; ver:=existing.current_version+1; old_status:=existing.current_status;
  update quotations set current_version=ver,current_status='draft',dealer_id=dealer,updated_by=actor,updated_at=now(),sent_at=null,approved_at=null,rejected_at=null where id=qid;
  insert into quotation_status_history(quotation_id,from_status,to_status,reason,changed_by) values(qid,old_status,'draft','Commercial revision created',actor);
 else
  qid:=coalesce(input_id,gen_random_uuid()); qno:=coalesce(requested_no,next_document_number('quotation','QT')); ver:=1;
  if exists(select 1 from quotations where quotation_no=qno) then raise exception 'Quotation number already exists'; end if;
  insert into quotations(id,quotation_no,customer_id,district_id,dealer_id,current_version,current_status,created_by,updated_by) values(qid,qno,cid,c.district_id,dealer,ver,'draft',actor,actor);
  insert into quotation_status_history(quotation_id,to_status,changed_by) values(qid,'draft',actor);
 end if;
 insert into quotation_versions(id,quotation_id,version_no,price_list_item_id,system_type,dcr_type,scheme,panel_brand,panel_technology,panel_wattage,panel_quantity,dc_capacity_kw,suggested_price,final_price,price_override_reason,gst_included,dealer_commission,internal_cost,immutable_snapshot,created_by)
 values(v_id,qid,ver,price.id,p_quote->>'systemType',p_quote->>'dcrType',p_quote->>'scheme',upper(trim(p_quote->>'panelBrand')),p_quote->>'panelTechnology',quoted_wattage,quoted_quantity,quoted_capacity,suggested,final,nullif(p_quote->>'priceOverrideReason',''),true,commission,case when public.current_role()='dealer' then 0 else coalesce(nullif(p_quote->>'internalCost','')::numeric,0) end,p_quote||jsonb_build_object('id',qid,'quoteNo',qno,'versionNo',ver,'status','draft','suggestedPrice',suggested,'basePrice',final,'grandTotal',final,'dcCapacityKw',quoted_capacity,'dealerId',dealer,'dealerCommission',commission,'taxMode','inclusive'),actor);
 for item in select * from jsonb_array_elements(coalesce(p_quote->'items','[]')) loop
  insert into quotation_items(quotation_version_id,description,brand,specification,quantity,unit,rate,selected,internal_only) values(v_id,item->>'description',nullif(item->>'brand',''),nullif(item->>'specification',''),coalesce((item->>'quantity')::numeric,1),coalesce(item->>'unit','Nos'),coalesce(nullif(item->>'rate','')::numeric,0),coalesce((item->>'selected')::boolean,true),coalesce((item->>'internalOnly')::boolean,false));
 end loop;
 if final<>suggested then insert into quotation_overrides(quotation_id,version_no,suggested_price,final_price,reason,created_by) values(qid,ver,suggested,final,p_quote->>'priceOverrideReason',actor); end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(actor,'quotation_version_saved','quotation',qid,coalesce(nullif(p_quote->>'configurationOverrideReason',''),nullif(p_quote->>'priceOverrideReason','')),jsonb_build_object('version',ver,'quotationNo',qno,'officialPriceRowId',price.id,'suggested',suggested,'final',final,'quotedWattage',quoted_wattage,'quotedQuantity',quoted_quantity,'quotedCapacity',quoted_capacity,'loanRequired',coalesce((p_quote->>'loanRequired')::boolean,false)));
 return qid;
end $$;
grant execute on function public.save_quotation_version(jsonb) to authenticated;

create or replace function public.cancel_customer_invoice(p_invoice_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare inv public.customer_invoices%rowtype;
begin
 if not public.is_admin() then raise exception 'Only Admin can cancel an invoice'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Invoice cancellation reason is required'; end if;
 select * into inv from public.customer_invoices where id=p_invoice_id for update;
 if inv.id is null then raise exception 'Invoice not found'; end if;
 if inv.status='cancelled' then return; end if;
 if inv.status not in('issued') then raise exception 'Only an issued, unpaid invoice can be cancelled'; end if;
 update public.customer_invoices set status='cancelled',cancelled_at=now(),cancellation_reason=trim(p_reason),snapshot=snapshot||jsonb_build_object('status','cancelled','cancelledAt',now(),'cancellationReason',trim(p_reason)) where id=inv.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'customer_invoice_cancelled','customer_invoice',inv.id,trim(p_reason),jsonb_build_object('invoiceNo',inv.invoice_no,'projectId',inv.project_id));
end $$;
grant execute on function public.cancel_customer_invoice(uuid,text) to authenticated;

create or replace function public.delete_erroneous_project(p_project_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare p public.projects%rowtype;
begin
 if not public.is_admin() then raise exception 'Only Admin can delete a project'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Deletion reason is required'; end if;
 select * into p from public.projects where id=p_project_id for update;
 if p.id is null then raise exception 'Project not found'; end if;
 if exists(select 1 from public.customer_invoices where project_id=p.id and status<>'cancelled') then raise exception 'Cancel the active invoice before deleting this project'; end if;
 if exists(select 1 from public.stock_transactions where project_id=p.id and transaction_type<>'reservation') then raise exception 'A project with issued or consumed stock cannot be deleted'; end if;
 if exists(select 1 from public.dealer_commission_payments cp join public.dealer_commissions c on c.id=cp.commission_id where c.project_id=p.id) then raise exception 'A project with dealer commission payments cannot be deleted'; end if;
 if exists(select 1 from public.payments where project_id=p.id and deleted_at is null) or exists(select 1 from public.expenses where project_id=p.id and deleted_at is null) then raise exception 'Remove linked payments and expenses before deleting this project'; end if;

 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,metadata)
 values(auth.uid(),'erroneous_project_deleted','project',p.id,trim(p_reason),jsonb_build_object('projectNo',p.project_no,'quotationId',p.quotation_id,'cancelledInvoices',(select count(*) from customer_invoices where project_id=p.id and status='cancelled')));
 delete from public.customer_invoice_items where invoice_id in(select id from public.customer_invoices where project_id=p.id and status='cancelled');
 delete from public.customer_invoices where project_id=p.id and status='cancelled';
 delete from public.inventory_serials where project_id=p.id;
 delete from public.installation_materials where project_id=p.id;
 delete from public.stock_transactions where project_id=p.id and transaction_type='reservation';
 delete from public.dealer_commissions where project_id=p.id;
 delete from public.project_material_requirements where project_id=p.id;
 delete from public.project_stage_history where project_id=p.id;
 delete from public.project_documents where project_id=p.id;
 update public.agreements set project_id=null where project_id=p.id;
 delete from public.projects where id=p.id;
 update public.quotations set current_status='approved',project_created_at=null,updated_by=auth.uid(),updated_at=now() where id=p.quotation_id and deleted_at is null;
end $$;
grant execute on function public.delete_erroneous_project(uuid,text) to authenticated;

commit;
