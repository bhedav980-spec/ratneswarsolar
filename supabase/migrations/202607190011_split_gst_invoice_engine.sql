begin;

alter table public.tax_rules add column if not exists supply_gst_rate numeric(7,3);
alter table public.tax_rules add column if not exists installation_gst_rate numeric(7,3);
alter table public.tax_rules add column if not exists supply_share_percent numeric(7,3) not null default 70;
alter table public.tax_rules add column if not exists installation_share_percent numeric(7,3) not null default 30;
alter table public.tax_rules add column if not exists supply_hsn text not null default '854140';
alter table public.tax_rules add column if not exists installation_sac text not null default '995442';

update public.tax_rules
set supply_gst_rate=coalesce(supply_gst_rate,gst_rate),
    installation_gst_rate=coalesce(installation_gst_rate,gst_rate)
where supply_gst_rate is null or installation_gst_rate is null;

alter table public.tax_rules alter column supply_gst_rate set not null;
alter table public.tax_rules alter column installation_gst_rate set not null;

do $$
begin
 if not exists(select 1 from pg_constraint where conname='tax_rules_split_share_check') then
  alter table public.tax_rules add constraint tax_rules_split_share_check check(
   supply_share_percent>=0 and installation_share_percent>=0 and
   round(supply_share_percent+installation_share_percent,3)=100
  );
 end if;
 if not exists(select 1 from pg_constraint where conname='tax_rules_split_rate_check') then
  alter table public.tax_rules add constraint tax_rules_split_rate_check check(supply_gst_rate>=0 and installation_gst_rate>=0);
 end if;
end $$;

alter table public.customer_invoice_items add column if not exists line_type text;
alter table public.customer_invoice_items add column if not exists share_percent numeric(7,3) not null default 100;
alter table public.customer_invoice_items add column if not exists gross_value numeric(14,2) not null default 0;
alter table public.customer_invoice_items add column if not exists cgst numeric(14,2) not null default 0;
alter table public.customer_invoice_items add column if not exists sgst numeric(14,2) not null default 0;
alter table public.customer_invoice_items add column if not exists igst numeric(14,2) not null default 0;

drop policy if exists tax_admin_write on public.tax_rules;
drop policy if exists tax_admin_manage on public.tax_rules;
create policy tax_admin_manage on public.tax_rules for all to authenticated using(public.is_admin()) with check(public.is_admin());
grant select,insert,update on public.tax_rules to authenticated;

create or replace function public.save_installation_and_issue_invoice(p_project_id uuid,p_details jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 p projects%rowtype; q jsonb; expected int; serial_count int; duplicate_count int; tr tax_rules%rowtype;
 gross numeric; supply_gross numeric; install_gross numeric; supply_taxable numeric; install_taxable numeric;
 supply_tax numeric; install_tax numeric; supply_cgst numeric:=0; supply_sgst numeric:=0; supply_igst numeric:=0;
 install_cgst numeric:=0; install_sgst numeric:=0; install_igst numeric:=0;
 taxable numeric; cgst_total numeric; sgst_total numeric; igst_total numeric; tax_lines jsonb:='[]'::jsonb;
 inv_id uuid:=gen_random_uuid(); inv_no text; inv_date date:=coalesce(nullif(p_details->>'invoiceDate','')::date,current_date);
 place_ text:=coalesce(nullif(trim(p_details->>'placeOfSupply'),''),'Gujarat (24)'); serial text; panel_item uuid;
begin
 select * into p from projects where id=p_project_id for update;
 if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if;
 if not (p.current_stage = any(array['installation_done','inspection_pending','inspection_done','meter_pending','meter_done','commissioning_done','subsidy_pending','subsidy_passed','handover_completed','project_closed']::project_stage[])) then raise exception 'Invoice is available only after Project Installation Done'; end if;
 if exists(select 1 from customer_invoices where project_id=p.id and status in('issued','paid')) then raise exception 'An active invoice already exists'; end if;
 q:=p.accepted_quotation_snapshot; expected:=(q->>'panelQuantity')::int; serial_count:=jsonb_array_length(coalesce(p_details->'panelSerials','[]'));
 if serial_count<1 then raise exception 'Panel serial numbers are required'; end if;
 select count(*)-count(distinct value) into duplicate_count from jsonb_array_elements_text(p_details->'panelSerials');
 if duplicate_count>0 then raise exception 'Duplicate panel serial numbers are not allowed'; end if;
 if (serial_count<>expected or p_details->>'panelBrand'<>q->>'panelBrand' or (p_details->>'panelWattage')::int<>(q->>'panelWattage')::int) and nullif(trim(p_details->>'overrideReason'),'') is null then raise exception 'Material change reason is required'; end if;

 select inventory_item_id into panel_item from project_material_requirements where project_id=p.id and item_code like 'PV-%' limit 1;
 if panel_item is null then
  insert into inventory_items(item_code,item_name,category,brand,model,specification,unit,district_id,serialized,reorder_level,created_by)
  values(format('PV-%s-%s',p_details->>'panelBrand',p_details->>'panelWattage'),format('%s %s Solar Panel',p_details->>'panelBrand',p_details->>'panelTechnology'),'PV Module',p_details->>'panelBrand',p_details->>'panelTechnology',format('%s Wp',p_details->>'panelWattage'),'Nos',p.district_id,true,0,auth.uid())
  on conflict(item_code) do update set item_name=excluded.item_name returning id into panel_item;
  update project_material_requirements set inventory_item_id=panel_item where project_id=p.id and item_code like 'PV-%';
 end if;
 for serial in select jsonb_array_elements_text(p_details->'panelSerials') loop
  if nullif(trim(serial),'') is null then raise exception 'Panel serial numbers cannot be blank'; end if;
  if exists(select 1 from inventory_serials where serial_number=serial) then raise exception 'Installed serial number % already exists',serial; end if;
  insert into inventory_serials(inventory_item_id,serial_number,status,project_id) values(panel_item,serial,'installed',p.id);
 end loop;
 insert into installation_materials(project_id,details,created_by) values(p.id,p_details,auth.uid());

 select * into tr from tax_rules where active and effective_from<=inv_date and (effective_to is null or effective_to>=inv_date) order by effective_from desc,created_at desc limit 1;
 if tr.id is null then raise exception 'No active effective-dated split GST rule exists'; end if;
 if round(tr.supply_share_percent+tr.installation_share_percent,3)<>100 then raise exception 'Supply and installation shares must total exactly 100 percent'; end if;

 gross:=(q->>'grandTotal')::numeric;
 supply_gross:=round(gross*tr.supply_share_percent/100,2); install_gross:=gross-supply_gross;
 supply_taxable:=case when tr.supply_gst_rate>0 then round(supply_gross*100/(100+tr.supply_gst_rate),2) else supply_gross end;
 install_taxable:=case when tr.installation_gst_rate>0 then round(install_gross*100/(100+tr.installation_gst_rate),2) else install_gross end;
 supply_tax:=supply_gross-supply_taxable; install_tax:=install_gross-install_taxable;
 if tr.intrastate then
  supply_cgst:=round(supply_tax/2,2); supply_sgst:=supply_tax-supply_cgst;
  install_cgst:=round(install_tax/2,2); install_sgst:=install_tax-install_cgst;
 else supply_igst:=supply_tax; install_igst:=install_tax; end if;
 taxable:=supply_taxable+install_taxable; cgst_total:=supply_cgst+install_cgst; sgst_total:=supply_sgst+install_sgst; igst_total:=supply_igst+install_igst;

 if tr.supply_share_percent>0 then tax_lines:=tax_lines||jsonb_build_array(jsonb_build_object('lineType','supply','description','Solar Power Generation System - Supply','hsnSac',tr.supply_hsn,'sharePercent',tr.supply_share_percent,'gstRate',tr.supply_gst_rate,'grossAmount',supply_gross,'taxableValue',supply_taxable,'cgst',supply_cgst,'sgst',supply_sgst,'igst',supply_igst)); end if;
 if tr.installation_share_percent>0 then tax_lines:=tax_lines||jsonb_build_array(jsonb_build_object('lineType','installation','description','Installation and Commissioning of Solar Power System','hsnSac',tr.installation_sac,'sharePercent',tr.installation_share_percent,'gstRate',tr.installation_gst_rate,'grossAmount',install_gross,'taxableValue',install_taxable,'cgst',install_cgst,'sgst',install_sgst,'igst',install_igst)); end if;

 inv_no:=coalesce(nullif(trim(p_details->>'invoiceNo'),''),next_document_number('invoice','INV'));
 if exists(select 1 from customer_invoices where invoice_no=inv_no) then raise exception 'Invoice number already exists'; end if;
 insert into customer_invoices(id,invoice_no,customer_id,project_id,invoice_date,place_of_supply,status,tax_rule_id,taxable_value,cgst,sgst,igst,grand_total,snapshot,issued_by)
 values(inv_id,inv_no,p.customer_id,p.id,inv_date,place_,'issued',tr.id,taxable,cgst_total,sgst_total,igst_total,gross,
  jsonb_build_object('id',inv_id,'invoiceNo',inv_no,'customerId',p.customer_id,'projectId',p.id,'invoiceDate',inv_date,'placeOfSupply',place_,'status','issued','taxMode','inclusive','taxRuleName',tr.name,'taxLines',tax_lines,'taxableValue',taxable,'cgst',cgst_total,'sgst',sgst_total,'igst',igst_total,'roundOff',0,'grandTotal',gross),auth.uid());
 if tr.supply_share_percent>0 then
  insert into customer_invoice_items(invoice_id,line_type,description,hsn_sac,quantity,unit,share_percent,gross_value,taxable_value,tax_rate,cgst,sgst,igst,serial_numbers)
  values(inv_id,'supply',format('Solar Power Generation System - %s kWp',q->>'dcCapacityKw'),tr.supply_hsn,1,'Job',tr.supply_share_percent,supply_gross,supply_taxable,tr.supply_gst_rate,supply_cgst,supply_sgst,supply_igst,array(select jsonb_array_elements_text(p_details->'panelSerials')));
 end if;
 if tr.installation_share_percent>0 then
  insert into customer_invoice_items(invoice_id,line_type,description,hsn_sac,quantity,unit,share_percent,gross_value,taxable_value,tax_rate,cgst,sgst,igst)
  values(inv_id,'installation',format('Installation and Commissioning of %s kWp Solar Power System',q->>'dcCapacityKw'),tr.installation_sac,1,'Job',tr.installation_share_percent,install_gross,install_taxable,tr.installation_gst_rate,install_cgst,install_sgst,install_igst);
 end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata)
 values(auth.uid(),'customer_invoice_issued','customer_invoice',inv_id,p_details->>'overrideReason',jsonb_build_object('projectId',p.id,'invoiceNo',inv_no,'gross',gross,'serialCount',serial_count,'taxRuleId',tr.id,'taxLines',tax_lines));
 return inv_id;
end $$;

grant execute on function public.save_installation_and_issue_invoice(uuid,jsonb) to authenticated;

commit;
