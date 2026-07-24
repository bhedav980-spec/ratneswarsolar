# Test Report — Final v14

Final verification date: 24/07/2026 (Asia/Kolkata)

- TypeScript typecheck: passed
- ESLint with zero warnings: passed
- Vitest: 15 files, 50 tests passed
- Ordered SQL verification: 18 migrations, 35 required tables and security guards passed
- Production Vite build: passed
- Quote-linked financial-year Bill Number tests: passed
- Admin-only persistent Manual Invoice create/view/print/cancel flow: passed
- Active Customer UI contains no Site Survey action or form
- Area Partner RLS hardened to `assigned_partner_id`; partners sharing an area do not automatically share customers
- Password recovery now opens an in-app strong-password completion screen
- Gemini server-side importer with optional OpenAI fallback
- Exact two-page vector quotation PDF based on the supplied Word reference
- Exact four-page editable Annexure-2 Agreement DOCX with customer signature area blank and vendor signature/stamp preserved
- One-page selectable/vector Vendor Feasibility PDF with mandatory application reference and optional `__` fields
- Database-enforced Approved → Agreement → Feasibility → Project workflow gate
- Single-page vector tax invoice with separately configurable supply and installation GST lines
- Invoice issuance supports `GST Included` reverse-calculation and `GST Extra` addition above the accepted quotation
- Intrastate lines split independently into CGST and SGST; interstate lines use IGST
- Accepted quotation amount, tax treatment, line values and final invoice total are stored in the immutable snapshot
- Supply/installation allocation shares must total 100%; both rates and HSN/SAC values are effective-dated and Admin-editable
- One-time owner-authorised reset SQL supplied for quotations, projects and customer invoices
- Internal official-price selection with audited manual panel quantity, wattage and exact kW overrides
- All 57 rows from the five supplied official price PDFs validated, including WAAREE 540 and 5 W range options
- Required-kW matching selects the nearest valid panel-count row without price interpolation
- Optional editable loan gross-up formula and file charge with saved immutable commercial snapshot
- Standard subsidy information printed on every quotation without changing the gross quotation value
- Fixed dealer commission and manual dealer creation for Admin/Area Partner quotations
- Multi-row material/truck receipt entry with derived unit rate and atomic stock-in posting

Automated checks are run with `npm run typecheck`, `npm run lint`, `npm test`, `npm run verify:sql` and `npm run build`.

Final local result on 24 July 2026: 50/50 tests passed; TypeScript, ESLint, 18-migration SQL verification and the production Vite build completed successfully. The compact six-stage workflow mapping, optional loan branch and legacy-stage compatibility tests passed. Project invoices and manual invoices use the same A4 vector invoice engine. The generated Agreement DOCX remains exactly four pages. The updated Feasibility PDF remains one A4 page, and the quotation remains exactly two A4 pages.

Coverage includes capacity, nearest official price-row matching, the final 57-row five-PDF source, GST-inclusive and GST-extra 70/30 calculations, line-level CGST/SGST, Indian amount words, editable settings/number previews, role permissions, valid/invalid project transitions, material reservation/shortage, audited invoice cancellation/project cleanup, exact two-page quotation PDF, one-page included/extra invoice PDFs and `.xlsx` workbook headings/totals. SQL tests inspect required tables, exact role enum, RLS, secured settings/material operations, private project access and duplicate guards.

Production acceptance still requires a disposable connected Supabase project for `supabase test db`, role-by-role live RLS checks, Edge Function secrets, email confirmation/password reset delivery, AI provider calls, private file signed URLs and clean A4 quotation/invoice PDF verification. Record the project/date/results before go-live; do not represent an offline build as live-environment verification.
