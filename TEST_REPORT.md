# Test Report — Final v8

Final verification date: 20/07/2026 (Asia/Kolkata)

- TypeScript typecheck: passed
- ESLint with zero warnings: passed
- Vitest: 9 files, 31 tests passed
- Ordered SQL verification: 12 migrations, 34 required tables and security guards passed
- Production Vite build: passed
- Area Partner RLS hardened to `assigned_partner_id`; partners sharing an area do not automatically share customers
- Password recovery now opens an in-app strong-password completion screen
- Gemini server-side importer with optional OpenAI fallback
- Exact two-page vector quotation PDF based on the supplied Word reference
- Single-page vector tax invoice with separately configurable supply and installation GST lines
- Invoice issuance supports `GST Included` reverse-calculation and `GST Extra` addition above the accepted quotation
- Intrastate lines split independently into CGST and SGST; interstate lines use IGST
- Accepted quotation amount, tax treatment, line values and final invoice total are stored in the immutable snapshot
- Supply/installation allocation shares must total 100%; both rates and HSN/SAC values are effective-dated and Admin-editable
- One-time owner-authorised reset SQL supplied for quotations, projects and customer invoices

Automated checks are run with `npm run typecheck`, `npm run lint`, `npm test`, `npm run verify:sql` and `npm run build`.

Final local result on 20 July 2026: 31/31 tests passed; TypeScript, ESLint, SQL verification and the production Vite build completed successfully.

Coverage includes capacity, GST-inclusive and GST-extra 70/30 calculations, line-level CGST/SGST, effective-dated subsidy eligibility, Indian amount words, editable settings/number previews, role permissions, valid/invalid project transitions, material reservation/shortage, the 97-row 06.06.2026 price source, wattage range preservation, exact two-page quotation PDF, one-page included/extra invoice PDFs and `.xlsx` workbook headings/totals. SQL tests inspect required tables, exact role enum, RLS, secured settings/material operations, private project access and duplicate guards.

Production acceptance still requires a disposable connected Supabase project for `supabase test db`, role-by-role live RLS checks, Edge Function secrets, email confirmation/password reset delivery, AI provider calls, private file signed URLs and clean A4 quotation/invoice PDF verification. Record the project/date/results before go-live; do not represent an offline build as live-environment verification.
