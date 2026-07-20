begin;

alter table public.customer_invoices add column if not exists quoted_amount numeric(14,2);
alter table public.customer_invoices add column if not exists tax_treatment text;
update public.customer_invoices
set quoted_amount=coalesce(quoted_amount,grand_total),
    tax_treatment=coalesce(tax_treatment,'inclusive')
where quoted_amount is null or tax_treatment is null;
alter table public.customer_invoices alter column quoted_amount set default 0;
alter table public.customer_invoices alter column quoted_amount set not null;
alter table public.customer_invoices alter column tax_treatment set default 'inclusive';
alter table public.customer_invoices alter column tax_treatment set not null;

do $$
begin
 if not exists(select 1 from pg_constraint where conname='customer_invoices_tax_treatment_check') then
  alter table public.customer_invoices add constraint customer_invoices_tax_treatment_check
  check(tax_treatment in('inclusive','exclusive'));
 end if;
end $$;

insert into public.tax_rules(
 name,effective_from,gst_rate,intrastate,active,supply_gst_rate,installation_gst_rate,
 supply_share_percent,installation_share_percent,supply_hsn,installation_sac
)
select 'Solar EPC 70/30 - Supply 5% / Installation 18%',date '2026-07-20',5,true,true,5,18,70,30,'854140','995442'
where not exists(
 select 1 from public.tax_rules
 where name='Solar EPC 70/30 - Supply 5% / Installation 18%' and effective_from=date '2026-07-20'
);

create or replace function public.save_installation_and_issue_invoice(p_project_id uuid,p_details jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 p projects%rowtype; q jsonb; expected int; serial_count int; duplicate_count int; tr tax_rules%rowtype;
 quote_amount numeric; tax_treatment text; gross numeric; supply_amount numeric; install_amount numeric;
 supply_gross numeric; install_gross numeric; supply_taxable numeric; install_taxable numeric;
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
 tax_treatment:=coalesce(nullif(p_details->>'taxTreatment',''),'inclusive');
 if tax_treatment not in('inclusive','exclusive') then raise exception 'Invoice GST treatment must be inclusive or exclusive'; end if;
 quote_amount:=(q->>'grandTotal')::numeric;
 supply_amount:=round(quote_amount*tr.supply_share_percent/100,2); install_amount:=quote_amount-supply_amount;

 if tax_treatment='inclusive' then
  supply_gross:=supply_amount; install_gross:=install_amount;
  supply_taxable:=case when tr.supply_gst_rate>0 then round(supply_gross*100/(100+tr.supply_gst_rate),2) else supply_gross end;
  install_taxable:=case when tr.installation_gst_rate>0 then round(install_gross*100/(100+tr.installation_gst_rate),2) else install_gross end;
  supply_tax:=supply_gross-supply_taxable; install_tax:=install_gross-install_taxable;
 else
  supply_taxable:=supply_amount; install_taxable:=install_amount;
  supply_tax:=round(supply_taxable*tr.supply_gst_rate/100,2); install_tax:=round(install_taxable*tr.installation_gst_rate/100,2);
  supply_gross:=supply_taxable+supply_tax; install_gross:=install_taxable+install_tax;
 end if;

 if tr.intrastate then
  supply_cgst:=round(supply_tax/2,2); supply_sgst:=supply_tax-supply_cgst;
  install_cgst:=round(install_tax/2,2); install_sgst:=install_tax-install_cgst;
 else supply_igst:=supply_tax; install_igst:=install_tax; end if;
 taxable:=supply_taxable+install_taxable; cgst_total:=supply_cgst+install_cgst; sgst_total:=supply_sgst+install_sgst; igst_total:=supply_igst+install_igst;
 gross:=supply_gross+install_gross;

 if tr.supply_share_percent>0 then tax_lines:=tax_lines||jsonb_build_array(jsonb_build_object('lineType','supply','description','Solar Power Generation System - Supply','hsnSac',tr.supply_hsn,'sharePercent',tr.supply_share_percent,'gstRate',tr.supply_gst_rate,'grossAmount',supply_gross,'taxableValue',supply_taxable,'cgst',supply_cgst,'sgst',supply_sgst,'igst',supply_igst)); end if;
 if tr.installation_share_percent>0 then tax_lines:=tax_lines||jsonb_build_array(jsonb_build_object('lineType','installation','description','Installation and Commissioning of Solar Power System','hsnSac',tr.installation_sac,'sharePercent',tr.installation_share_percent,'gstRate',tr.installation_gst_rate,'grossAmount',install_gross,'taxableValue',install_taxable,'cgst',install_cgst,'sgst',install_sgst,'igst',install_igst)); end if;

 inv_no:=coalesce(nullif(trim(p_details->>'invoiceNo'),''),next_document_number('invoice','INV'));
 if exists(select 1 from customer_invoices where invoice_no=inv_no) then raise exception 'Invoice number already exists'; end if;
 insert into customer_invoices(id,invoice_no,customer_id,project_id,invoice_date,place_of_supply,status,tax_rule_id,quoted_amount,tax_treatment,taxable_value,cgst,sgst,igst,grand_total,snapshot,issued_by)
 values(inv_id,inv_no,p.customer_id,p.id,inv_date,place_,'issued',tr.id,quote_amount,tax_treatment,taxable,cgst_total,sgst_total,igst_total,gross,
  jsonb_build_object('id',inv_id,'invoiceNo',inv_no,'customerId',p.customer_id,'projectId',p.id,'invoiceDate',inv_date,'placeOfSupply',place_,'status','issued','taxMode',tax_treatment,'quotedAmount',quote_amount,'taxRuleName',tr.name,'taxLines',tax_lines,'taxableValue',taxable,'cgst',cgst_total,'sgst',sgst_total,'igst',igst_total,'roundOff',0,'grandTotal',gross),auth.uid());
 if tr.supply_share_percent>0 then
  insert into customer_invoice_items(invoice_id,line_type,description,hsn_sac,quantity,unit,share_percent,gross_value,taxable_value,tax_rate,cgst,sgst,igst,serial_numbers)
  values(inv_id,'supply',format('Solar Power Generation System - %s kWp',q->>'dcCapacityKw'),tr.supply_hsn,1,'Job',tr.supply_share_percent,supply_gross,supply_taxable,tr.supply_gst_rate,supply_cgst,supply_sgst,supply_igst,array(select jsonb_array_elements_text(p_details->'panelSerials')));
 end if;
 if tr.installation_share_percent>0 then
  insert into customer_invoice_items(invoice_id,line_type,description,hsn_sac,quantity,unit,share_percent,gross_value,taxable_value,tax_rate,cgst,sgst,igst)
  values(inv_id,'installation',format('Installation and Commissioning of %s kWp Solar Power System',q->>'dcCapacityKw'),tr.installation_sac,1,'Job',tr.installation_share_percent,install_gross,install_taxable,tr.installation_gst_rate,install_cgst,install_sgst,install_igst);
 end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata)
 values(auth.uid(),'customer_invoice_issued','customer_invoice',inv_id,p_details->>'overrideReason',jsonb_build_object('projectId',p.id,'invoiceNo',inv_no,'quotedAmount',quote_amount,'taxTreatment',tax_treatment,'gross',gross,'serialCount',serial_count,'taxRuleId',tr.id,'taxLines',tax_lines));
 return inv_id;
end $$;

grant execute on function public.save_installation_and_issue_invoice(uuid,jsonb) to authenticated;

commit;
