begin;

-- Preserve the source document's wattage ranges without changing historic quotation keys.
alter table public.price_list_items add column if not exists panel_wattage_min integer;
alter table public.price_list_items add column if not exists panel_wattage_max integer;
alter table public.price_list_items add column if not exists panel_wattage_label text;

create or replace view public.active_price_rows with (security_invoker=true) as
select distinct on(i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity)
 i.id,i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity,i.dc_capacity_kw,i.gross_price,i.expected_subsidy,i.after_subsidy,i.active,
 l.effective_from,l.version_no,l.source_document,
 coalesce(i.panel_wattage_min,i.panel_wattage) panel_wattage_min,
 coalesce(i.panel_wattage_max,i.panel_wattage) panel_wattage_max,
 coalesce(i.panel_wattage_label,format('%s Wp',i.panel_wattage)) panel_wattage_label
from public.price_list_items i
join public.price_lists l on l.id=i.price_list_id
where i.active and l.status='published' and l.effective_from<=current_date
order by i.panel_brand,i.panel_technology,i.panel_wattage,i.panel_quantity,l.effective_from desc,l.version_no desc;

create or replace function public.publish_price_row(p_row jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare list_id uuid:=gen_random_uuid(); item_id uuid:=gen_random_uuid(); ver int;
begin
 if not is_admin() then raise exception 'Admin access required'; end if;
 select coalesce(max(version_no),0)+1 into ver from price_lists where name='Manual Price Configuration';
 insert into price_lists(id,name,version_no,effective_from,status,source_document,created_by,published_by,published_at)
 values(list_id,'Manual Price Configuration',ver,(p_row->>'effectiveFrom')::date,'published',p_row->>'sourceDocument',auth.uid(),auth.uid(),now());
 insert into price_list_items(id,price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy,active)
 values(item_id,list_id,upper(p_row->>'panelBrand'),p_row->>'panelTechnology',(p_row->>'panelWattage')::int,
  coalesce(nullif(p_row->>'panelWattageMin','')::int,(p_row->>'panelWattage')::int),
  coalesce(nullif(p_row->>'panelWattageMax','')::int,(p_row->>'panelWattage')::int),
  coalesce(nullif(p_row->>'panelWattageLabel',''),format('%s Wp',p_row->>'panelWattage')),
  (p_row->>'panelQuantity')::int,(p_row->>'capacityKw')::numeric,(p_row->>'price')::numeric,
  nullif(p_row->>'expectedSubsidy','')::numeric,nullif(p_row->>'afterSubsidy','')::numeric,true);
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'price_published','price_list_item',item_id,p_row);
 return item_id;
end $$;
grant execute on function public.publish_price_row(jsonb) to authenticated;

do $$
declare
 list_id uuid;
 row_count integer;
begin
 insert into public.price_lists(name,version_no,effective_from,status,source_document,published_at)
 values('Residential Solar Rooftop Master Price List',1,date '2026-07-17','published','Price List_Residential_Solar_Rooftop(2).pdf · Source dated 06.06.2026',now())
 on conflict(name,version_no) do update set effective_from=excluded.effective_from,status='published',source_document=excluded.source_document,published_at=now()
 returning id into list_id;

 update public.price_lists set status='inactive' where status='published' and id<>list_id;
 update public.price_list_items set active=false where price_list_id=list_id;

 insert into public.price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_wattage_min,panel_wattage_max,panel_wattage_label,panel_quantity,dc_capacity_kw,gross_price,active) values
 -- BIFACIAL 530-550 WP: exact capacities and prices from page 1.
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',4,2.180,124540,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',5,2.725,146175,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',6,3.270,171310,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',7,3.815,184945,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',8,4.360,208840,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',9,4.905,249715,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',10,5.450,267910,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',11,5.995,298985,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',12,6.540,324620,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',13,7.085,346255,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',14,7.630,367890,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',15,8.175,385125,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',16,8.720,406160,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',17,9.265,429295,true),
 (list_id,'ADANI','Bifacial',545,530,550,'530–550 Wp',18,9.810,453430,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',4,2.180,122740,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',5,2.725,145050,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',6,3.270,167460,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',7,3.815,180570,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',8,4.360,202880,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',9,4.905,243240,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',10,5.450,260700,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',11,5.995,291110,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',12,6.540,315720,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',13,7.085,336630,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',14,7.630,357740,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',15,8.175,373550,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',16,8.720,393860,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',17,9.265,416070,true),
 (list_id,'WAAREE','Bifacial',545,530,550,'530–550 Wp',18,9.810,440180,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',4,2.180,116140,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',5,2.725,136800,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',6,3.270,157560,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',7,3.815,169020,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',8,4.360,189680,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',9,4.905,228390,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',10,5.450,244200,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',11,5.995,272960,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',12,6.540,295920,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',13,7.085,315180,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',14,7.630,334640,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',15,8.175,348800,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',16,8.720,367460,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',17,9.265,388020,true),
 (list_id,'APS','Bifacial',545,530,550,'530–550 Wp',18,9.810,410480,true),
 -- TOPCON PAHAL 600 W.
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',4,2.400,124300,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',5,3.000,151500,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',6,3.600,172700,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',7,4.200,192400,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',8,4.800,210600,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',9,5.400,236800,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',10,6.000,262600,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',11,6.600,306700,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',12,7.200,334400,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',13,7.800,352100,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',14,8.400,379300,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',15,9.000,396500,true),
 (list_id,'PAHAL','TOPCon',600,600,600,'600 Wp',16,9.600,419200,true),
 -- TOPCON ADANI 605-620 W; capacities follow the source's 620 W column.
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',4,2.480,138040,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',5,3.100,161700,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',6,3.720,183860,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',7,4.340,221020,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',8,4.960,258880,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',9,5.580,276740,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',10,6.200,308600,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',11,6.820,343960,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',12,7.440,300820,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',13,8.060,420480,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',14,8.680,445640,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',15,9.300,473900,true),
 (list_id,'ADANI','TOPCon',620,605,620,'605–620 Wp',16,9.920,511060,true),
 -- TOPCON WAAREE 570-580 W.
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',4,2.320,125640,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',5,2.900,148400,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',6,3.480,172360,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',7,4.060,198120,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',8,4.640,219280,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',9,5.220,249940,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',10,5.800,265100,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',11,6.380,317760,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',12,6.960,339920,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',13,7.540,361780,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',14,8.120,383480,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',15,8.700,405900,true),
 (list_id,'WAAREE','TOPCon',580,570,580,'570–580 Wp',16,9.280,420560,true),
 -- TOPCON APS: source heading is 580 W; exact source-listed capacities are retained.
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',4,2.400,118440,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',5,3.000,139400,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',6,3.600,161560,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',7,4.200,185520,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',8,4.800,204880,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',9,5.400,233740,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',10,6.000,247100,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',11,6.600,297960,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',12,7.200,318320,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',13,7.800,338380,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',14,8.400,358280,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',15,9.000,378900,true),
 (list_id,'APS','TOPCon',580,580,580,'580 Wp',16,9.600,391760,true)
 on conflict(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity)
 do update set panel_wattage_min=excluded.panel_wattage_min,panel_wattage_max=excluded.panel_wattage_max,panel_wattage_label=excluded.panel_wattage_label,dc_capacity_kw=excluded.dc_capacity_kw,gross_price=excluded.gross_price,expected_subsidy=null,after_subsidy=null,active=true;

 select count(*) into row_count from public.price_list_items where price_list_id=list_id and active;
 if row_count<>97 then raise exception 'Residential master price list must contain 97 active configurations; found %',row_count; end if;
end $$;

commit;
