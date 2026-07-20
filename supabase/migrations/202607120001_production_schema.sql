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
