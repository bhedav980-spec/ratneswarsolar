begin;

insert into public.company_settings(key,value)
values('crm.settings',jsonb_build_object(
  'company',jsonb_build_object('legalName','RATNESWAR ENGINEERING','tradeName','Ratneswar Engineering','address','Office No. 19, Sanghvi Square Complex, Salarinaka, Rapar-Kutch, Rapar, Gujarat - 370165','mobilePrimary','84010 50053','mobileSecondary','78019 56980','email','ratneswarengineering@gmail.com','gstin','24ABKFR8021K1ZZ','pan','ABKFR8021K','state','Gujarat','stateCode','24','jurisdiction','Kutch'),
  'bank',jsonb_build_object('accountHolder','RATNESWAR ENGINEERING','bankName','HDFC Bank','accountNumber','99900019052018','ifsc','HDFC0002295','branch','Rapar Branch, Kutch'),
  'quotationNumbering',jsonb_build_object('prefix','RE-RSS-PGVCL-2026','nextNumber',1,'padding',4),
  'invoiceNumbering',jsonb_build_object('prefix','RE-INV-2026','nextNumber',1,'padding',4),
  'quotationValidityDays',15,'paymentTerms','10% advance at work order; 90% before material dispatch.','warrantyTerms','Five-year comprehensive system warranty; component warranties as provided by manufacturers.','quotationNotes','Subsidy is informational, subject to eligibility, and credited directly to the customer.','defaultHsnSac','8541 / 9954','footerText','This is a computer-generated document. Subject to Kutch jurisdiction.','inactivityMinutes',30
)) on conflict(key) do nothing;

drop policy if exists settings_authenticated_read on public.company_settings;
create policy settings_authenticated_read on public.company_settings for select to authenticated using(true);

create or replace function public.next_document_number(p_type text,p_prefix text) returns text
language plpgsql security definer set search_path=public as $$
declare
 fy text:=to_char(current_date,'YYYY'); n bigint; cfg jsonb; prefix_ text; padding_ int;
begin
 select value into cfg from company_settings where key='crm.settings';
 if p_type='quotation' then
  prefix_:=coalesce(nullif(cfg#>>'{quotationNumbering,prefix}',''),p_prefix);
  padding_:=greatest(1,least(10,coalesce((cfg#>>'{quotationNumbering,padding}')::int,4)));
 elsif p_type='invoice' then
  prefix_:=coalesce(nullif(cfg#>>'{invoiceNumbering,prefix}',''),p_prefix);
  padding_:=greatest(1,least(10,coalesce((cfg#>>'{invoiceNumbering,padding}')::int,4)));
 else
  prefix_:=format('RE/%s/%s/',p_prefix,fy); padding_:=4;
 end if;
 insert into document_counters(document_type,financial_year,last_number) values(p_type,fy,1)
 on conflict(document_type) do update set last_number=case when excluded.document_type not in('quotation','invoice') and document_counters.financial_year<>excluded.financial_year then 1 else document_counters.last_number+1 end,financial_year=excluded.financial_year,updated_at=now()
 returning last_number into n;
 if p_type='quotation' then update company_settings set value=jsonb_set(value,'{quotationNumbering,nextNumber}',to_jsonb(n+1),true),updated_at=now() where key='crm.settings'; end if;
 if p_type='invoice' then update company_settings set value=jsonb_set(value,'{invoiceNumbering,nextNumber}',to_jsonb(n+1),true),updated_at=now() where key='crm.settings'; end if;
 return prefix_||lpad(n::text,padding_,'0');
end $$;
revoke all on function public.next_document_number(text,text) from public,anon,authenticated;

create or replace function public.save_crm_settings(p_settings jsonb) returns void
language plpgsql security definer set search_path=public as $$
declare q_next bigint; i_next bigint;
begin
 if not is_admin() then raise exception 'Admin access required'; end if;
 if nullif(trim(p_settings#>>'{company,legalName}'),'') is null then raise exception 'Company legal name is required'; end if;
 if nullif(trim(p_settings#>>'{quotationNumbering,prefix}'),'') is null or nullif(trim(p_settings#>>'{invoiceNumbering,prefix}'),'') is null then raise exception 'Document prefixes are required'; end if;
 q_next:=greatest(1,coalesce((p_settings#>>'{quotationNumbering,nextNumber}')::bigint,1));
 i_next:=greatest(1,coalesce((p_settings#>>'{invoiceNumbering,nextNumber}')::bigint,1));
 if coalesce((p_settings#>>'{quotationNumbering,padding}')::int,0) not between 1 and 10 or coalesce((p_settings#>>'{invoiceNumbering,padding}')::int,0) not between 1 and 10 then raise exception 'Number padding must be between 1 and 10'; end if;
 insert into company_settings(key,value,updated_by,updated_at) values('crm.settings',p_settings,auth.uid(),now()) on conflict(key) do update set value=excluded.value,updated_by=excluded.updated_by,updated_at=now();
 insert into document_counters(document_type,financial_year,last_number) values('quotation',to_char(current_date,'YYYY'),q_next-1) on conflict(document_type) do update set financial_year=excluded.financial_year,last_number=excluded.last_number,updated_at=now();
 insert into document_counters(document_type,financial_year,last_number) values('invoice',to_char(current_date,'YYYY'),i_next-1) on conflict(document_type) do update set financial_year=excluded.financial_year,last_number=excluded.last_number,updated_at=now();
 insert into audit_logs(actor_id,action,entity_type,reason,metadata) values(auth.uid(),'crm_settings_updated','company_settings','Main settings and document counters changed',jsonb_build_object('quotationNext',q_next,'invoiceNext',i_next));
end $$;
grant execute on function public.save_crm_settings(jsonb) to authenticated;

create or replace function public.save_quotation_version(p_quote jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 qid uuid; input_id uuid:=nullif(p_quote->>'id','')::uuid; requested_no text:=nullif(trim(p_quote->>'quoteNo'),''); qno text; ver int; old_status quote_status;
 cid uuid:=(p_quote->>'customerId')::uuid; c customers%rowtype; price active_price_rows%rowtype; final numeric:=(p_quote->>'grandTotal')::numeric; suggested numeric;
 v_id uuid:=gen_random_uuid(); item jsonb; actor uuid:=auth.uid(); dealer uuid; commission numeric:=0; existing quotations%rowtype;
begin
 if not can_access_customer(cid) then raise exception 'Customer is not accessible'; end if; select * into c from customers where id=cid;
 if public.current_role()='dealer' then dealer:=current_dealer(); else dealer:=nullif(p_quote->>'dealerId','')::uuid; end if;
 select * into price from active_price_rows where panel_brand=upper(p_quote->>'panelBrand') and panel_technology=p_quote->>'panelTechnology' and panel_wattage=(p_quote->>'panelWattage')::int and panel_quantity=(p_quote->>'panelQuantity')::int;
 if price.id is null then raise exception 'No exact active price configuration exists'; end if; suggested:=price.gross_price;
 if final<>suggested and nullif(trim(p_quote->>'priceOverrideReason'),'') is null then raise exception 'Price override reason is required'; end if;
 if (p_quote->>'taxMode')<>'inclusive' then raise exception 'Published price is GST-inclusive and cannot be changed to GST-extra'; end if;
 if public.current_role()<>'dealer' then commission:=coalesce(nullif(p_quote->>'dealerCommission','')::numeric,0); end if;

 if input_id is not null then select * into existing from quotations where id=input_id and deleted_at is null; end if;
 if existing.id is null and requested_no is not null then select * into existing from quotations where quotation_no=requested_no and deleted_at is null; end if;
 if existing.id is not null then
  if requested_no is not null and existing.quotation_no=requested_no and input_id<>existing.id and coalesce((p_quote->>'versionNo')::int,1)<=1 then raise exception 'Quotation number already exists'; end if;
  if existing.customer_id<>cid then raise exception 'Quotation customer cannot be changed'; end if;
  qid:=existing.id; qno:=existing.quotation_no; ver:=existing.current_version+1; old_status:=existing.current_status;
  update quotations set current_version=ver,current_status='draft',dealer_id=dealer,updated_by=actor,updated_at=now(),sent_at=null,approved_at=null,rejected_at=null where id=qid;
  insert into quotation_status_history(quotation_id,from_status,to_status,reason,changed_by) values(qid,old_status,'draft','Commercial revision created',actor);
 else
  qid:=coalesce(input_id,gen_random_uuid()); qno:=coalesce(requested_no,next_document_number('quotation','QT')); ver:=1;
  if exists(select 1 from quotations where quotation_no=qno) then raise exception 'Quotation number already exists'; end if;
  insert into quotations(id,quotation_no,customer_id,district_id,dealer_id,current_version,current_status,created_by,updated_by) values(qid,qno,cid,c.district_id,dealer,ver,'draft',actor,actor);
  insert into quotation_status_history(quotation_id,to_status,changed_by) values(qid,'draft',actor);
 end if;
 insert into quotation_versions(id,quotation_id,version_no,price_list_item_id,system_type,dcr_type,scheme,panel_brand,panel_technology,panel_wattage,panel_quantity,dc_capacity_kw,suggested_price,final_price,price_override_reason,gst_included,dealer_commission,internal_cost,immutable_snapshot,created_by)
 values(v_id,qid,ver,price.id,p_quote->>'systemType',p_quote->>'dcrType',p_quote->>'scheme',upper(p_quote->>'panelBrand'),p_quote->>'panelTechnology',(p_quote->>'panelWattage')::int,(p_quote->>'panelQuantity')::int,price.dc_capacity_kw,suggested,final,nullif(p_quote->>'priceOverrideReason',''),true,commission,case when public.current_role()='dealer' then 0 else coalesce(nullif(p_quote->>'internalCost','')::numeric,0) end,p_quote||jsonb_build_object('id',qid,'quoteNo',qno,'versionNo',ver,'status','draft','suggestedPrice',suggested,'basePrice',final,'grandTotal',final,'dcCapacityKw',price.dc_capacity_kw,'dealerId',dealer,'dealerCommission',commission,'taxMode','inclusive'),actor);
 for item in select * from jsonb_array_elements(coalesce(p_quote->'items','[]')) loop
  insert into quotation_items(quotation_version_id,description,brand,specification,quantity,unit,rate,selected,internal_only) values(v_id,item->>'description',nullif(item->>'brand',''),nullif(item->>'specification',''),coalesce((item->>'quantity')::numeric,1),coalesce(item->>'unit','Nos'),coalesce(nullif(item->>'rate','')::numeric,0),coalesce((item->>'selected')::boolean,true),coalesce((item->>'internalOnly')::boolean,false));
 end loop;
 if final<>suggested then insert into quotation_overrides(quotation_id,version_no,suggested_price,final_price,reason,created_by) values(qid,ver,suggested,final,p_quote->>'priceOverrideReason',actor); end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(actor,'quotation_version_saved','quotation',qid,nullif(p_quote->>'priceOverrideReason',''),jsonb_build_object('version',ver,'quotationNo',qno,'suggested',suggested,'final',final));
 return qid;
end $$;
grant execute on function public.save_quotation_version(jsonb) to authenticated;

create or replace function public.update_inventory_item(p_item jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare iid uuid:=(p_item->>'id')::uuid; did uuid:=nullif(p_item->>'districtId','')::uuid;
begin
 if not is_admin() then raise exception 'Admin access required'; end if;
 if not exists(select 1 from inventory_items where id=iid and deleted_at is null) then raise exception 'Inventory item not found'; end if;
 update inventory_items set item_code=upper(trim(p_item->>'itemCode')),item_name=trim(p_item->>'itemName'),category=trim(p_item->>'category'),brand=nullif(trim(p_item->>'brand'),''),model=nullif(trim(p_item->>'model'),''),specification=nullif(trim(p_item->>'specification'),''),unit=trim(p_item->>'unit'),district_id=did,reorder_level=greatest(0,coalesce(nullif(p_item->>'reorderLevel','')::numeric,0)) where id=iid;
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'inventory_item_updated','inventory_item',iid,p_item);
 return iid;
exception when unique_violation then raise exception 'Inventory item code already exists';
end $$;
grant execute on function public.update_inventory_item(jsonb) to authenticated;

create or replace function public.archive_inventory_item(p_item_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare bal inventory_balance%rowtype;
begin
 if not is_admin() then raise exception 'Admin access required'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Archive reason is required'; end if;
 select * into bal from inventory_balance where id=p_item_id;
 if bal.id is null then raise exception 'Inventory item not found'; end if;
 if bal.on_hand<>0 or bal.reserved<>0 then raise exception 'Item can be archived only when on-hand and reserved stock are zero'; end if;
 update inventory_items set deleted_at=now(),updated_at=now() where id=p_item_id;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'inventory_item_archived','inventory_item',p_item_id,p_reason,jsonb_build_object('onHand',bal.on_hand,'reserved',bal.reserved));
end $$;
grant execute on function public.archive_inventory_item(uuid,text) to authenticated;

create or replace function public.save_project_material_requirements(p_project_id uuid,p_materials jsonb,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare p projects%rowtype; row_ jsonb; rid uuid; existing project_material_requirements%rowtype; keep_ids uuid[]:='{}'; qty numeric;
begin
 select * into p from projects where id=p_project_id for update;
 if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Material change reason is required'; end if;
 for row_ in select * from jsonb_array_elements(coalesce(p_materials,'[]')) loop
  rid:=coalesce(nullif(row_->>'id','')::uuid,gen_random_uuid()); qty:=coalesce(nullif(row_->>'requiredQty','')::numeric,0);
  if qty<=0 or nullif(trim(row_->>'itemName'),'') is null or nullif(trim(row_->>'unit'),'') is null then raise exception 'Every material needs a name, positive quantity and unit'; end if;
  select * into existing from project_material_requirements where id=rid;
  if existing.id is not null then
   if existing.project_id<>p.id then raise exception 'Invalid material row'; end if;
   if qty<greatest(existing.reserved_qty,existing.issued_qty) then raise exception 'Required quantity cannot be below reserved or issued quantity for %',existing.item_name; end if;
   update project_material_requirements set item_code=upper(trim(row_->>'itemCode')),item_name=trim(row_->>'itemName'),specification=nullif(trim(row_->>'specification'),''),required_qty=qty,unit=trim(row_->>'unit') where id=rid;
  else
   insert into project_material_requirements(id,project_id,item_code,item_name,specification,required_qty,unit) values(rid,p.id,coalesce(nullif(upper(trim(row_->>'itemCode')),''),'MANUAL'),trim(row_->>'itemName'),nullif(trim(row_->>'specification'),''),qty,trim(row_->>'unit'));
  end if;
  keep_ids:=array_append(keep_ids,rid); existing:=null;
 end loop;
 if exists(select 1 from project_material_requirements where project_id=p.id and not(id=any(keep_ids)) and (reserved_qty>0 or issued_qty>0)) then raise exception 'Reserved or issued material rows cannot be removed'; end if;
 delete from project_material_requirements where project_id=p.id and not(id=any(keep_ids));
 update projects set updated_at=now(),row_version=row_version+1 where id=p.id;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'project_materials_updated','project',p.id,p_reason,jsonb_build_object('rows',jsonb_array_length(p_materials)));
end $$;
grant execute on function public.save_project_material_requirements(uuid,jsonb,text) to authenticated;

create or replace function public.save_installation_and_issue_invoice(p_project_id uuid,p_details jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 p projects%rowtype; q jsonb; expected int; serial_count int; duplicate_count int; tr tax_rules%rowtype; gross numeric; taxable numeric; tax numeric;
 inv_id uuid:=gen_random_uuid(); inv_no text; inv_date date:=coalesce(nullif(p_details->>'invoiceDate','')::date,current_date); place_ text:=coalesce(nullif(trim(p_details->>'placeOfSupply'),''),'Gujarat (24)'); serial text; panel_item uuid; hsn text;
begin
 select * into p from projects where id=p_project_id for update;
 if p.id is null or not can_access_project(p.id) or public.current_role()='dealer' then raise exception 'Not authorised'; end if;
 if not (p.current_stage = any(array['installation_done','inspection_pending','inspection_done','meter_pending','meter_done','commissioning_done','subsidy_pending','subsidy_passed','handover_completed','project_closed']::project_stage[])) then raise exception 'Invoice is available only after Project Installation Done'; end if;
 if exists(select 1 from customer_invoices where project_id=p.id and status in('issued','paid')) then raise exception 'An active invoice already exists'; end if;
 q:=p.accepted_quotation_snapshot; expected:=(q->>'panelQuantity')::int; serial_count:=jsonb_array_length(coalesce(p_details->'panelSerials','[]'));
 if serial_count<1 then raise exception 'Panel serial numbers are required'; end if;
 select count(*)-count(distinct value) into duplicate_count from jsonb_array_elements_text(p_details->'panelSerials'); if duplicate_count>0 then raise exception 'Duplicate panel serial numbers are not allowed'; end if;
 if (serial_count<>expected or p_details->>'panelBrand'<>q->>'panelBrand' or (p_details->>'panelWattage')::int<>(q->>'panelWattage')::int) and nullif(trim(p_details->>'overrideReason'),'') is null then raise exception 'Material change reason is required'; end if;
 select inventory_item_id into panel_item from project_material_requirements where project_id=p.id and item_code like 'PV-%' limit 1;
 if panel_item is null then
  insert into inventory_items(item_code,item_name,category,brand,model,specification,unit,district_id,serialized,reorder_level,created_by) values(format('PV-%s-%s',p_details->>'panelBrand',p_details->>'panelWattage'),format('%s %s Solar Panel',p_details->>'panelBrand',p_details->>'panelTechnology'),'PV Module',p_details->>'panelBrand',p_details->>'panelTechnology',format('%s Wp',p_details->>'panelWattage'),'Nos',p.district_id,true,0,auth.uid()) on conflict(item_code) do update set item_name=excluded.item_name returning id into panel_item;
  update project_material_requirements set inventory_item_id=panel_item where project_id=p.id and item_code like 'PV-%';
 end if;
 for serial in select jsonb_array_elements_text(p_details->'panelSerials') loop
  if nullif(trim(serial),'') is null then raise exception 'Panel serial numbers cannot be blank'; end if;
  if exists(select 1 from inventory_serials where serial_number=serial) then raise exception 'Installed serial number % already exists',serial; end if;
  insert into inventory_serials(inventory_item_id,serial_number,status,project_id) values(panel_item,serial,'installed',p.id);
 end loop;
 insert into installation_materials(project_id,details,created_by) values(p.id,p_details,auth.uid());
 select * into tr from tax_rules where active and effective_from<=inv_date and (effective_to is null or effective_to>=inv_date) order by effective_from desc limit 1; if tr.id is null then raise exception 'No active effective-dated tax rule exists'; end if;
 gross:=(q->>'grandTotal')::numeric; taxable:=round(gross*100/(100+tr.gst_rate),2); tax:=gross-taxable;
 inv_no:=coalesce(nullif(trim(p_details->>'invoiceNo'),''),next_document_number('invoice','INV'));
 if exists(select 1 from customer_invoices where invoice_no=inv_no) then raise exception 'Invoice number already exists'; end if;
 select coalesce(value->>'defaultHsnSac','8541 / 9954') into hsn from company_settings where key='crm.settings';
 insert into customer_invoices(id,invoice_no,customer_id,project_id,invoice_date,place_of_supply,status,tax_rule_id,taxable_value,cgst,sgst,igst,grand_total,snapshot,issued_by)
 values(inv_id,inv_no,p.customer_id,p.id,inv_date,place_,'issued',tr.id,taxable,case when tr.intrastate then round(tax/2,2) else 0 end,case when tr.intrastate then tax-round(tax/2,2) else 0 end,case when tr.intrastate then 0 else tax end,gross,jsonb_build_object('id',inv_id,'invoiceNo',inv_no,'customerId',p.customer_id,'projectId',p.id,'invoiceDate',inv_date,'placeOfSupply',place_,'status','issued','taxMode','inclusive','taxableValue',taxable,'cgst',case when tr.intrastate then round(tax/2,2) else 0 end,'sgst',case when tr.intrastate then tax-round(tax/2,2) else 0 end,'igst',case when tr.intrastate then 0 else tax end,'roundOff',0,'grandTotal',gross),auth.uid());
 insert into customer_invoice_items(invoice_id,description,hsn_sac,quantity,unit,taxable_value,tax_rate,serial_numbers) values(inv_id,format('Supply and Installation of %s kW Rooftop Solar Power Plant',q->>'dcCapacityKw'),hsn,1,'Job',taxable,tr.gst_rate,array(select jsonb_array_elements_text(p_details->'panelSerials')));
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'customer_invoice_issued','customer_invoice',inv_id,p_details->>'overrideReason',jsonb_build_object('projectId',p.id,'invoiceNo',inv_no,'gross',gross,'serialCount',serial_count));
 return inv_id;
end $$;
grant execute on function public.save_installation_and_issue_invoice(uuid,jsonb) to authenticated;

commit;
