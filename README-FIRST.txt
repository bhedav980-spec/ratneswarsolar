RATNESWAR SOLAR CRM - FINAL V13

EXISTING DEPLOYMENT
1. Back up Supabase.
2. Follow FINAL_V13_DEPLOYMENT.md exactly.
3. If v12 is already deployed, run only supabase/migrations/202607230017_quote_linked_and_manual_invoices.sql once in Supabase SQL Editor.
4. Push the complete v13 source to GitHub.
5. Wait for Vercel Ready, sign out, press Ctrl+Shift+R, and sign in.

NEW SUPABASE PROJECT
Run supabase/SETUP.sql once, then follow SUPABASE_SETUP.md and ADMIN_FIRST_LOGIN.md.

IMPORTANT
- Keep every SQL migration file in GitHub; do not delete it after running.
- Do not run any reset SQL for this v13 update.
- The quotation price list is GST-inclusive and comes from the five supplied official PDFs.
- The source row is matched internally; the user selects panel details and required kW.
- Project creation now requires Approved Quotation → Agreement DOCX → Feasibility PDF.

VERIFIED ON 23/07/2026
- TypeScript passed
- ESLint passed with zero warnings
- 48/48 tests passed
- 17 ordered SQL migrations verified
- Production build passed
- Quotation is exactly two selectable-text A4 pages
- Included and GST-extra invoice PDFs are each exactly one selectable-text A4 page
- Agreement DOCX remains exactly four pages; editable Feasibility PDF is exactly one selectable-text A4 page
