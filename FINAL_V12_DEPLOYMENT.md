# Ratneswar Solar CRM Final v12 — Existing Production Deployment

This update preserves all existing customers, quotations, agreements, projects and invoices. Do not run any reset or delete SQL.

## 1. Back up Supabase

In Supabase, open Database → Backups and confirm a current backup before applying the migration.

## 2. Run the single v12 migration

The v11 migration `202607200015_agreement_feasibility_project_gate.sql` has already succeeded on the current project. Open Supabase SQL Editor, create a new query, copy the complete contents of:

`supabase/migrations/202607200016_editable_feasibility_and_quote_signature.sql`

Press **Run** once. The expected result is **Success. No rows returned**. Keep the SQL file inside the GitHub repository after running it.

## 3. Push the complete v12 folder to GitHub

Open CMD and run these commands one at a time. Adjust only the folder path if the extracted folder name differs:

```cmd
cd "C:\Users\salma\Downloads\Ratneswar-Solar-CRM-Final-v12"
git init
git branch -M main
git remote add origin https://github.com/bhedav980-spec/ratneswarsolar.git
git fetch origin main
git reset --soft origin/main
git add .
git commit -m "Deploy v12 editable feasibility and quotation signature"
git push -u origin main
```

If `origin` already exists, skip `git remote add origin ...`. Never use `--force` unless the repository was intentionally re-created and you have verified the target.

## 4. Wait for Vercel

Open the Vercel Ratneswar Solar project and wait until the deployment sourced from the new commit shows **Ready**. The production URL remains:

`https://ratneswarsolar.vercel.app`

## 5. Refresh and verify

1. Sign out of the CRM.
2. Press `Ctrl+Shift+R` on the login page.
3. Sign in as Admin.
4. Open an Approved quotation with an Agreement and generate Feasibility.
5. Verify there is no report date, yellow highlight or site-layout row; EPC Number is only the quote serial.
6. Create/download a quotation PDF and verify the Ratneswar stamp/signature appears on page 2.
7. Open a Project Created quotation, choose **Edit Feasibility**, change OEM or another field, and choose **Update & Download PDF**. Confirm that no second project is created.

## New Supabase project only

Run `supabase/SETUP.sql` once instead of individual migrations. It contains all 16 ordered migrations through v12. Then follow `SUPABASE_SETUP.md`, `ADMIN_FIRST_LOGIN.md` and `DEPLOYMENT.md`.
