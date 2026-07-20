# Ratneswar Solar CRM Final v10 - Existing Production Deployment

This is the short upgrade path from the already deployed v9 database and website.

## 1. Back up Supabase

Create a database backup before deployment. Do not run any one-time reset SQL for this update.

## 2. Run the single v10 migration

In Supabase Dashboard, open SQL Editor and run the complete contents of:

`supabase/migrations/202607200014_official_price_match_and_project_cleanup.sql`

Expected result: `Success. No rows returned`.

Keep this SQL file in GitHub after it succeeds. It is permanent deployment history and must not be deleted.

## 3. Push the complete v10 folder to GitHub

Extract the final v10 ZIP to a new folder. In Windows CMD:

```cmd
cd "C:\Users\salma\Downloads\Ratneswar-Solar-CRM-Final-v10"
git init
git branch -M main
git remote add origin https://github.com/bhedav980-spec/ratneswarsolar.git
git fetch origin main
git reset --soft origin/main
git add -A
git commit -m "Deploy v10 official prices and invoice project cleanup"
git push origin main
```

If `origin` already exists, skip `git remote add origin ...`. Do not use `--force` for this v10 upgrade.

## 4. Wait for Vercel

Vercel should deploy `main` automatically. Wait until the latest deployment shows `Ready`. Then sign out of the CRM, press `Ctrl + Shift + R`, and sign in again.

## 5. Verify quotation matching

1. Open New Quotation.
2. Select WAAREE + Bifacial. Confirm `540 Wp` appears.
3. Enter required capacity `3.27` kW. Confirm the matched result is 6 panels and 3.240 kW.
4. Select WAAREE + TOPCon. Confirm 580, 610 and 615 Wp are available.
5. Select ADANI + TOPCon. Confirm 610, 615, 620 and 625 Wp are available.
6. Confirm there is no visible `Verified Source Price Row` selector or PDF filename reference.
7. Save a quotation and download it. Confirm the heading says `SUBSIDY DETAILS`, the total says `Total Subsidy`, and the old authority-approval sentence is absent.

## 6. Delete the erroneous invoiced project

1. Open Invoices or the project detail as Admin.
2. Click `Cancel Invoice`, enter the required reason and confirm.
3. Open the same project and click `Delete Project`.
4. Enter the deletion reason and confirm.
5. The cancelled test invoice, its installation serial records and the erroneous project are removed atomically. Issued stock, payments or dealer commission payments still block unsafe deletion.

## New empty Supabase project

Run `supabase/SETUP.sql` once instead of individual migrations. It is generated from all 14 ordered migrations and already includes v10. Then follow `ADMIN_FIRST_LOGIN.md`, `SUPABASE_SETUP.md` and `DEPLOYMENT.md`.
