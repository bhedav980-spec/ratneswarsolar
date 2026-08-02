begin;

-- A deliberately deleted/reset project leaves its quotation Approved while the
-- quotation-linked feasibility report remains for audit. Editing that existing
-- report must recreate the missing project instead of only updating the PDF
-- fields or attempting to insert a duplicate feasibility row.
create or replace function public.update_feasibility_report(
  p_quotation_id uuid,
  p_data jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  q public.quotations%rowtype;
  v public.quotation_versions%rowtype;
  c public.customers%rowtype;
  f public.feasibility_reports%rowtype;
  pid uuid;
  application_ref text;
  applicant text;
  consumer text;
  premises text;
  report_district text;
  report_state text;
  report_pin text;
  oem text;
  applied_capacity numeric(10,3);
  actual_capacity numeric(10,3);
  report_cost numeric(14,2);
begin
  if public.current_role() not in ('admin', 'district_partner') then
    raise exception 'Not authorised';
  end if;

  application_ref := nullif(trim(p_data->>'applicationReferenceNumber'), '');
  if application_ref is null then
    raise exception 'Application Reference Number is required';
  end if;

  select * into q
  from public.quotations
  where id = p_quotation_id
    and deleted_at is null
  for update;

  if q.id is null then
    raise exception 'Quotation not found';
  end if;

  select * into f
  from public.feasibility_reports
  where quotation_id = q.id
  for update;

  if f.id is null then
    raise exception 'Feasibility Report not found';
  end if;

  if not public.can_access_customer(q.customer_id)
    and (f.project_id is null or not public.can_access_project(f.project_id))
  then
    raise exception 'Not authorised for this report';
  end if;

  select * into v
  from public.quotation_versions
  where quotation_id = q.id
    and version_no = q.current_version;

  select * into c
  from public.customers
  where id = q.customer_id;

  if v.id is null or c.id is null then
    raise exception 'Quotation version or customer is missing';
  end if;

  applicant := coalesce(nullif(trim(p_data->>'applicantName'), ''), f.applicant_name, c.full_name);
  consumer := coalesce(nullif(trim(p_data->>'consumerNumber'), ''), f.consumer_number, c.consumer_number);
  premises := coalesce(
    nullif(trim(p_data->>'installationAddress'), ''),
    f.installation_address,
    concat_ws(', ', nullif(c.full_address, ''), nullif(c.village_city, ''), nullif(c.taluka, ''), nullif(c.district_name, ''), nullif(c.state, ''), nullif(c.pin_code, ''))
  );
  report_district := coalesce(nullif(trim(p_data->>'districtName'), ''), f.district_name, c.district_name);
  report_state := coalesce(nullif(trim(p_data->>'stateName'), ''), f.state_name, c.state, 'Gujarat');
  report_pin := coalesce(nullif(trim(p_data->>'pinCode'), ''), f.pin_code, c.pin_code);
  oem := coalesce(nullif(trim(p_data->>'oemName'), ''), f.oem_name, v.panel_brand);
  applied_capacity := coalesce(nullif(p_data->>'appliedCapacityKw', '')::numeric, f.applied_capacity_kw, v.dc_capacity_kw);
  actual_capacity := coalesce(nullif(p_data->>'actualCapacityKw', '')::numeric, f.actual_capacity_kw, v.dc_capacity_kw);
  report_cost := coalesce(nullif(p_data->>'projectCost', '')::numeric, f.project_cost, v.final_price);

  if applied_capacity < 0 or actual_capacity < 0 or report_cost < 0 then
    raise exception 'Capacity and project cost cannot be negative';
  end if;

  update public.feasibility_reports
  set application_reference_number = application_ref,
      jan_samarth_id = nullif(trim(p_data->>'janSamarthId'), ''),
      discom_id = nullif(trim(p_data->>'discomId'), ''),
      applicant_name = applicant,
      consumer_number = consumer,
      installation_address = premises,
      district_name = report_district,
      state_name = report_state,
      pin_code = report_pin,
      oem_name = oem,
      applied_capacity_kw = applied_capacity,
      actual_capacity_kw = actual_capacity,
      project_cost = report_cost,
      snapshot = coalesce(f.snapshot, '{}'::jsonb) || jsonb_build_object(
        'applicationReferenceNumber', application_ref,
        'janSamarthId', coalesce(nullif(trim(p_data->>'janSamarthId'), ''), '__'),
        'discomId', coalesce(nullif(trim(p_data->>'discomId'), ''), '__'),
        'applicantName', applicant,
        'consumerNumber', coalesce(consumer, '__'),
        'installationAddress', premises,
        'districtName', report_district,
        'stateName', report_state,
        'pinCode', coalesce(report_pin, '__'),
        'oemName', oem,
        'appliedCapacityKw', applied_capacity,
        'actualCapacityKw', actual_capacity,
        'projectCost', report_cost
      ),
      generated_by = auth.uid(),
      generated_at = now()
  where id = f.id;

  select id into pid
  from public.projects
  where quotation_id = q.id
  for update;

  if pid is null then
    if q.current_status <> 'approved' then
      raise exception 'An approved quotation is required to create the missing project';
    end if;

    pid := public.approve_quotation_and_create_project(q.id);

    update public.projects
    set agreement_id = f.agreement_id
    where id = pid;

    update public.agreements
    set project_id = pid
    where id = f.agreement_id;

    update public.feasibility_reports
    set project_id = pid
    where id = f.id;

    insert into public.audit_logs(
      actor_id, action, entity_type, entity_id, metadata
    ) values (
      auth.uid(), 'feasibility_updated_project_recovered', 'project', pid,
      jsonb_build_object('quotationId', q.id, 'agreementId', f.agreement_id, 'feasibilityId', f.id)
    );
  else
    update public.projects
    set agreement_id = coalesce(agreement_id, f.agreement_id)
    where id = pid;

    update public.agreements
    set project_id = pid
    where id = f.agreement_id
      and project_id is distinct from pid;

    update public.feasibility_reports
    set project_id = pid
    where id = f.id
      and project_id is distinct from pid;

    insert into public.audit_logs(
      actor_id, action, entity_type, entity_id, metadata
    ) values (
      auth.uid(), 'feasibility_report_updated', 'feasibility_report', f.id,
      jsonb_build_object('quotationId', q.id, 'projectId', pid)
    );
  end if;

  return f.id;
end
$$;

revoke all on function public.update_feasibility_report(uuid, jsonb) from public, anon;
grant execute on function public.update_feasibility_report(uuid, jsonb) to authenticated;

commit;
