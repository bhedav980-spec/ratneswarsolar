# Ratneswar Solar CRM Final v11 — Existing Production Deployment

This is the short upgrade path from the already deployed v10 website/database.

## 1. Back up Supabase

Create a database backup before deployment. Do not run any reset SQL for this update.

## 2. Run the single v11 migration

In Supabase Dashboard → SQL Editor, run the complete contents of:

`supabase/migrations/202607200015_agreement_feasibility_project_gate.sql`

Expected result: `Success. No rows returned`.

Keep this migration and `supabase/SETUP.sql` in GitHub. SQL migration files are permanent deployment history and must not be deleted after they run.

## 3. Push the complete v11 folder to GitHub

Extract the ZIP to a new folder. In Windows CMD:

```cmd
cd "C:\Users\salma\Downloads\Ratneswar-Solar-CRM-Final-v11"
git init
git branch -M main
git remote add origin https://github.com/bhedav980-spec/ratneswarsolar.git
git fetch origin main
git reset --soft origin/main
git add -A
git commit -m "Deploy v11 agreement and feasibility workflow"
git push origin main
```

If `origin` already exists, skip `git remote add origin ...`. Do not use `--force`.

## 4. Wait for Vercel

Vercel deploys `main` automatically. Wait until the latest deployment is `Ready`, sign out of the CRM, press `Ctrl + Shift + R`, and sign in again.

## 5. Verify the final document workflow

1. Create or open a sent/pending quotation as Admin or Area Partner.
2. Click Approve. Confirm no project is created yet.
3. Click the Agreement download action. Confirm an editable `.docx` downloads.
4. Open the DOCX: customer name/address and quote date must be filled, customer signature area must be blank, and Ratneswar details/signature must be unchanged.
5. The Feasibility action now appears. Enter the mandatory Application Reference Number; Jan Samarth ID and DISCOM ID may be blank.
6. Click `Generate PDF & Create Project`.
7. Confirm a one-page A4 Feasibility PDF downloads and exactly one project is created.
8. Confirm the Agreement and Feasibility download actions remain available on the Project Created quotation.

## New empty Supabase project

Run `supabase/SETUP.sql` once instead of individual migrations. It is generated from all 15 ordered migrations and already includes v11. Then follow `ADMIN_FIRST_LOGIN.md`, `SUPABASE_SETUP.md` and `DEPLOYMENT.md`.
