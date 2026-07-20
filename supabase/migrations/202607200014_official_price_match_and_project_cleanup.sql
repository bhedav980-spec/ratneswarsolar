-- Official five-PDF price source, internal quotation matching, invoice cancellation and safe project cleanup.
begin;

do $$
declare
 list_540 uuid; list_580 uuid; list_w610 uuid; list_a550 uuid; list_a610 uuid; verified_count integer;
begin
 update public.price_lists set status='inactive' where status='published';

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official WAAREE Bifacial 540 Wp',1,date '2026-07-20','published','Ratneswar_WAAREE BIFACIAL 540WP PRICE LIST.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_540;
 update public.price_list_items set active=false where price_list_id=list_540;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',4,2.160,112615,62880,49735,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',5,2.700,133320,69000,64320,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',6,3.240,156752,78000,78752,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',7,3.780,177154,78000,99154,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',8,4.320,202000,78000,124000,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',9,4.860,227654,78000,149654,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',10,5.400,249066,78000,171066,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',11,5.940,274013,78000,196013,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',12,6.480,318554,78000,240554,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',14,7.560,364105,78000,286105,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',16,8.640,403293,78000,325293,true),
 (list_540,'WAAREE','Bifacial',540,540,540,'540 Wp',18,9.720,442481,78000,364481,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official WAAREE TOPCon 580 Wp',1,date '2026-07-20','published','Ratneswar_WAREE_TOPCORN_580WP.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_580;
 update public.price_list_items set active=false where price_list_id=list_580;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',4,2.320,124129,65760,58369,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',5,2.900,149076,76200,72876,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',6,3.480,174023,78000,96023,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',7,4.060,203010,78000,125010,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',8,4.640,226442,78000,148442,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',9,5.220,255934,78000,177934,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',10,5.800,277851,78000,199851,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',12,6.960,352187,78000,274187,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',14,8.120,398950,78000,320950,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',17,9.860,472276,78000,394276,true),
 (list_580,'WAAREE','TOPCon',580,580,580,'580 Wp',18,10.440,494294,78000,416294,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official WAAREE TOPCon 610-615 Wp',1,date '2026-07-20','published','Ratneswar_WAREE_TOPCORN_610-615WP.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_w610;
 update public.price_list_items set active=false where price_list_id=list_w610;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',4,2.440,129381,67920,61461,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',5,3.050,155742,78000,77742,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',6,3.660,178972,78000,100972,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',7,4.270,212302,78000,134302,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',8,4.880,242198,78000,164198,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',9,5.490,267751,78000,189751,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',10,6.100,315019,78000,237019,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',12,7.320,368044,78000,290044,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',14,8.540,417534,78000,339534,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',16,9.760,471468,78000,393468,true),
 (list_w610,'WAAREE','TOPCon',610,610,615,'610 / 615 Wp',17,10.370,494698,78000,416698,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official ADANI Bifacial 550 Wp',1,date '2026-07-20','published','Ratneswar_Adani_Bifacial_550WP.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_a550;
 update public.price_list_items set active=false where price_list_id=list_a550;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',4,2.200,117665,63600,54065,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',5,2.750,140996,69000,71996,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',6,3.300,161297,78000,83297,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',7,3.850,186042,78000,108042,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',8,4.400,213514,78000,135514,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',9,4.950,236138,78000,158138,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',10,5.500,262297,78000,184297,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',12,6.600,332189,78000,254189,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',14,7.700,374811,78000,296811,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',16,8.800,423392,78000,345392,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',18,9.900,465105,78000,387105,true),
 (list_a550,'ADANI','Bifacial',550,550,550,'550 Wp',19,10.450,485507,78000,407507,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Official ADANI TOPCon 610-625 Wp',1,date '2026-07-20','published','Ratneswar_Adani TOPCON 610-615-620-625WP PRICE LIST.pdf',now())
 on conflict(name,version_no) do update set status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_a610;
 update public.price_list_items set active=false where price_list_id=list_a610;
 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',4,2.440,131502,67920,63582,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',5,3.050,158267,78000,80267,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',6,3.660,182002,78000,104002,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',7,4.270,215938,78000,137938,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',8,4.880,246238,78000,168238,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',9,5.490,272397,78000,194397,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',10,6.100,320776,78000,242776,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',12,7.320,374205,78000,296205,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',14,8.540,424705,78000,346705,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',16,9.760,479750,78000,401750,true),
 (list_a610,'ADANI','TOPCon',610,610,625,'610 / 615 / 620 / 625 Wp',17,10.370,503485,78000,425485,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity) do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=excluded.expected_subsidy,after_subsidy=excluded.after_subsidy,active=true;

 select count(*) into verified_count from public.price_list_items where active and price_list_id in(list_540,list_580,list_w610,list_a550,list_a610);
 if verified_count<>57 then raise exception 'Official price seed must contain 57 rows; found %',verified_count; end if;
end $$;

create or replace function public.save_quotation_version(p_quote jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 qid uuid; input_id uuid:=nullif(p_quote->>'id','')::uuid; requested_no text:=nullif(trim(p_quote->>'quoteNo'),''); qno text; ver int; old_status quote_status;
 cid uuid:=(p_quote->>'customerId')::uuid; c customers%rowtype; price active_price_rows%rowtype; final numeric:=(p_quote->>'grandTotal')::numeric; suggested numeric;
 quoted_capacity numeric:=coalesce(nullif(p_quote->>'dcCapacityKw','')::numeric,0); quoted_wattage int:=coalesce(nullif(p_quote->>'panelWattage','')::int,0); quoted_quantity int:=coalesce(nullif(p_quote->>'panelQuantity','')::int,0); calculated_capacity numeric;
 v_id uuid:=gen_random_uuid(); item jsonb; actor uuid:=auth.uid(); dealer uuid; commission numeric:=0; existing quotations%rowtype; source_id uuid:=nullif(p_quote->'priceSnapshot'->>'priceRowId','')::uuid; config_changed boolean:=false;
begin
 if not can_access_customer(cid) then raise exception 'Customer is not accessible'; end if; select * into c from customers where id=cid;
 if quoted_capacity<=0 or quoted_wattage<=0 or quoted_quantity<=0 then raise exception 'Panel wattage, quantity and exact DC capacity must be greater than zero'; end if;
 if public.current_role()='dealer' then dealer:=current_dealer(); else dealer:=nullif(p_quote->>'dealerId','')::uuid; end if;
 if dealer is not null and not exists(select 1 from dealers d where d.id=dealer and d.active and d.deleted_at is null and d.district_id=c.district_id) then raise exception 'Selected dealer is not active in the customer area'; end if;
 if source_id is not null then
  select * into price from active_price_rows
  where id=source_id and panel_brand=upper(trim(p_quote->>'panelBrand')) and panel_technology=p_quote->>'panelTechnology'
   and quoted_wattage between panel_wattage_min and panel_wattage_max;
 end if;
 if price.id is null then
  select * into price from active_price_rows
  where panel_brand=upper(trim(p_quote->>'panelBrand')) and panel_technology=p_quote->>'panelTechnology'
   and quoted_wattage between panel_wattage_min and panel_wattage_max and panel_quantity=quoted_quantity
  limit 1;
 end if;
 if price.id is null then raise exception 'No official price configuration exists for this brand, technology and wattage'; end if;
 suggested:=price.gross_price; calculated_capacity:=round(quoted_wattage*quoted_quantity/1000.0,3);
 config_changed:=quoted_quantity<>price.panel_quantity or abs(quoted_capacity-calculated_capacity)>.0005;
 if config_changed and nullif(trim(p_quote->>'configurationOverrideReason'),'') is null then raise exception 'Manual configuration edit reason is required'; end if;
 if final<>suggested and nullif(trim(p_quote->>'priceOverrideReason'),'') is null then raise exception 'Price override reason is required'; end if;
 if (p_quote->>'taxMode')<>'inclusive' then raise exception 'Published price is GST-inclusive and cannot be changed to GST-extra'; end if;
 if public.current_role()<>'dealer' then commission:=greatest(0,coalesce(nullif(p_quote->>'dealerCommission','')::numeric,0)); end if;

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
 values(v_id,qid,ver,price.id,p_quote->>'systemType',p_quote->>'dcrType',p_quote->>'scheme',upper(trim(p_quote->>'panelBrand')),p_quote->>'panelTechnology',quoted_wattage,quoted_quantity,quoted_capacity,suggested,final,nullif(p_quote->>'priceOverrideReason',''),true,commission,case when public.current_role()='dealer' then 0 else coalesce(nullif(p_quote->>'internalCost','')::numeric,0) end,p_quote||jsonb_build_object('id',qid,'quoteNo',qno,'versionNo',ver,'status','draft','suggestedPrice',suggested,'basePrice',final,'grandTotal',final,'dcCapacityKw',quoted_capacity,'dealerId',dealer,'dealerCommission',commission,'taxMode','inclusive'),actor);
 for item in select * from jsonb_array_elements(coalesce(p_quote->'items','[]')) loop
  insert into quotation_items(quotation_version_id,description,brand,specification,quantity,unit,rate,selected,internal_only) values(v_id,item->>'description',nullif(item->>'brand',''),nullif(item->>'specification',''),coalesce((item->>'quantity')::numeric,1),coalesce(item->>'unit','Nos'),coalesce(nullif(item->>'rate','')::numeric,0),coalesce((item->>'selected')::boolean,true),coalesce((item->>'internalOnly')::boolean,false));
 end loop;
 if final<>suggested then insert into quotation_overrides(quotation_id,version_no,suggested_price,final_price,reason,created_by) values(qid,ver,suggested,final,p_quote->>'priceOverrideReason',actor); end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(actor,'quotation_version_saved','quotation',qid,coalesce(nullif(p_quote->>'configurationOverrideReason',''),nullif(p_quote->>'priceOverrideReason','')),jsonb_build_object('version',ver,'quotationNo',qno,'officialPriceRowId',price.id,'suggested',suggested,'final',final,'quotedWattage',quoted_wattage,'quotedQuantity',quoted_quantity,'quotedCapacity',quoted_capacity,'loanRequired',coalesce((p_quote->>'loanRequired')::boolean,false)));
 return qid;
end $$;
grant execute on function public.save_quotation_version(jsonb) to authenticated;

create or replace function public.cancel_customer_invoice(p_invoice_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare inv public.customer_invoices%rowtype;
begin
 if not public.is_admin() then raise exception 'Only Admin can cancel an invoice'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'Invoice cancellation reason is required'; end if;
 select * into inv from public.customer_invoices where id=p_invoice_id for update;
 if inv.id is null then raise exception 'Invoice not found'; end if;
 if inv.status='cancelled' then return; end if;
 if inv.status not in('issued') then raise exception 'Only an issued, unpaid invoice can be cancelled'; end if;
 update public.customer_invoices set status='cancelled',cancelled_at=now(),cancellation_reason=trim(p_reason),snapshot=snapshot||jsonb_build_object('status','cancelled','cancelledAt',now(),'cancellationReason',trim(p_reason)) where id=inv.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(auth.uid(),'customer_invoice_cancelled','customer_invoice',inv.id,trim(p_reason),jsonb_build_object('invoiceNo',inv.invoice_no,'projectId',inv.project_id));
end $$;
grant execute on function public.cancel_customer_invoice(uuid,text) to authenticated;

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
 if exists(select 1 from public.dealer_commission_payments cp join public.dealer_commissions c on c.id=cp.commission_id where c.project_id=p.id) then raise exception 'A project with dealer commission payments cannot be deleted'; end if;
 if exists(select 1 from public.payments where project_id=p.id and deleted_at is null) or exists(select 1 from public.expenses where project_id=p.id and deleted_at is null) then raise exception 'Remove linked payments and expenses before deleting this project'; end if;

 insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,metadata)
 values(auth.uid(),'erroneous_project_deleted','project',p.id,trim(p_reason),jsonb_build_object('projectNo',p.project_no,'quotationId',p.quotation_id,'cancelledInvoices',(select count(*) from customer_invoices where project_id=p.id and status='cancelled')));
 delete from public.customer_invoice_items where invoice_id in(select id from public.customer_invoices where project_id=p.id and status='cancelled');
 delete from public.customer_invoices where project_id=p.id and status='cancelled';
 delete from public.inventory_serials where project_id=p.id;
 delete from public.installation_materials where project_id=p.id;
 delete from public.stock_transactions where project_id=p.id and transaction_type='reservation';
 delete from public.dealer_commissions where project_id=p.id;
 delete from public.project_material_requirements where project_id=p.id;
 delete from public.project_stage_history where project_id=p.id;
 delete from public.project_documents where project_id=p.id;
 update public.agreements set project_id=null where project_id=p.id;
 delete from public.projects where id=p.id;
 update public.quotations set current_status='approved',project_created_at=null,updated_by=auth.uid(),updated_at=now() where id=p.quotation_id and deleted_at is null;
end $$;
grant execute on function public.delete_erroneous_project(uuid,text) to authenticated;

commit;
