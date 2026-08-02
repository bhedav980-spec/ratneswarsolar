begin;

-- Status actions can be repeated by a double-click, a slow-network retry or a
-- stale browser tab. Returning successfully when the quotation already has the
-- requested status keeps the operation idempotent without relaxing the valid
-- workflow transitions below.
create or replace function public.set_quotation_status(
  p_quotation_id uuid,
  p_status public.quote_status,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  q public.quotations%rowtype;
  old public.quote_status;
  actor_role public.app_role := public.current_role();
begin
  select *
  into q
  from public.quotations
  where id = p_quotation_id
    and deleted_at is null
  for update;

  if q.id is null then
    raise exception 'Quotation not found';
  end if;

  if not public.can_access_customer(q.customer_id) then
    raise exception 'Not authorised';
  end if;

  old := q.current_status;

  if old = p_status then
    return;
  end if;

  if actor_role = 'dealer'
    and not (old = 'draft' and p_status = 'sent')
  then
    raise exception 'Dealer can only send a draft quotation';
  end if;

  if actor_role in ('admin', 'district_partner')
    and not (
      (old = 'draft' and p_status in ('sent', 'rejected'))
      or (old in ('sent', 'pending') and p_status in ('pending', 'approved', 'rejected'))
    )
  then
    raise exception 'Invalid quotation status transition';
  end if;

  if p_status = 'rejected' and nullif(trim(p_reason), '') is null then
    raise exception 'Rejection reason is required';
  end if;

  update public.quotations
  set current_status = p_status,
      updated_by = auth.uid(),
      updated_at = now(),
      sent_at = case when p_status = 'sent' then now() else sent_at end,
      approved_at = case when p_status = 'approved' then now() else approved_at end,
      rejected_at = case when p_status = 'rejected' then now() else rejected_at end
  where id = p_quotation_id;

  insert into public.quotation_status_history(
    quotation_id, from_status, to_status, reason, changed_by
  ) values (
    p_quotation_id, old, p_status, p_reason, auth.uid()
  );

  insert into public.audit_logs(
    actor_id, action, entity_type, entity_id, reason, metadata
  ) values (
    auth.uid(), 'quotation_status_changed', 'quotation', p_quotation_id,
    p_reason, jsonb_build_object('from', old, 'to', p_status)
  );
end
$$;

revoke all on function public.set_quotation_status(uuid, public.quote_status, text) from public, anon;
grant execute on function public.set_quotation_status(uuid, public.quote_status, text) to authenticated;

commit;
