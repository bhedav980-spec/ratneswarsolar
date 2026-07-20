-- Run after SETUP.sql. All result columns should be true/zero as labelled.
select array_agg(enumlabel order by enumsortorder)=array['admin','district_partner','dealer'] as exact_three_roles from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='app_role';
select count(*)=0 as no_anon_business_grants from information_schema.role_table_grants where grantee='anon' and table_schema='public' and privilege_type in('SELECT','INSERT','UPDATE','DELETE');
select bool_and(relrowsecurity) as all_business_tables_have_rls from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r';
select count(*)=5 as five_private_buckets from storage.buckets where id in('customer-documents','agreement-files','project-files','invoice-files','inventory-invoices') and not public;
select count(*)=33 as recovered_waaree_topcon_rows from public.active_price_rows where panel_brand='WAAREE' and panel_technology='TOPCon' and source_document in('Ratneswar_WAREE_TOPCORN_580WP.pdf','Ratneswar_WAREE_TOPCORN_610-615WP.pdf');
select count(*) as active_tax_rules_must_be_configured_before_invoice from public.tax_rules where active and effective_from<=current_date and (effective_to is null or effective_to>=current_date);
