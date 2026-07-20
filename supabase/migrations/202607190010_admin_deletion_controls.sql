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
