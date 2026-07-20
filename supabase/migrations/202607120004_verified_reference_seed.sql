begin;
insert into public.districts(code,name) values ('KUT','Kutch'),('JUN','Junagadh'),('RAJ','Rajkot'),('AHM','Ahmedabad'),('JAM','Jamnagar'),('MOR','Morbi') on conflict do nothing;
insert into public.inverter_products(brand,model,capacity_kw,created_by) values ('KSOLE','',null,null),('Solaryan','',null,null),('Suryyan','',null,null),('Polycab','',null,null) on conflict do nothing;

do $$declare l580 uuid:=gen_random_uuid();l610 uuid:=gen_random_uuid();begin
insert into price_lists(id,name,version_no,effective_from,status,source_document,published_at) values
 (l580,'Waaree TOPCon 580 W Official',1,date '2026-07-12','published','Ratneswar_WAREE_TOPCORN_580WP.pdf',now()),
 (l610,'Waaree TOPCon 610/615 W Official',1,date '2026-07-12','published','Ratneswar_WAREE_TOPCORN_610-615WP.pdf',now());
insert into price_list_items(price_list_id,panel_brand,panel_technology,panel_wattage,panel_quantity,dc_capacity_kw,gross_price,expected_subsidy,after_subsidy) values
 (l580,'WAAREE','TOPCon',580,4,2.320,124129,65760,58369),(l580,'WAAREE','TOPCon',580,5,2.900,149076,76200,72876),(l580,'WAAREE','TOPCon',580,6,3.480,174023,78000,96023),(l580,'WAAREE','TOPCon',580,7,4.060,203010,78000,125010),(l580,'WAAREE','TOPCon',580,8,4.640,226442,78000,148442),(l580,'WAAREE','TOPCon',580,9,5.220,255934,78000,177934),(l580,'WAAREE','TOPCon',580,10,5.800,277851,78000,199851),(l580,'WAAREE','TOPCon',580,12,6.960,352187,78000,274187),(l580,'WAAREE','TOPCon',580,14,8.120,398950,78000,320950),(l580,'WAAREE','TOPCon',580,17,9.860,472276,78000,394276),(l580,'WAAREE','TOPCon',580,18,10.440,494294,78000,416294),
 (l610,'WAAREE','TOPCon',610,4,2.440,129381,67920,61461),(l610,'WAAREE','TOPCon',615,4,2.460,129381,68280,61101),
 (l610,'WAAREE','TOPCon',610,5,3.050,155742,78000,77742),(l610,'WAAREE','TOPCon',615,5,3.075,155742,78000,77742),(l610,'WAAREE','TOPCon',610,6,3.660,178972,78000,100972),(l610,'WAAREE','TOPCon',615,6,3.690,178972,78000,100972),(l610,'WAAREE','TOPCon',610,7,4.270,212302,78000,134302),(l610,'WAAREE','TOPCon',615,7,4.305,212302,78000,134302),(l610,'WAAREE','TOPCon',610,8,4.880,242198,78000,164198),(l610,'WAAREE','TOPCon',615,8,4.920,242198,78000,164198),(l610,'WAAREE','TOPCon',610,9,5.490,267751,78000,189751),(l610,'WAAREE','TOPCon',615,9,5.535,267751,78000,189751),(l610,'WAAREE','TOPCon',610,10,6.100,315019,78000,237019),(l610,'WAAREE','TOPCon',615,10,6.150,315019,78000,237019),(l610,'WAAREE','TOPCon',610,12,7.320,368044,78000,290044),(l610,'WAAREE','TOPCon',615,12,7.380,368044,78000,290044),(l610,'WAAREE','TOPCon',610,14,8.540,417534,78000,339534),(l610,'WAAREE','TOPCon',615,14,8.610,417534,78000,339534),(l610,'WAAREE','TOPCon',610,16,9.760,471468,78000,393468),(l610,'WAAREE','TOPCon',615,16,9.840,471468,78000,393468),(l610,'WAAREE','TOPCon',610,17,10.370,494698,78000,416698),(l610,'WAAREE','TOPCon',615,17,10.455,494698,78000,416698);
end$$;
insert into company_settings(key,value) values
 ('company.profile','{"name":"Ratneswar Engineering","gstin":"24ABKFR8021K1ZZ","address":"Office No. 19, Sanghvi Square Complex, Salarinaka, Rapar-Kutch, Gujarat 370165","timezone":"Asia/Kolkata"}'::jsonb),
 ('company.bank','{"accountName":"Ratneswar Engineering","bankName":"HDFC Bank","accountNumber":"99900019052018","ifsc":"HDFC0002295","branch":"Rapar Branch, Kutch"}'::jsonb),
 ('security.inactivity_minutes','{"minutes":30}'::jsonb),('security.minimum_password_length','{"length":12}'::jsonb)
on conflict(key) do nothing;
commit;
