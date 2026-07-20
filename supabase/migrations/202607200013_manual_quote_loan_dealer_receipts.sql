-- Manual + automatic quotation controls, fixed dealer commission workflow and material-receipt support.
begin;

create or replace function public.save_dealer(p_dealer jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 role public.app_role:=public.current_role();
 did uuid; id_ uuid:=coalesce(nullif(p_dealer->>'id','')::uuid,gen_random_uuid());
 mobile_ text:=regexp_replace(coalesce(p_dealer->>'mobile',''),'\D','','g');
begin
 if role not in ('admin','district_partner') then raise exception 'Admin or Area Partner access required'; end if;
 if role='district_partner' then did:=public.current_district();
 else did:=coalesce(nullif(p_dealer->>'districtId','')::uuid,(select id from districts where active and name=p_dealer->>'district'));
 end if;
 if did is null then raise exception 'Dealer area is required'; end if;
 if length(mobile_)<>10 then raise exception 'Dealer mobile number must contain exactly 10 digits'; end if;
 if role='district_partner' and exists(select 1 from dealers where id=id_ and district_id<>did) then raise exception 'Dealer is outside your assigned area'; end if;
 insert into dealers(id,dealer_no,name,mobile,email,address,district_id,login_user_id,default_commission_type,default_commission_value,active,created_by,updated_by)
 values(id_,next_document_number('dealer','DL'),trim(p_dealer->>'name'),mobile_,nullif(lower(trim(p_dealer->>'email')),''),nullif(trim(p_dealer->>'address'),''),did,nullif(p_dealer->>'loginUserId','')::uuid,'fixed',greatest(0,coalesce(nullif(p_dealer->>'commissionValue','')::numeric,0)),coalesce((p_dealer->>'active')::boolean,true),auth.uid(),auth.uid())
 on conflict(id) do update set name=excluded.name,mobile=excluded.mobile,email=excluded.email,address=excluded.address,district_id=excluded.district_id,default_commission_type='fixed',default_commission_value=excluded.default_commission_value,active=excluded.active,updated_by=auth.uid(),updated_at=now();
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'dealer_saved','dealer',id_,jsonb_build_object('source','quotation_or_dealer_master','commissionType','fixed'));
 return id_;
exception when unique_violation then raise exception 'A dealer with this mobile number already exists in the selected area';
end $$;
grant execute on function public.save_dealer(jsonb) to authenticated;

create or replace function public.save_quotation_version(p_quote jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 qid uuid; input_id uuid:=nullif(p_quote->>'id','')::uuid; requested_no text:=nullif(trim(p_quote->>'quoteNo'),''); qno text; ver int; old_status quote_status;
 cid uuid:=(p_quote->>'customerId')::uuid; c customers%rowtype; price active_price_rows%rowtype; final numeric:=(p_quote->>'grandTotal')::numeric; suggested numeric;
 quoted_capacity numeric:=coalesce(nullif(p_quote->>'dcCapacityKw','')::numeric,0); quoted_wattage int:=coalesce(nullif(p_quote->>'panelWattage','')::int,0); quoted_quantity int:=coalesce(nullif(p_quote->>'panelQuantity','')::int,0);
 v_id uuid:=gen_random_uuid(); item jsonb; actor uuid:=auth.uid(); dealer uuid; commission numeric:=0; existing quotations%rowtype; source_id uuid:=nullif(p_quote->'priceSnapshot'->>'priceRowId','')::uuid; config_changed boolean:=false;
begin
 if not can_access_customer(cid) then raise exception 'Customer is not accessible'; end if; select * into c from customers where id=cid;
 if quoted_capacity<=0 or quoted_wattage<=0 or quoted_quantity<=0 then raise exception 'Panel wattage, quantity and exact DC capacity must be greater than zero'; end if;
 if upper(trim(p_quote->>'panelBrand'))='WAAREE' and quoted_wattage not in (540,580) then raise exception 'WAAREE quotation wattage must be 540 Wp or 580 Wp'; end if;
 if public.current_role()='dealer' then dealer:=current_dealer(); else dealer:=nullif(p_quote->>'dealerId','')::uuid; end if;
 if dealer is not null and not exists(select 1 from dealers d where d.id=dealer and d.active and d.deleted_at is null and d.district_id=c.district_id) then raise exception 'Selected dealer is not active in the customer area'; end if;
 if source_id is not null then select * into price from active_price_rows where id=source_id; end if;
 if price.id is null then select * into price from active_price_rows where panel_brand=upper(p_quote->>'panelBrand') and panel_technology=p_quote->>'panelTechnology' and panel_wattage=quoted_wattage and panel_quantity=quoted_quantity; end if;
 if price.id is null then raise exception 'A verified source price row is required'; end if; suggested:=price.gross_price;
 config_changed:=upper(trim(p_quote->>'panelBrand'))<>upper(price.panel_brand) or p_quote->>'panelTechnology'<>price.panel_technology or quoted_wattage<>price.panel_wattage or quoted_quantity<>price.panel_quantity or abs(quoted_capacity-price.dc_capacity_kw)>.0005;
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
 values(v_id,qid,ver,price.id,p_quote->>'systemType',p_quote->>'dcrType',p_quote->>'scheme',upper(trim(p_quote->>'panelBrand')),p_quote->>'panelTechnology',quoted_wattage,quoted_quantity,quoted_capacity,suggested,final,nullif(p_quote->>'priceOverrideReason',''),true,commission,case when public.current_role()='dealer' then 0 else coalesce(nullif(p_quote->>'internalCost','')::numeric,0) end,p_quote||jsonb_build_object('id',qid,'quoteNo',qno,'versionNo',ver,'status','draft','suggestedPrice',suggested,'basePrice',final,'grandTotal',final,'dcCapacityKw',quoted_capacity,'dealerId',dealer,'dealerCommission',commission,'taxMode','inclusive','subsidy',coalesce(p_quote->'subsidy',jsonb_build_object('eligible',true,'central',78000,'state',0,'total',78000,'informationalOnly',true))),actor);
 for item in select * from jsonb_array_elements(coalesce(p_quote->'items','[]')) loop
  insert into quotation_items(quotation_version_id,description,brand,specification,quantity,unit,rate,selected,internal_only) values(v_id,item->>'description',nullif(item->>'brand',''),nullif(item->>'specification',''),coalesce((item->>'quantity')::numeric,1),coalesce(item->>'unit','Nos'),coalesce(nullif(item->>'rate','')::numeric,0),coalesce((item->>'selected')::boolean,true),coalesce((item->>'internalOnly')::boolean,false));
 end loop;
 if final<>suggested then insert into quotation_overrides(quotation_id,version_no,suggested_price,final_price,reason,created_by) values(qid,ver,suggested,final,p_quote->>'priceOverrideReason',actor); end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,reason,metadata) values(actor,'quotation_version_saved','quotation',qid,coalesce(nullif(p_quote->>'configurationOverrideReason',''),nullif(p_quote->>'priceOverrideReason','')),jsonb_build_object('version',ver,'quotationNo',qno,'suggested',suggested,'final',final,'configurationMode',coalesce(p_quote->>'configurationMode','automatic'),'loanRequired',coalesce((p_quote->>'loanRequired')::boolean,false)));
 return qid;
end $$;
grant execute on function public.save_quotation_version(jsonb) to authenticated;

commit;
