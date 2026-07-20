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
