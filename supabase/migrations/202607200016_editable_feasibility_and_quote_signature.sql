begin;

alter table public.feasibility_reports
 add column if not exists applicant_name text,
 add column if not exists consumer_number text,
 add column if not exists installation_address text,
 add column if not exists district_name text,
 add column if not exists state_name text,
 add column if not exists pin_code text,
 add column if not exists oem_name text;

update public.feasibility_reports f
set applicant_name=coalesce(f.applicant_name,c.full_name),
    consumer_number=coalesce(f.consumer_number,c.consumer_number),
    installation_address=coalesce(f.installation_address,concat_ws(', ',nullif(c.full_address,''),nullif(c.village_city,''),nullif(c.taluka,''),nullif(c.district_name,''),nullif(c.state,''),nullif(c.pin_code,''))),
    district_name=coalesce(f.district_name,c.district_name),
    state_name=coalesce(f.state_name,c.state),
    pin_code=coalesce(f.pin_code,c.pin_code),
    oem_name=coalesce(f.oem_name,v.panel_brand)
from public.customers c, public.quotations q, public.quotation_versions v
where f.customer_id=c.id
  and f.quotation_id=q.id
  and v.quotation_id=q.id
  and v.version_no=q.current_version;

create or replace function public.save_feasibility_and_create_project(p_quotation_id uuid,p_data jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 q quotations%rowtype; v quotation_versions%rowtype; a agreements%rowtype; c customers%rowtype;
 fid uuid:=gen_random_uuid(); pid uuid; report_day date; application_ref text;
 applicant text; consumer text; premises text; report_district text; report_state text; report_pin text; oem text;
 applied_capacity numeric(10,3); actual_capacity numeric(10,3); report_cost numeric(14,2);
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
 select * into c from customers where id=q.customer_id;
 if c.id is null then raise exception 'Customer is missing'; end if;

 applicant:=coalesce(nullif(trim(p_data->>'applicantName'),''),c.full_name);
 consumer:=coalesce(nullif(trim(p_data->>'consumerNumber'),''),c.consumer_number);
 premises:=coalesce(nullif(trim(p_data->>'installationAddress'),''),concat_ws(', ',nullif(c.full_address,''),nullif(c.village_city,''),nullif(c.taluka,''),nullif(c.district_name,''),nullif(c.state,''),nullif(c.pin_code,'')));
 report_district:=coalesce(nullif(trim(p_data->>'districtName'),''),c.district_name);
 report_state:=coalesce(nullif(trim(p_data->>'stateName'),''),c.state,'Gujarat');
 report_pin:=coalesce(nullif(trim(p_data->>'pinCode'),''),c.pin_code);
 oem:=coalesce(nullif(trim(p_data->>'oemName'),''),v.panel_brand);
 applied_capacity:=coalesce(nullif(p_data->>'appliedCapacityKw','')::numeric,v.dc_capacity_kw);
 actual_capacity:=coalesce(nullif(p_data->>'actualCapacityKw','')::numeric,v.dc_capacity_kw);
 report_cost:=coalesce(nullif(p_data->>'projectCost','')::numeric,v.final_price);
 if applied_capacity<0 or actual_capacity<0 or report_cost<0 then raise exception 'Capacity and project cost cannot be negative'; end if;

 report_day:=(q.created_at at time zone 'Asia/Kolkata')::date;
 insert into feasibility_reports(
  id,quotation_id,customer_id,agreement_id,report_date,application_reference_number,jan_samarth_id,discom_id,
  applicant_name,consumer_number,installation_address,district_name,state_name,pin_code,oem_name,
  applied_capacity_kw,actual_capacity_kw,project_cost,snapshot,generated_by
 ) values(
  fid,q.id,q.customer_id,a.id,report_day,application_ref,nullif(trim(p_data->>'janSamarthId'),''),nullif(trim(p_data->>'discomId'),''),
  applicant,consumer,premises,report_district,report_state,report_pin,oem,applied_capacity,actual_capacity,report_cost,
  jsonb_build_object('quotationId',q.id,'customerId',q.customer_id,'agreementId',a.id,'applicationReferenceNumber',application_ref,
   'janSamarthId',coalesce(nullif(trim(p_data->>'janSamarthId'),''),'__'),'discomId',coalesce(nullif(trim(p_data->>'discomId'),''),'__'),
   'applicantName',applicant,'consumerNumber',coalesce(consumer,'__'),'installationAddress',premises,'districtName',report_district,
   'stateName',report_state,'pinCode',coalesce(report_pin,'__'),'oemName',oem,'appliedCapacityKw',applied_capacity,
   'actualCapacityKw',actual_capacity,'projectCost',report_cost),auth.uid()
 );

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

create or replace function public.update_feasibility_report(p_quotation_id uuid,p_data jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 q quotations%rowtype; v quotation_versions%rowtype; c customers%rowtype; f feasibility_reports%rowtype;
 application_ref text; applicant text; consumer text; premises text; report_district text; report_state text; report_pin text; oem text;
 applied_capacity numeric(10,3); actual_capacity numeric(10,3); report_cost numeric(14,2);
begin
 if public.current_role() not in('admin','district_partner') then raise exception 'Not authorised'; end if;
 application_ref:=nullif(trim(p_data->>'applicationReferenceNumber'),'');
 if application_ref is null then raise exception 'Application Reference Number is required'; end if;
 select * into q from quotations where id=p_quotation_id for update;
 if q.id is null then raise exception 'Quotation not found'; end if;
 select * into f from feasibility_reports where quotation_id=q.id for update;
 if f.id is null then raise exception 'Feasibility Report not found'; end if;
 if not public.can_access_customer(q.customer_id) and (f.project_id is null or not public.can_access_project(f.project_id)) then raise exception 'Not authorised for this report'; end if;
 select * into v from quotation_versions where quotation_id=q.id and version_no=q.current_version;
 select * into c from customers where id=q.customer_id;

 applicant:=coalesce(nullif(trim(p_data->>'applicantName'),''),f.applicant_name,c.full_name);
 consumer:=coalesce(nullif(trim(p_data->>'consumerNumber'),''),f.consumer_number,c.consumer_number);
 premises:=coalesce(nullif(trim(p_data->>'installationAddress'),''),f.installation_address,concat_ws(', ',nullif(c.full_address,''),nullif(c.village_city,''),nullif(c.taluka,''),nullif(c.district_name,''),nullif(c.state,''),nullif(c.pin_code,'')));
 report_district:=coalesce(nullif(trim(p_data->>'districtName'),''),f.district_name,c.district_name);
 report_state:=coalesce(nullif(trim(p_data->>'stateName'),''),f.state_name,c.state,'Gujarat');
 report_pin:=coalesce(nullif(trim(p_data->>'pinCode'),''),f.pin_code,c.pin_code);
 oem:=coalesce(nullif(trim(p_data->>'oemName'),''),f.oem_name,v.panel_brand);
 applied_capacity:=coalesce(nullif(p_data->>'appliedCapacityKw','')::numeric,f.applied_capacity_kw,v.dc_capacity_kw);
 actual_capacity:=coalesce(nullif(p_data->>'actualCapacityKw','')::numeric,f.actual_capacity_kw,v.dc_capacity_kw);
 report_cost:=coalesce(nullif(p_data->>'projectCost','')::numeric,f.project_cost,v.final_price);
 if applied_capacity<0 or actual_capacity<0 or report_cost<0 then raise exception 'Capacity and project cost cannot be negative'; end if;

 update feasibility_reports set
  application_reference_number=application_ref,jan_samarth_id=nullif(trim(p_data->>'janSamarthId'),''),discom_id=nullif(trim(p_data->>'discomId'),''),
  applicant_name=applicant,consumer_number=consumer,installation_address=premises,district_name=report_district,state_name=report_state,pin_code=report_pin,oem_name=oem,
  applied_capacity_kw=applied_capacity,actual_capacity_kw=actual_capacity,project_cost=report_cost,
  snapshot=coalesce(f.snapshot,'{}'::jsonb)||jsonb_build_object('applicationReferenceNumber',application_ref,
   'janSamarthId',coalesce(nullif(trim(p_data->>'janSamarthId'),''),'__'),'discomId',coalesce(nullif(trim(p_data->>'discomId'),''),'__'),
   'applicantName',applicant,'consumerNumber',coalesce(consumer,'__'),'installationAddress',premises,'districtName',report_district,
   'stateName',report_state,'pinCode',coalesce(report_pin,'__'),'oemName',oem,'appliedCapacityKw',applied_capacity,
   'actualCapacityKw',actual_capacity,'projectCost',report_cost),generated_by=auth.uid(),generated_at=now()
 where id=f.id;

 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values(auth.uid(),'feasibility_report_updated','feasibility_report',f.id,jsonb_build_object('quotationId',q.id,'projectId',f.project_id));
 return f.id;
end $$;
revoke all on function public.update_feasibility_report(uuid,jsonb) from public,anon;
grant execute on function public.update_feasibility_report(uuid,jsonb) to authenticated;

commit;
