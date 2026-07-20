# Final v5 Update — Exact Existing-Project Steps

Use Command Prompt inside this extracted project folder. Run one command at a time.

## 1. Update the existing Supabase database

Open Supabase SQL Editor and run this file once:

`supabase/migrations/202607180008_area_partner_security_and_login_bootstrap.sql`

It maps these existing Auth users when present:

- Admin: `ratneswarengineering@gmail.com`
- Area Partner: `bhedav980@gmail.com`
- Dealer: `bhedavishal79@gmail.com`

No passwords are stored in SQL or source code. Create missing users first in Supabase Authentication or from the Admin screen.

## 2. Configure production URLs

Supabase → Authentication → URL Configuration:

- Site URL: `https://ratneswarsolar.vercel.app`
- Redirect URL: `https://ratneswarsolar.vercel.app/**`

Then run:

```cmd
npx.cmd supabase login
npx.cmd supabase link --project-ref ygfeemsxwrlyzdmnzauw
npx.cmd supabase secrets set APP_URL=https://ratneswarsolar.vercel.app
```

## 3. Configure Google AI Studio / Gemini importer

Create a Gemini API key in Google AI Studio, then run locally (never paste the real key into GitHub or a `VITE_` variable):

```cmd
npx.cmd supabase secrets set GEMINI_API_KEY=PASTE_YOUR_NEW_GEMINI_KEY_HERE
npx.cmd supabase secrets set GEMINI_MODEL=gemini-2.5-flash
```

OpenAI is optional fallback only. Do not reuse any key that was exposed in a chat or screenshot.

## 4. Deploy both server functions

```cmd
npx.cmd supabase functions deploy admin-users
npx.cmd supabase functions deploy document-importer
```

The Docker warning may be ignored when the deployment finishes successfully.

## 5. Push the final application

```cmd
git add .
git commit -m "Deploy final v5 Area Partner CRM"
git push origin main
```

Vercel will deploy automatically. Confirm that `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` remain configured in Vercel.

## 6. First verification

1. Sign in as Admin.
2. Open Administration and rename `Primary Partner Area` if required.
3. Edit the Area Partner and Dealer records with final names, area, mobile and commission defaults.
4. Create two customers and assign only one to the Area Partner.
5. Sign in as Area Partner: only the assigned customer and its quotation/project must appear.
6. Sign in as Dealer: only dealer customers and quotations must appear.
7. Test Forgot Password; the production link must open the in-app Create New Password screen.
8. Upload one light bill in AI Customer Import and confirm the result shows an editable review before customer creation.
9. Print one quotation and one invoice. The generated clean PDF must contain only the A4 document.

