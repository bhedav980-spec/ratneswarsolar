# Supabase Setup

1. Create a new Supabase project and record its Project URL and publishable anon key.
2. Open SQL Editor, create a new query, paste all of `supabase/SETUP.sql`, and run it once. It already contains every ordered migration through v10; do not run the individual migrations again on a new project. Supabase CLI users may run `supabase db push` instead.
3. Confirm every migration committed without error. Run `supabase/verification.sql`; every query must return the documented result.
4. In Authentication → Providers → Email, enable email confirmation.
5. In Authentication → Security, set a strong password policy (minimum 12 characters, upper/lowercase, number and symbol), enable leaked-password protection where available, and retain platform rate limits. TOTP is optional and is not required by this CRM.
6. In Authentication → URL Configuration, set the deployed HTTPS production Site URL and add `https://YOUR_PRODUCTION_DOMAIN/**` as a Redirect URL. Do not retain localhost in the production project.
7. Do not create public buckets. The SQL creates private business-document buckets. The legacy `agreement-files` bucket remains private only to preserve older data; the current application does not expose or create agreements.
8. Create the first Admin using `ADMIN_FIRST_LOGIN.md`.
9. In Administration → Effective-Dated Invoice Tax Rules, publish the legally verified tax rule before issuing an invoice. Quotation subsidy information is standard and requires no rule setup.

For CLI database tests, link a disposable project and run `supabase test db`. Never run destructive test fixtures against production.
