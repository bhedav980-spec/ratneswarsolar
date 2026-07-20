begin;

create or replace function public.current_role() returns public.app_role language sql stable security definer set search_path=public as $$ select role from profiles where id=auth.uid() and active $$;
create or replace function public.current_district() returns uuid language sql stable security definer set search_path=public as $$ select district_id from profiles where id=auth.uid() and active $$;
create or replace function public.current_dealer() returns uuid language sql stable security definer set search_path=public as $$ select dealer_id from profiles where id=auth.uid() and active $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select coalesce(public.current_role()='admin',false) $$;
create or replace function public.can_access_customer(p_customer uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from customers c where c.id=p_customer and c.archived_at is null and (is_admin() or (public.current_role()='district_partner' and c.district_id=current_district()) or (public.current_role()='dealer' and c.dealer_id=current_dealer())))
$$;
create or replace function public.can_access_project(p_project uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from projects p where p.id=p_project and (is_admin() or (public.current_role()='district_partner' and p.district_id=current_district())))
$$;
grant execute on function public.current_role(),public.current_district(),public.current_dealer(),public.is_admin(),public.can_access_customer(uuid),public.can_access_project(uuid) to authenticated;

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
create trigger districts_touch before update on public.districts for each row execute function public.touch_updated_at();
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger dealers_touch before update on public.dealers for each row execute function public.touch_updated_at();
create trigger inventory_touch before update on public.inventory_items for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into profiles(id,full_name,role,active) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'full_name',''),split_part(new.email,'@',1)),'dealer',false) on conflict(id) do nothing; return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.next_document_number(p_type text,p_prefix text) returns text language plpgsql security definer set search_path=public as $$
declare fy text:=to_char(current_date,'YYYY'); n bigint;
begin insert into document_counters(document_type,financial_year,last_number) values(p_type,fy,1)
 on conflict(document_type) do update set last_number=case when document_counters.financial_year=excluded.financial_year then document_counters.last_number+1 else 1 end,financial_year=excluded.financial_year,updated_at=now()
 returning last_number into n; return format('RE/%s/%s/%s',p_prefix,fy,lpad(n::text,4,'0')); end $$;
revoke all on function public.next_document_number(text,text) from public,anon,authenticated;

create or replace view public.profile_current with (security_invoker=true) as
select p.id,p.full_name,p.role,p.district_id,d.name district_name,p.dealer_id,p.active,p.last_login_at,false mfa_verified from profiles p left join districts d on d.id=p.district_id where p.id=auth.uid() and p.active;

create or replace view public.active_price_rows with (security_invoker=true) as
select distinct on(i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity)
 i.id,i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity,i.dc_capacity_kw,i.gross_price,i.expected_subsidy,i.after_subsidy,i.active,
 l.effective_from,l.version_no,l.source_document
from price_list_items i join price_lists l on l.id=i.price_list_id where i.active and l.status='published' and l.effective_from<=current_date
order by i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity,l.effective_from desc,l.version_no desc;

create or replace view public.inventory_balance with (security_invoker=true) as
select i.id,i.item_code,i.item_name,i.category,i.brand,i.model,i.specification,i.unit,i.district_id,d.name district_name,i.reorder_level,
 coalesce(sum(case when t.transaction_type in('purchase','opening','return','adjustment') then t.quantity when t.transaction_type in('issue','damage','consumption') then -t.quantity else 0 end),0)::numeric(14,3) on_hand,
 greatest(coalesce(sum(case when t.transaction_type='reservation' then t.quantity when t.transaction_type='issue' and t.project_id is not null then -t.quantity else 0 end),0),0)::numeric(14,3) reserved,
 (coalesce(sum(case when t.transaction_type in('purchase','opening','return','adjustment') then t.quantity when t.transaction_type in('issue','damage','consumption') then -t.quantity else 0 end),0)-greatest(coalesce(sum(case when t.transaction_type='reservation' then t.quantity when t.transaction_type='issue' and t.project_id is not null then -t.quantity else 0 end),0),0))::numeric(14,3) available,
 coalesce(sum(case when t.transaction_type in('purchase','opening') then t.quantity*coalesce(t.unit_rate,0) else 0 end)/nullif(sum(case when t.transaction_type in('purchase','opening') then t.quantity else 0 end),0),0)::numeric(14,2) average_rate
from inventory_items i left join districts d on d.id=i.district_id left join stock_transactions t on t.inventory_item_id=i.id where i.deleted_at is null group by i.id,d.name;

create or replace view public.quotation_current with (security_invoker=true) as
select q.id,q.customer_id,q.district_id,q.dealer_id,q.created_at,
 (v.immutable_snapshot || jsonb_build_object('id',q.id,'quoteNo',q.quotation_no,'versionNo',q.current_version,'status',q.current_status,'sentAt',q.sent_at,'approvedAt',q.approved_at,'rejectedAt',q.rejected_at)) payload
from quotations q join quotation_versions v on v.quotation_id=q.id and v.version_no=q.current_version where q.deleted_at is null;

create or replace view public.project_current with (security_invoker=true) as
select p.id,p.customer_id,p.district_id,p.created_at,
 jsonb_build_object('id',p.id,'projectNo',p.project_no,'customerId',p.customer_id,'quotationId',p.quotation_id,'agreementId',p.agreement_id,'acceptedQuoteSnapshot',p.accepted_quotation_snapshot,'stage',p.current_stage,'assignedTo',p.assigned_partner_id,'district',d.name,'paymentReceived',coalesce((select sum(amount) from payments x where x.project_id=p.id and x.deleted_at is null),0),'expensesTotal',coalesce((select sum(amount) from expenses x where x.project_id=p.id and x.deleted_at is null),0),'createdAt',p.created_at,'updatedAt',p.updated_at,
 'stageHistory',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'fromStage',h.from_stage,'toStage',h.to_stage,'note',h.note,'changedBy',h.changed_by,'changedAt',h.changed_at) order by h.changed_at) from project_stage_history h where h.project_id=p.id),'[]'::jsonb),
 'materials',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'itemCode',m.item_code,'itemName',m.item_name,'specification',m.specification,'requiredQty',m.required_qty,'reservedQty',m.reserved_qty,'issuedQty',m.issued_qty,'unit',m.unit,'shortageQty',greatest(m.required_qty-m.reserved_qty,0))) from project_material_requirements m where m.project_id=p.id),'[]'::jsonb),
 'installationMaterials',(select details from installation_materials im where im.project_id=p.id)) payload
from projects p join districts d on d.id=p.district_id;

create or replace function public.record_security_event(p_action text,p_metadata jsonb default '{}') returns void language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null then raise exception 'Authentication required'; end if; update profiles set last_login_at=case when p_action='login' then now() else last_login_at end where id=auth.uid(); insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),p_action,'security',auth.uid(),coalesce(p_metadata,'{}')); end $$;
grant execute on function public.record_security_event(text,jsonb) to authenticated;

create or replace function public.save_customer(p_customer jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid:=coalesce(nullif(p_customer->>'id','')::uuid,gen_random_uuid()); did uuid; dname text; existing customers%rowtype; actor uuid:=auth.uid(); role app_role:=public.current_role();
begin if actor is null or role is null then raise exception 'Not authorised'; end if;
 if role='admin' then select id,name into did,dname from districts where active and name=p_customer->>'district'; else did:=current_district(); select name into dname from districts where id=did; end if;
 if did is null then raise exception 'A valid district is required'; end if;
 select * into existing from customers where id=cid;
 if found then
   if not can_access_customer(cid) then raise exception 'Not authorised'; end if;
   if (p_customer->>'rowVersion') is null or existing.row_version<>(p_customer->>'rowVersion')::bigint then raise exception 'This customer was updated by another user. Refresh and try again'; end if;
   update customers set full_name=trim(p_customer->>'fullName'),mobile=regexp_replace(p_customer->>'mobile','\D','','g'),alternate_mobile=nullif(p_customer->>'alternateMobile',''),email=nullif(lower(p_customer->>'email'),''),full_address=p_customer->>'address',village_city=p_customer->>'villageCity',taluka=nullif(p_customer->>'taluka',''),district_id=did,district_name=dname,state=coalesce(nullif(p_customer->>'state',''),'Gujarat'),pin_code=nullif(p_customer->>'pinCode',''),customer_category=p_customer->>'customerCategory',discom=p_customer->>'discom',consumer_number=nullif(p_customer->>'consumerNumber',''),sanctioned_load_kw=nullif(p_customer->>'sanctionedLoadKw','')::numeric,phase=nullif(p_customer->>'phase',''),meter_type=nullif(p_customer->>'meterType',''),average_monthly_units=nullif(p_customer->>'averageMonthlyUnits','')::numeric,average_bill=nullif(p_customer->>'averageBill','')::numeric,roof_type=nullif(p_customer->>'roofType',''),available_roof_area_sq_ft=nullif(p_customer->>'availableRoofAreaSqFt','')::numeric,gps_link=nullif(p_customer->>'gpsLink',''),dealer_id=case when role='dealer' then current_dealer() else nullif(p_customer->>'dealerId','')::uuid end,assigned_partner_id=case when role='district_partner' then actor else nullif(p_customer->>'assignedPartnerId','')::uuid end,lead_status=coalesce(nullif(p_customer->>'leadStatus',''),'New'),notes=nullif(p_customer->>'notes',''),updated_by=actor,updated_at=now(),row_version=row_version+1 where id=cid;
   insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(actor,'customer_updated','customer',cid,jsonb_build_object('previousVersion',existing.row_version));
 else
   if role='dealer' and current_dealer() is null then raise exception 'Dealer profile is incomplete'; end if;
   insert into customers(id,customer_no,full_name,mobile,alternate_mobile,email,full_address,village_city,taluka,district_id,district_name,state,pin_code,customer_category,discom,consumer_number,sanctioned_load_kw,phase,meter_type,average_monthly_units,average_bill,roof_type,available_roof_area_sq_ft,gps_link,assigned_partner_id,dealer_id,lead_status,notes,created_by,updated_by)
   values(cid,next_document_number('customer','CU'),trim(p_customer->>'fullName'),regexp_replace(p_customer->>'mobile','\D','','g'),nullif(p_customer->>'alternateMobile',''),nullif(lower(p_customer->>'email'),''),p_customer->>'address',p_customer->>'villageCity',nullif(p_customer->>'taluka',''),did,dname,coalesce(nullif(p_customer->>'state',''),'Gujarat'),nullif(p_customer->>'pinCode',''),p_customer->>'customerCategory',p_customer->>'discom',nullif(p_customer->>'consumerNumber',''),nullif(p_customer->>'sanctionedLoadKw','')::numeric,nullif(p_customer->>'phase',''),nullif(p_customer->>'meterType',''),nullif(p_customer->>'averageMonthlyUnits','')::numeric,nullif(p_customer->>'averageBill','')::numeric,nullif(p_customer->>'roofType',''),nullif(p_customer->>'availableRoofAreaSqFt','')::numeric,nullif(p_customer->>'gpsLink',''),case when role='district_partner' then actor else nullif(p_customer->>'assignedPartnerId','')::uuid end,case when role='dealer' then current_dealer() else nullif(p_customer->>'dealerId','')::uuid end,coalesce(nullif(p_customer->>'leadStatus',''),'New'),nullif(p_customer->>'notes',''),actor,actor);
   insert into audit_logs(actor_id,action,entity_type,entity_id) values(actor,'customer_created','customer',cid);
 end if; return cid;
exception when unique_violation then raise exception 'Duplicate mobile number or DISCOM consumer number'; end $$;
grant execute on function public.save_customer(jsonb) to authenticated;

create or replace function public.archive_customer(p_customer_id uuid,p_reason text) returns void language plpgsql security definer set search_path=public as $$
begin if public.current_role() not in('admin','district_partner') or not can_access_customer(p_customer_id) or nullif(trim(p_reason),'') is null then raise exception 'Not authorised or archive reason missing'; end if; update customers set archived_at=now(),archived_by=auth.uid(),archive_reason=p_reason,updated_by=auth.uid(),updated_at=now(),row_version=row_version+1 where id=p_customer_id; insert into audit_logs(actor_id,action,entity_type,entity_id,reason) values(auth.uid(),'customer_archived','customer',p_customer_id,p_reason); end $$;
grant execute on function public.archive_customer(uuid,text) to authenticated;

create or replace function public.save_dealer(p_dealer jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare did uuid; id_ uuid:=coalesce(nullif(p_dealer->>'id','')::uuid,gen_random_uuid());
begin if not is_admin() then raise exception 'Admin access required'; end if; did:=coalesce(nullif(p_dealer->>'districtId','')::uuid,(select id from districts where name=p_dealer->>'district'));
 insert into dealers(id,dealer_no,name,mobile,email,address,district_id,login_user_id,default_commission_type,default_commission_value,active,created_by,updated_by) values(id_,next_document_number('dealer','DL'),p_dealer->>'name',regexp_replace(p_dealer->>'mobile','\D','','g'),nullif(p_dealer->>'email',''),nullif(p_dealer->>'address',''),did,nullif(p_dealer->>'loginUserId','')::uuid,p_dealer->>'commissionType',(p_dealer->>'commissionValue')::numeric,coalesce((p_dealer->>'active')::boolean,true),auth.uid(),auth.uid())
 on conflict(id) do update set name=excluded.name,mobile=excluded.mobile,email=excluded.email,address=excluded.address,district_id=excluded.district_id,login_user_id=excluded.login_user_id,default_commission_type=excluded.default_commission_type,default_commission_value=excluded.default_commission_value,active=excluded.active,updated_by=auth.uid(),updated_at=now();
 insert into audit_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'dealer_saved','dealer',id_); return id_; end $$;
grant execute on function public.save_dealer(jsonb) to authenticated;

create or replace function public.publish_price_row(p_row jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare list_id uuid:=gen_random_uuid(); item_id uuid:=gen_random_uuid(); ver int;
begin if not is_admin() then raise exception 'Admin access required'; end if; select coalesce(max(version_no),0)+1 into ver from price_lists where name='Manual Price Configuration';
 insert into price_lists(id,name,version_no,effective_from,status,source_document,created_by,published_by,published_at) values(list_id,'Manual Price Configuration',ver,(p_row->>'effectiveFrom')::date,'published',p_row->>'sourceDocument',auth.uid(),auth.uid(),now());
 insert into price_list_items(id,price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active) values(item_id,list_id,upper(p_row->>'panelBrand'),p_row->>'panelTechnology',(p_row->>'panelWattage')::int,(p_row->>'panelQuantity')::int,(p_row->>'capacityKw')::numeric,(p_row->>'price')::numeric,nullif(p_row->>'expectedSubsidy','')::numeric,nullif(p_row->>'afterSubsidy','')::numeric,true);
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'price_published','price_list_item',item_id,p_row); return item_id; end $$;
grant execute on function public.publish_price_row(jsonb) to authenticated;
commit;
