# Ratneswar Solar CRM Final v14 — Existing Production Deployment

This update preserves all existing customers, quotations, agreements, feasibility reports, projects, invoices and detailed project history. Do not run reset or delete SQL.

## 1. Back up Supabase

Open Supabase → Database → Backups and confirm a current backup.

## 2. Run the single v14 migration

Open Supabase SQL Editor, create a new query, copy the complete contents of:

`supabase/migrations/202607240018_compact_project_workflow.sql`

Press **Run** once. Expected result: **Success. No rows returned**.

Keep this migration file in GitHub after running it. It is required for database history, clean setup and future verification.

## 3. Push the complete v14 folder

Open CMD and run these commands one at a time. Change only the folder path when necessary:

```cmd
cd "C:\Users\salma\Downloads\Ratneswar-Solar-CRM-Final-v14"
git init
git branch -M main
git remote add origin https://github.com/bhedav980-spec/ratneswarsolar.git
git fetch origin main
git reset --soft origin/main
git add .
git commit -m "Deploy v14 compact project workflow and operations dashboard"
git push -u origin main
```

If CMD says `remote origin already exists`, skip only the `git remote add origin ...` command.

## 4. Wait for Vercel

Wait for the new deployment to show **Ready**, then open:

`https://ratneswarsolar.vercel.app`

Sign out, press `Ctrl+Shift+R`, and sign in again.

## 5. Verify v14

1. Open Dashboard and confirm the Operations Pro Compact layout appears.
2. Confirm the project pipeline shows exactly six stages.
3. Open an existing project and confirm its old detailed stage is displayed under the correct grouped label.
4. For a project without a loan, move from Quotation & Documentation directly to Material & Dispatch.
5. For a loan project, move through Loan Progress before Material & Dispatch.
6. Confirm Area Partner can update only an authorised project and Dealer still cannot open Projects.
7. Confirm Installation Completed enables the existing installation and invoice action.

## New Supabase project only

Run `supabase/SETUP.sql` once instead of individual migrations. It contains all 18 ordered migrations through v14. Then follow `SUPABASE_SETUP.md`, `ADMIN_FIRST_LOGIN.md` and `DEPLOYMENT.md`.
