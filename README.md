# Ratneswar Engineering Solar EPC CRM

Production React/TypeScript and Supabase CRM for customer intake, OCR-assisted imports, exact GST-inclusive quotations, editable Word agreements, vendor feasibility reports, gated project creation, project workflow, inventory, installation serials, tax invoices, dealer commissions, audit logs and Excel reports.

Final v11 adds the approved quotation → editable Agreement DOCX → one-page Feasibility PDF → Project Created gate. Agreement output preserves the supplied legal template and Ratneswar signature/stamp while replacing only the quote date and customer party fields. Feasibility uses quote/customer data, requires the application reference number, keeps Jan Samarth/DISCOM optional, and creates the project atomically only after both documents are ready.

The production build has no demo mode, localStorage business database, PIN login or demo operational data. Supabase PostgreSQL is authoritative and all business tables use RLS.

## Quick start

1. For a new Supabase project, read `SUPABASE_SETUP.md` and run the complete `supabase/SETUP.sql`. For the existing deployed project, follow `FINAL_V11_DEPLOYMENT.md` exactly.
2. Follow `ADMIN_FIRST_LOGIN.md` to create and promote the first Admin.
3. Copy `.env.example` to `.env.local` and set the project URL and publishable anon key.
4. Deploy the two Edge Functions and add server-only secrets as described in `DEPLOYMENT.md`.
5. Run:

```bash
npm install
npm run typecheck
npm run lint
npm test
npm run verify:sql
npm run build
```

## Security model

The only business roles are `admin`, `district_partner` and `dealer`. Sign-in uses Supabase email/password at no separate authenticator cost, with verified email, a 12-character password policy, active-account checks, automatic idle logout, login audit events, rate limits and password reset. RLS applies district and dealer boundaries independently of hidden navigation. Private documents use expiring signed URLs. Service-role and AI keys exist only in Edge Function secrets.

Quotation and invoice previews create a clean A4 PDF before printing. This prevents browser date, time and URL headers/footers from entering the business document.

For the exact existing-deployment sequence, start with `FINAL_V11_DEPLOYMENT.md`. See `ROLE_PERMISSION_MATRIX.md`, `DATABASE_SCHEMA.md`, `TEST_REPORT.md` and `BACKUP_AND_ROLLBACK.md` for production operations.
