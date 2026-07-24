begin;

-- Keep the original project_stage enum and detailed history intact for existing
-- projects. The application now exposes six practical business stages through
-- this secured grouped transition function.
create or replace function public.change_project_stage_grouped(
  p_project_id uuid,
  p_group text,
  p_note text default null,
  p_override_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  p public.projects%rowtype;
  current_group text;
  target_stage public.project_stage;
  valid_transition boolean := false;
begin
  select *
  into p
  from public.projects
  where id = p_project_id
  for update;

  if p.id is null
    or not public.can_access_project(p.id)
    or public.current_role() = 'dealer'
  then
    raise exception 'Not authorised';
  end if;

  if nullif(trim(p_note), '') is null then
    raise exception 'Stage note is required';
  end if;

  current_group := case
    when p.current_stage in (
      'project_created', 'planning_done',
      'documentation_pending', 'documentation_completed'
    ) then 'quotation_documentation'
    when p.current_stage in (
      'loan_required', 'loan_application_pending', 'loan_applied',
      'loan_sanctioned', 'loan_rejected'
    ) then 'loan_progress'
    when p.current_stage in (
      'loan_not_required', 'material_requirement_generated',
      'material_reserved', 'material_dispatched'
    ) then 'material_dispatch'
    when p.current_stage in (
      'installation_in_progress', 'installation_done'
    ) then 'installation'
    when p.current_stage in (
      'inspection_pending', 'inspection_done', 'meter_pending', 'meter_done',
      'commissioning_done', 'subsidy_pending', 'subsidy_passed',
      'handover_completed'
    ) then 'inspection_meter'
    when p.current_stage = 'project_closed' then 'completed'
  end;

  target_stage := case p_group
    when 'quotation_documentation' then 'documentation_pending'::public.project_stage
    when 'loan_progress' then 'loan_application_pending'::public.project_stage
    when 'material_dispatch' then 'material_dispatched'::public.project_stage
    when 'installation' then 'installation_done'::public.project_stage
    when 'inspection_meter' then 'inspection_pending'::public.project_stage
    when 'completed' then 'project_closed'::public.project_stage
    else null
  end;

  if target_stage is null then
    raise exception 'Unknown project stage';
  end if;

  valid_transition := case current_group
    when 'quotation_documentation' then p_group in ('loan_progress', 'material_dispatch')
    when 'loan_progress' then p_group = 'material_dispatch'
    when 'material_dispatch' then p_group = 'installation'
    when 'installation' then p_group = 'inspection_meter'
    when 'inspection_meter' then p_group = 'completed'
    else false
  end;

  if not valid_transition
    and (not public.is_admin() or nullif(trim(p_override_reason), '') is null)
  then
    raise exception 'Invalid project stage transition';
  end if;

  update public.projects
  set current_stage = target_stage,
      updated_at = now(),
      row_version = row_version + 1,
      closed_at = case when target_stage = 'project_closed' then now() else null end
  where id = p.id;

  insert into public.project_stage_history(
    project_id, from_stage, to_stage, note, override_reason, changed_by
  ) values (
    p.id, p.current_stage, target_stage, trim(p_note),
    nullif(trim(p_override_reason), ''), auth.uid()
  );

  -- The compact "Material & Dispatch" stage performs the same idempotent stock
  -- issue that the detailed workflow previously performed at material_dispatched.
  if p_group = 'material_dispatch' then
    insert into public.stock_transactions(
      inventory_item_id, transaction_type, quantity, project_id, reference_no,
      reason, idempotency_key, created_by
    )
    select
      inventory_item_id, 'issue', reserved_qty, p.id, p.project_no,
      'Reserved material dispatched',
      format('project:%s:issue:%s', p.id, id), auth.uid()
    from public.project_material_requirements
    where project_id = p.id
      and inventory_item_id is not null
      and reserved_qty > 0
      and issued_qty = 0
    on conflict (idempotency_key) do nothing;

    update public.project_material_requirements
    set issued_qty = reserved_qty
    where project_id = p.id
      and reserved_qty > 0
      and issued_qty = 0;
  end if;

  insert into public.audit_logs(
    actor_id, action, entity_type, entity_id, reason, metadata
  ) values (
    auth.uid(), 'project_stage_group_changed', 'project', p.id,
    nullif(trim(p_override_reason), ''),
    jsonb_build_object(
      'fromStage', p.current_stage,
      'fromGroup', current_group,
      'toStage', target_stage,
      'toGroup', p_group,
      'note', trim(p_note)
    )
  );
end
$$;

revoke all on function public.change_project_stage_grouped(uuid, text, text, text) from public;
grant execute on function public.change_project_stage_grouped(uuid, text, text, text) to authenticated;

commit;
