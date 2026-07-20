RATNESWAR SOLAR CRM - FINAL V8

MAIN UPDATE
- Invoice creation now asks whether GST is included in the quotation or must be added above it.
- Requested initial split rule: 70% Supply at 5% and 30% Installation at 18%.
- Intrastate invoices show separate CGST and SGST for each line; interstate invoices show IGST.
- The accepted quotation amount, selected treatment, taxable values, tax and final total are locked into the issued invoice snapshot.
- Downloaded invoice remains a sharp, selectable, single-page A4 vector PDF.

EXISTING DEPLOYMENT
1. Back up Supabase.
2. Follow FINAL_V9_DEPLOYMENT.md.
3. Run supabase/migrations/202607200012_invoice_gst_treatment_and_standard_split.sql in Supabase SQL Editor.
4. Push the complete v9 source to GitHub.
5. Wait for Vercel Ready, then press Ctrl+Shift+R.

NEW SUPABASE PROJECT
Run supabase/SETUP.sql once, then follow SUPABASE_SETUP.md and ADMIN_FIRST_LOGIN.md.

IMPORTANT
- Keep SQL migration files in GitHub; do not delete them after running.
- Do not run the one-time reset SQL for this v9 update.
- Confirm the current legally applicable GST rates with your GST adviser before issuing a production invoice.

VERIFIED ON 20/07/2026
- TypeScript passed
- ESLint passed with zero warnings
- 31/31 tests passed
- 12 ordered SQL migrations verified
- Production build passed
- Included and GST-extra invoice PDFs are each exactly one A4 page with selectable text
