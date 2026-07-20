# Final Release Notes

## What changed

- Mandatory authenticator/TOTP was removed. Sign-in now uses verified Supabase email/password, strong password policy, role-based RLS, active-account checks, audit events, password reset and 30-minute idle logout.
- The Agreement module and all agreement-generation UI/code were removed.
- Approving a sent or pending quotation now creates the project atomically.
- A dedicated Invoices module is visible to Admin and District Partner users.
- Invoice generation remains available at every workflow stage after installation is completed.
- Quotation and tax invoice layouts were rebuilt for A4 and produce a clean PDF containing only the selected document.
- Customer rows now show an explicit **Delete** action for Admin and District Partner. It performs an audited soft delete so linked history is not destroyed.
- The final active price master contains the 57 exact configurations read from the five supplied official PDFs; older source lists remain only as migration history and are inactive.
- Quotation and invoice documents now follow the supplied `QuoteInvoiceTemplates.jsx` reference design while retaining clean A4 PDF generation.
- Invitation and password-reset links now require the deployed HTTPS application URL and reject localhost.
- Admin can create a verified login manually with a strong temporary password or send an email invitation.
- Multiple District Partners may be assigned to the same district; RLS still restricts every partner to that district.
- Company, bank, HSN/SAC, footer, idle timeout, quotation defaults and quotation/invoice numbering are editable in Administration.
- New quotation and invoice numbers may be typed manually or generated from the Admin-configured next number.
- Inventory item masters can be edited or safely archived, while project material requirements can be added, edited or removed with an audited reason.

## Upgrade an existing deployment

1. Back up the database.
2. If not already applied, run `supabase/migrations/202607160005_simplify_project_invoice_flow.sql`.
3. Run `supabase/migrations/202607170006_residential_price_list_source_ranges.sql` to publish the 97-row master price list.
4. Run `supabase/migrations/202607170007_operational_controls_and_settings.sql`.
5. Set `APP_URL` to the deployed HTTPS CRM URL, configure the same Supabase Auth Site/Redirect URL, and deploy `admin-users` and `document-importer` Edge Functions. The old `document-generator` function is no longer used.
6. Run `npm install`, set the existing `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`, then deploy the output of `npm run build`.
7. In Supabase Auth, keep email confirmation, password rules, leaked-password protection and rate limits enabled. TOTP can remain optional or disabled.

For a new database, run `supabase/SETUP.sql`, then migrations `202607170006_residential_price_list_source_ranges.sql` and `202607170007_operational_controls_and_settings.sql` in order (or use `supabase db push`).
# Final v8 — Dual GST Treatment Invoice Engine

- Added an invoice-time choice between GST included in the accepted quotation and GST added above it.
- Added the requested effective-dated 70% Supply / 30% Installation configuration with separate 5% / 18% rates.
- Added per-line CGST + SGST or IGST calculations, immutable quotation-base/treatment snapshots and matching UI/PDF totals.
- Added single-page A4 vector PDF tests for both treatments.
- Added migration `202607200012_invoice_gst_treatment_and_standard_split.sql` and a complete existing-production deployment guide.

# Final v9 — Editable Quotations, Loan Pricing and Material Receipts

- Added verified automatic pricing plus audited manual panel wattage, quantity and exact DC capacity edits.
- Limited WAAREE source choices to the verified 540 Wp and 580 Wp categories.
- Made inverter brand/model/capacity and every BOM row editable; Online Monitoring System wording is standardised.
- Added optional editable loan pricing using `base / (1 - gross-up %) + file charge`, with defaults of 10% and ₹2,000.
- Made the reference subsidy table informational on every quotation; it never changes the quotation total.
- Added existing-or-manual dealer selection with fixed commission amount and Dealer Master creation.
- Replaced single-line manual stock entry with multi-material truck/receipt entry using quantity and total lot value.
- Added migration `202607200013_manual_quote_loan_dealer_receipts.sql`.

# Final v10 — Official Price Matching and Project Cleanup

- Replaced the visible source-row selector with internal price matching by brand, technology, selected wattage and nearest valid panel quantity.
- Published the verified 57-row active price set from WAAREE 540, WAAREE 580, WAAREE 610/615, ADANI 550 and ADANI 610/615/620/625 PDFs.
- Added every verified 5 W option within combined source ranges without inventing prices or interpolating between quantity rows.
- Removed “Informational” and the authority-approval note from the customer quotation subsidy section.
- Added an audited Admin `Cancel Invoice` action and safe deletion of a cancelled invoice with its erroneous project.
- Kept project cleanup accessible when the linked customer was already archived.
- Added migration `202607200014_official_price_match_and_project_cleanup.sql` and `FINAL_V10_DEPLOYMENT.md`.
