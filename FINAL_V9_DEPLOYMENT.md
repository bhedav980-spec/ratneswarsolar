# Ratneswar Solar CRM Final v9 — Fast Existing Deployment

This update adds editable automatic/manual quotation configuration, optional loan pricing, fixed manual dealers, standard informational subsidy rows and multi-material truck receipts.

## 1. Back up Supabase

Create a database backup before deployment. Do not run any reset SQL for this update.

## 2. Run one new SQL migration

Supabase Dashboard → SQL Editor → New query. Copy the complete contents of:

`supabase/migrations/202607200013_manual_quote_loan_dealer_receipts.sql`

Run it once. A successful result is `Success. No rows returned`.

Keep the migration file in GitHub. Migration files are deployment history and must not be deleted after running.

## 3. Push v9 to GitHub

Open CMD inside the extracted v9 folder:

```cmd
git add .
git commit -m "Deploy v9 editable quotations loan dealers and material receipts"
git push origin main
```

Vercel should deploy the connected `main` branch automatically. Wait for status `Ready`.

## 4. Refresh production assets

Open the live site, sign out, press `Ctrl + Shift + R`, and sign in again.

## 5. Verify quotation flow

1. New Quotation → choose a verified source price row.
2. Confirm WAAREE lists only 540 Wp and 580 Wp source categories.
3. Switch to `Manual Edit`; change panel quantity or exact DC kW and enter the required audit reason.
4. Enter inverter brand/model/capacity manually.
5. Select Loan Required. Confirm defaults are 10% gross-up and ₹2,000 file charge, both editable.
6. With base price ₹1,50,000, confirm financed EPC price is ₹1,66,666.67 and total with ₹2,000 charge rounds to ₹1,68,667.
7. Confirm the final customer price remains editable.
8. Edit one BOM row and confirm Auto-sync turns off.
9. Download the quotation PDF. It must remain two clean A4 vector-text pages.
10. Confirm subsidy appears as information and Net Amount Payable remains equal to Grand Total.

## 6. Verify dealer flow

1. Admin or Area Partner creates a quotation.
2. Dealer → `Add dealer manually`.
3. Enter dealer name, 10-digit mobile, address and fixed commission amount.
4. Save the quote and confirm the dealer appears in Dealer Master.
5. After project creation, confirm the fixed amount enters the commission ledger.

## 7. Verify inventory receipt

1. Inventory → create required Item Masters for panel, inverter and other materials.
2. Inventory → Material / Truck Receipt.
3. Enter vendor, receipt number, arrival date and optional truck reference.
4. Add multiple material rows and enter quantity plus total lot price only.
5. Confirm the per-unit rate is calculated automatically and stock increases once.

## New Supabase project

For a new empty project, run `supabase/SETUP.sql` once. It includes all migrations through v9. Then follow `ADMIN_FIRST_LOGIN.md`, `SUPABASE_SETUP.md` and `DEPLOYMENT.md`.
