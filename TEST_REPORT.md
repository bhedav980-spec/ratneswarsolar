# Test Report — Invoice Signature Update

Final verification date: 07/08/2026 (Asia/Kolkata)

- TypeScript typecheck: passed
- ESLint with zero warnings: passed
- Vitest: 16 files, 58 tests passed
- Ordered SQL verification: 22 migrations, 35 required tables and security guards passed
- Production Vite build: passed
- Project and manual invoice forms default to `With Digital Stamp & Signature` and expose a deliberate unsigned option
- Exact Quotation/Feasibility signature asset reused without raster recapture or quality loss
- Signed and unsigned invoice snapshots preserve the selected choice for later reprints
- Poppler visual QA: signed and unsigned outputs are one A4 page each, with no clipping, overlap or blank page
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
- Main invoice item table verified with five columns only: Sl No., Particulars, HSN/SAC, Quantity and Amount
- Invoice metadata now shows dynamic Place of Supply and a neutral Destination dash; the obsolete GST-treatment label is not printed
- Embedded document fonts keep the downloaded A4 PDF sharp and selectable; main item-row separators use thin professional rules
- Invoice footer no longer exposes internal invoice/project/customer reference codes
- Intrastate line rounding is balanced across CGST and SGST totals whenever the invoice tax permits an equal paise split
- Tax summary prints `SGST` only and uses merged-header-aware divider lines with no text collisions
- Editing a previously generated feasibility report now uses the existing quotation-linked row instead of attempting a duplicate insert
- Quotation status updates are idempotent, double-click protected and expose only transitions accepted by the database workflow
- An existing Feasibility record with a missing/reset Project now updates the same record and recreates exactly one linked Project atomically
- Invoice issuance is retry-safe for an already-issued response, same-project installation serials and corrected reissues after cancellation; backend errors display inside the invoice modal
- Mobile dialogs use the dynamic viewport, retain touch scrolling and keep Feasibility save/download actions visible above phone browser controls and safe areas
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

Final local result after the optional invoice signature update: 58/58 tests passed; TypeScript, ESLint, ordered SQL verification and the production Vite build completed successfully. Project invoices and manual invoices use the same one-page A4 vector invoice engine. Signed and unsigned invoice renders were visually inspected at A4 size. The generated Agreement DOCX remains exactly four pages. The updated Feasibility PDF remains one A4 page, and the quotation remains exactly two A4 pages.

Coverage includes capacity, nearest official price-row matching, the final 57-row five-PDF source, GST-inclusive and GST-extra 70/30 calculations, line-level CGST/SGST, Indian amount words, editable settings/number previews, role permissions, valid/invalid project transitions, material reservation/shortage, audited invoice cancellation/project cleanup, exact two-page quotation PDF, one-page included/extra invoice PDFs and `.xlsx` workbook headings/totals. SQL tests inspect required tables, exact role enum, RLS, secured settings/material operations, private project access and duplicate guards.

Production acceptance still requires a disposable connected Supabase project for `supabase test db`, role-by-role live RLS checks, Edge Function secrets, email confirmation/password reset delivery, AI provider calls, private file signed URLs and clean A4 quotation/invoice PDF verification. Record the project/date/results before go-live; do not represent an offline build as live-environment verification.
