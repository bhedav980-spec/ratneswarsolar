RATNESWAR SOLAR CRM - FINAL V10

EXISTING DEPLOYMENT
1. Back up Supabase.
2. Follow FINAL_V10_DEPLOYMENT.md exactly.
3. Run supabase/migrations/202607200014_official_price_match_and_project_cleanup.sql once in Supabase SQL Editor.
4. Push the complete v10 source to GitHub.
5. Wait for Vercel Ready, sign out, press Ctrl+Shift+R, and sign in.

NEW SUPABASE PROJECT
Run supabase/SETUP.sql once, then follow SUPABASE_SETUP.md and ADMIN_FIRST_LOGIN.md.

IMPORTANT
- Keep every SQL migration file in GitHub; do not delete it after running.
- Do not run the one-time reset SQL for this v10 update.
- The quotation price list is GST-inclusive and comes from the five supplied official PDFs.
- The source row is matched internally; the user selects panel details and required kW.
- Cancel an issued test invoice before deleting its erroneous project.

VERIFIED ON 20/07/2026
- TypeScript passed
- ESLint passed with zero warnings
- 38/38 tests passed
- 14 ordered SQL migrations verified
- Production build passed
- Quotation is exactly two selectable-text A4 pages
- Included and GST-extra invoice PDFs are each exactly one selectable-text A4 page
