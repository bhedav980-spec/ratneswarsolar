# Deployment

## Edge Functions

Install Supabase CLI, log in and link the project, then deploy:

```bash
supabase functions deploy admin-users
supabase functions deploy document-importer
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
supabase secrets set GEMINI_API_KEY=YOUR_GOOGLE_AI_STUDIO_KEY
supabase secrets set GEMINI_MODEL=gemini-2.5-flash
# Optional fallback only:
supabase secrets set OPENAI_API_KEY=YOUR_SERVER_SIDE_OPENAI_KEY
supabase secrets set OPENAI_MODEL=gpt-5-mini
supabase secrets set APP_URL=https://YOUR_PRODUCTION_DOMAIN
```

Never add the service-role or AI key to a `VITE_` variable.

In Supabase Authentication → URL Configuration, set the same HTTPS production domain as the Site URL and add `https://YOUR_PRODUCTION_DOMAIN/**` as an allowed Redirect URL. The user-administration function rejects localhost for invitations and password resets.

## Vercel

1. Push the project to a private Git repository and import it in Vercel.
2. Framework preset: Vite. Build command: `npm run build`. Output directory: `dist`.
3. Add `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` and `VITE_APP_TIMEZONE=Asia/Kolkata`.
4. Deploy and add the production/preview URLs to Supabase Auth redirect URLs.

## Netlify

Use the included `netlify.toml`, add the same three public variables, deploy, and add the resulting URL to Supabase Auth redirects.

## Final verification

Test Admin, Area Partner and Dealer in separate browser profiles. Verify email confirmation and password reset, customer-assignment/dealer isolation, exact pricing, Approved → Agreement DOCX → Feasibility PDF → Project Created, duplicate project guard, project stages, commission overpayment guard, stock reservation/issue, serial uniqueness, invoice gross equality, private signed URLs, Excel exports and clean A4 output for quotation, agreement, feasibility and invoice.

For an existing v4 database, run `supabase/migrations/202607180008_area_partner_security_and_login_bootstrap.sql` once before testing. This changes partner access from broad territory access to assigned-customer access and maps the three supplied login emails when those Auth users exist.
