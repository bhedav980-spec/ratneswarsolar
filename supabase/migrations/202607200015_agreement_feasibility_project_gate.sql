begin;

create table if not exists public.feasibility_reports (
 id uuid primary key default gen_random_uuid(),
 quotation_id uuid not null unique references public.quotations(id),
 customer_id uuid not null references public.customers(id),
 agreement_id uuid not null unique references public.agreements(id),
 project_id uuid unique references public.projects(id) on delete set null,
 report_date date not null,
 application_reference_number text not null check(nullif(trim(application_reference_number),'') is not null),
 jan_samarth_id text,
 discom_id text,
 applied_capacity_kw numeric(10,3) not null,
 actual_capacity_kw numeric(10,3) not null,
 project_cost numeric(14,2) not null,
 snapshot jsonb not null,
 generated_by uuid not null references public.profiles(id),
 generated_at timestamptz not null default now()
);

create index if not exists feasibility_customer_idx on public.feasibility_reports(customer_id);
alter table public.feasibility_reports enable row level security;
drop policy if exists feasibility_reports_read on public.feasibility_reports;
create policy feasibility_reports_read on public.feasibility_reports for select to authenticated
 using(public.current_role() in('admin','district_partner') and public.can_access_customer(customer_id));
grant select on public.feasibility_reports to authenticated;

update storage.buckets
 set allowed_mime_types=array['application/pdf','image/jpeg','image/png','application/vnd.openxmlformats-officedocument.wordprocessingml.document']
 where id='agreement-files';

create or replace function public.save_agreement_document(p_quotation_id uuid,p_generated_file_path text) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 q quotations%rowtype; v quotation_versions%rowtype; a agreements%rowtype;
 aid uuid:=gen_random_uuid(); agreement_day date;
begin
 if public.current_role() not in('admin','district_partner') then raise exception 'Not authorised'; end if;
 if nullif(trim(p_generated_file_path),'') is null then raise exception 'Generated agreement DOCX is required'; end if;
 select * into q from quotations where id=p_quotation_id and deleted_at is null for update;
 if q.id is null or not public.can_access_customer(q.customer_id) then raise exception 'Accessible quotation required'; end if;
 if q.current_status<>'approved' then raise exception 'Approve the quotation before generating the agreement'; end if;
 if exists(select 1 from projects where quotation_id=q.id) then raise exception 'A project already exists for this quotation'; end if;
 select * into v from quotation_versions where quotation_id=q.id and version_no=q.current_version;
 if v.id is null then raise exception 'Current quotation version is missing'; end if;
 agreement_day:=(q.created_at at time zone 'Asia/Kolkata')::date;
 select * into a from agreements where quotation_id=q.id for update;
 if a.id is null then
  insert into agreements(id,agreement_no,customer_id,quotation_id,agreement_date,status,capacity_kw,gross_price,signature_path,generated_file_path,snapshot,generated_by)
  values(aid,public.next_document_number('agreement','AG'),q.customer_id,q.id,agreement_day,'generated',v.dc_capacity_kw,v.final_price,null,p_generated_file_path,v.immutable_snapshot,auth.uid());
 else
  aid:=a.id;
  update agreements set agreement_date=agreement_day,status='generated',capacity_kw=v.dc_capacity_kw,gross_price=v.final_price,
   signature_path=null,generated_file_path=p_generated_file_path,snapshot=v.immutable_snapshot,generated_by=auth.uid()
  where id=aid;
 end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values(auth.uid(),'agreement_docx_generated','agreement',aid,jsonb_build_object('quotationId',q.id,'filePath',p_generated_file_path,'quoteDate',agreement_day));
 return aid;
end $$;
revoke all on function public.save_agreement_document(uuid,text) from public,anon;
grant execute on function public.save_agreement_document(uuid,text) to authenticated;

create or replace function public.save_feasibility_and_create_project(p_quotation_id uuid,p_data jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 q quotations%rowtype; v quotation_versions%rowtype; a agreements%rowtype;
 fid uuid:=gen_random_uuid(); pid uuid; report_day date; application_ref text;
begin
 if public.current_role() not in('admin','district_partner') then raise exception 'Not authorised'; end if;
 application_ref:=nullif(trim(p_data->>'applicationReferenceNumber'),'');
 if application_ref is null then raise exception 'Application Reference Number is required'; end if;
 select * into q from quotations where id=p_quotation_id and deleted_at is null for update;
 if q.id is null or not public.can_access_customer(q.customer_id) then raise exception 'Accessible quotation required'; end if;
 if q.current_status<>'approved' then raise exception 'An approved quotation is required'; end if;
 if exists(select 1 from projects where quotation_id=q.id) then raise exception 'A project already exists for this quotation'; end if;
 select * into a from agreements where quotation_id=q.id and status='generated' for update;
 if a.id is null then raise exception 'Generate the editable agreement DOCX first'; end if;
 select * into v from quotation_versions where quotation_id=q.id and version_no=q.current_version;
 if v.id is null then raise exception 'Current quotation version is missing'; end if;
 report_day:=(q.created_at at time zone 'Asia/Kolkata')::date;
 insert into feasibility_reports(id,quotation_id,customer_id,agreement_id,report_date,application_reference_number,jan_samarth_id,discom_id,applied_capacity_kw,actual_capacity_kw,project_cost,snapshot,generated_by)
 values(fid,q.id,q.customer_id,a.id,report_day,application_ref,nullif(trim(p_data->>'janSamarthId'),''),nullif(trim(p_data->>'discomId'),''),v.dc_capacity_kw,v.dc_capacity_kw,v.final_price,
  jsonb_build_object('quotationId',q.id,'customerId',q.customer_id,'agreementId',a.id,'reportDate',report_day,'applicationReferenceNumber',application_ref,
   'janSamarthId',coalesce(nullif(trim(p_data->>'janSamarthId'),''),'__'),'discomId',coalesce(nullif(trim(p_data->>'discomId'),''),'__'),
   'appliedCapacityKw',v.dc_capacity_kw,'actualCapacityKw',v.dc_capacity_kw,'projectCost',v.final_price,'panelBrand',v.panel_brand),auth.uid());

 pid:=public.approve_quotation_and_create_project(q.id);
 update projects set agreement_id=a.id where id=pid;
 update agreements set project_id=pid where id=a.id;
 update feasibility_reports set project_id=pid where id=fid;
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values(auth.uid(),'feasibility_generated_project_created','project',pid,jsonb_build_object('quotationId',q.id,'agreementId',a.id,'feasibilityId',fid));
 return pid;
end $$;
revoke all on function public.save_feasibility_and_create_project(uuid,jsonb) from public,anon;
grant execute on function public.save_feasibility_and_create_project(uuid,jsonb) to authenticated;

-- Direct quotation-to-project conversion is intentionally closed. The secured feasibility
-- function above is now the only authenticated route that may call it.
revoke all on function public.approve_quotation_and_create_project(uuid) from public,anon,authenticated;
revoke all on function public.generate_agreement_and_project(uuid,text,text,date) from public,anon,authenticated;

commit;
