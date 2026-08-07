begin;

-- Preserve the user's signed/unsigned invoice choice in the immutable invoice
-- snapshot. Existing invoices without this key remain signed by default in the UI.
create or replace function public.attach_invoice_signature_preference() returns trigger
language plpgsql security definer set search_path=public as $$
declare
 include_signature boolean;
begin
 select coalesce((details->>'includeSignature')::boolean,true)
 into include_signature
 from public.installation_materials
 where project_id=new.project_id;

 new.snapshot:=jsonb_set(
  coalesce(new.snapshot,'{}'::jsonb),
  '{includeSignature}',
  to_jsonb(coalesce(include_signature,true)),
  true
 );
 return new;
end $$;

drop trigger if exists customer_invoice_signature_preference on public.customer_invoices;
create trigger customer_invoice_signature_preference
before insert on public.customer_invoices
for each row execute function public.attach_invoice_signature_preference();

commit;
