# Ratneswar Solar CRM Final v13 — Existing Production Deployment

This update preserves existing customers, quotations, agreements, feasibility reports, projects and invoices. Do not run reset or delete SQL.

## 1. Back up Supabase

Open Supabase → Database → Backups and confirm a current backup.

## 2. Run the single v13 migration

Open Supabase SQL Editor, create a new query, copy the complete contents of:

`supabase/migrations/202607230017_quote_linked_and_manual_invoices.sql`

Press **Run** once. Expected result: **Success. No rows returned**.

Keep this migration file in GitHub after running it. It is required for database history, clean setup and future verification.

## 3. Push the complete v13 folder

Open CMD and run these commands one at a time. Change only the folder path when necessary:

```cmd
cd "C:\Users\salma\Downloads\Ratneswar-Solar-CRM-Final-v13"
git init
git branch -M main
git remote add origin https://github.com/bhedav980-spec/ratneswarsolar.git
git fetch origin main
git reset --soft origin/main
git add .
git commit -m "Deploy v13 quote linked and manual invoices"
git push -u origin main
```

If CMD says `remote origin already exists`, skip only the `git remote add origin ...` command.

## 4. Wait for Vercel

Wait for the new deployment to show **Ready**, then open:

`https://ratneswarsolar.vercel.app`

Sign out, press `Ctrl+Shift+R`, and sign in again.

## 5. Verify v13

1. Open an installed CRM project and choose Generate Invoice.
2. Confirm quotation serial `38` displays Bill No. `RE/BILL/26-27/0038`.
3. Open Invoices as Admin and choose **Manual Invoice**.
4. Enter an old quotation serial such as `18`, complete the customer/system/amount fields and save.
5. Confirm the saved Bill No. is `RE/BILL/26-27/0018`, the invoice opens in the standard A4 preview, and it appears in Manual Invoice Register.
6. Open Customers and confirm there is no Site Survey button or Site Survey form.

## New Supabase project only

Run `supabase/SETUP.sql` once instead of individual migrations. It contains all 17 ordered migrations through v13. Then follow `SUPABASE_SETUP.md`, `ADMIN_FIRST_LOGIN.md` and `DEPLOYMENT.md`.
