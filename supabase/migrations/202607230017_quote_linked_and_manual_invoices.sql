begin;

create or replace function public.linked_bill_number(p_quote_no text,p_invoice_date date default current_date) returns text
language plpgsql immutable set search_path=public as $$
declare
 digits text;
 serial_number bigint;
 fy_start int;
begin
 digits:=substring(trim(coalesce(p_quote_no,'')) from '([0-9]+)$');
 if digits is null then raise exception 'Quotation number must end with a numeric serial'; end if;
 if digits ~ '^20[0-9]{2}[0-9]+$' then digits:=substring(digits from 5); end if;
 serial_number:=digits::bigint;
 if serial_number<1 then raise exception 'Quotation serial must be greater than zero'; end if;
 fy_start:=extract(year from p_invoice_date)::int-case when extract(month from p_invoice_date)<4 then 1 else 0 end;
 return format('RE/BILL/%s-%s/%s',right(fy_start::text,2),right((fy_start+1)::text,2),lpad(serial_number::text,4,'0'));
end $$;

create table if not exists public.manual_invoices(
 id uuid primary key default gen_random_uuid(),
 invoice_no text not null unique,
 legacy_quote_no text not null,
 invoice_date date not null,
 customer_name text not null,
 mobile text,
 district_name text not null,
 consumer_number text,
 capacity_kw numeric(10,3) not null check(capacity_kw>0),
 grand_total numeric(14,2) not null check(grand_total>0),
 status text not null default 'issued' check(status in('issued','cancelled')),
 snapshot jsonb not null,
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 cancelled_at timestamptz,
 cancellation_reason text
);

create index if not exists manual_invoices_created_at_idx on public.manual_invoices(created_at desc);
create index if not exists manual_invoices_quote_idx on public.manual_invoices(legacy_quote_no);
alter table public.manual_invoices enable row level security;

drop policy if exists manual_invoices_admin_read on public.manual_invoices;
create policy manual_invoices_admin_read on public.manual_invoices
for select to authenticated using(public.current_role()='admin');

grant select on table public.manual_invoices to authenticated;

create or replace function public.force_quote_linked_bill_number() returns trigger
language plpgsql security definer set search_path=public as $$
declare
 quote_no text;
 generated_no text;
begin
 select accepted_quotation_snapshot->>'quoteNo' into quote_no from public.projects where id=new.project_id;
 if nullif(trim(quote_no),'') is null then raise exception 'Accepted quotation number is missing'; end if;
 generated_no:=public.linked_bill_number(quote_no,new.invoice_date);
 if exists(select 1 from public.manual_invoices where invoice_no=generated_no and status='issued') then
  raise exception 'Bill number % is already used by a manual invoice',generated_no;
 end if;
 new.invoice_no:=generated_no;
 new.snapshot:=jsonb_set(coalesce(new.snapshot,'{}'::jsonb),'{invoiceNo}',to_jsonb(generated_no),true);
 return new;
end $$;

drop trigger if exists customer_invoice_quote_linked_number on public.customer_invoices;
create trigger customer_invoice_quote_linked_number
before insert on public.customer_invoices
for each row execute function public.force_quote_linked_bill_number();

create or replace function public.save_manual_invoice(p_invoice jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 invoice_id uuid:=coalesce(nullif(p_invoice->>'id','')::uuid,gen_random_uuid());
 generated_no text;
 invoice_date_value date:=nullif(p_invoice->>'invoiceDate','')::date;
 clean_snapshot jsonb;
begin
 if public.current_role()<>'admin' then raise exception 'Only Admin can create a manual invoice'; end if;
 if invoice_date_value is null then raise exception 'Invoice date is required'; end if;
 if nullif(trim(p_invoice->>'legacyQuoteNo'),'') is null then raise exception 'Old quotation number is required'; end if;
 if nullif(trim(p_invoice->>'customerName'),'') is null then raise exception 'Customer name is required'; end if;
 if nullif(trim(p_invoice->>'district'),'') is null then raise exception 'District is required'; end if;
 if coalesce((p_invoice->>'capacityKw')::numeric,0)<=0 then raise exception 'Capacity must be greater than zero'; end if;
 if coalesce((p_invoice->>'grandTotal')::numeric,0)<=0 then raise exception 'Invoice total must be greater than zero'; end if;
 if jsonb_typeof(p_invoice->'snapshot')<>'object' then raise exception 'Printable invoice snapshot is required'; end if;

 generated_no:=public.linked_bill_number(p_invoice->>'legacyQuoteNo',invoice_date_value);
 if exists(select 1 from public.customer_invoices where invoice_no=generated_no)
    or exists(select 1 from public.manual_invoices where invoice_no=generated_no) then
  raise exception 'Bill number % already exists',generated_no;
 end if;
 clean_snapshot:=jsonb_set(p_invoice->'snapshot','{invoice,invoiceNo}',to_jsonb(generated_no),true);

 insert into public.manual_invoices(
  id,invoice_no,legacy_quote_no,invoice_date,customer_name,mobile,district_name,consumer_number,
  capacity_kw,grand_total,status,snapshot,created_by
 ) values(
  invoice_id,generated_no,trim(p_invoice->>'legacyQuoteNo'),invoice_date_value,trim(p_invoice->>'customerName'),
  nullif(trim(p_invoice->>'mobile'),''),trim(p_invoice->>'district'),nullif(trim(p_invoice->>'consumerNumber'),''),
  (p_invoice->>'capacityKw')::numeric,(p_invoice->>'grandTotal')::numeric,'issued',clean_snapshot,auth.uid()
 );
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values(auth.uid(),'manual_invoice_issued','manual_invoice',invoice_id,jsonb_build_object('invoiceNo',generated_no,'legacyQuoteNo',p_invoice->>'legacyQuoteNo','grandTotal',p_invoice->>'grandTotal'));
 return invoice_id;
end $$;

create or replace function public.cancel_manual_invoice(p_invoice_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare
 target public.manual_invoices%rowtype;
begin
 if public.current_role()<>'admin' then raise exception 'Only Admin can cancel a manual invoice'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Cancellation reason is required'; end if;
 select * into target from public.manual_invoices where id=p_invoice_id for update;
 if target.id is null then raise exception 'Manual invoice not found'; end if;
 if target.status='cancelled' then return; end if;
 update public.manual_invoices set status='cancelled',cancelled_at=now(),cancellation_reason=trim(p_reason) where id=p_invoice_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,metadata)
 values(auth.uid(),'manual_invoice_cancelled','manual_invoice',p_invoice_id,trim(p_reason),jsonb_build_object('invoiceNo',target.invoice_no));
end $$;

grant execute on function public.linked_bill_number(text,date) to authenticated;
grant execute on function public.save_manual_invoice(jsonb) to authenticated;
grant execute on function public.cancel_manual_invoice(uuid,text) to authenticated;

commit;
