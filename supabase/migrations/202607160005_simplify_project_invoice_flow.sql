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
