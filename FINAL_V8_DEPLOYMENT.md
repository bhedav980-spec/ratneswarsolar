# Ratneswar Solar CRM Final v8 — Existing Production Deployment

This update adds two audited invoice GST treatments while keeping every issued invoice immutable:

- `GST Included in Quotation Amount`: the accepted quotation remains the final invoice total and GST is reverse-calculated inside it.
- `Add GST Above Quotation Amount`: the accepted quotation becomes the taxable base and GST is added above it.

## 1. Back up Supabase

Create/download a database backup before changing the production database. Do not run the one-time reset SQL for this update.

## 2. Run the v8 migration

In Supabase Dashboard → SQL Editor → New query, copy the complete contents of:

`supabase/migrations/202607200012_invoice_gst_treatment_and_standard_split.sql`

Run it once. Keep this migration in GitHub after deployment; never delete migration history.

The migration:

- adds `quoted_amount` and immutable `tax_treatment` to customer invoices;
- publishes the requested effective-dated 70% Supply / 30% Installation rule with 5% / 18% rates;
- calculates CGST + SGST for intrastate invoices or IGST for interstate invoices;
- saves line-level taxable value, tax, total and treatment in the issued invoice snapshot;
- prevents invalid treatment values and duplicate active invoices.

If migration `202607190011_split_gst_invoice_engine.sql` was never run on this database, run migration 011 first, then migration 012.

## 3. Push v8 to GitHub

Open CMD inside the extracted v8 folder:

```cmd
git add .
git commit -m "Deploy v8 inclusive and GST-extra invoice engine"
git push origin main
```

Vercel will build the connected `main` branch. Confirm deployment status is `Ready`.

## 4. Clear old browser assets

Open the production URL, sign out, press `Ctrl + Shift + R`, then sign in again. This ensures the new invoice form is loaded instead of an older cached bundle.

## 5. Verify both invoice modes

Use a disposable test project at `Project Installation Done`:

1. Open `Installation Details and Invoice`.
2. Confirm `Invoice GST Treatment` has two options.
3. With an accepted quotation of ₹1,00,000 and the seeded 70/30, 5%/18% rule:
   - Included mode final total must remain ₹1,00,000.
   - Extra mode taxable base must be ₹1,00,000 and final total must be ₹1,08,900.
4. For intrastate mode, confirm the 5% supply tax is divided into 2.5% CGST + 2.5% SGST and the 18% installation tax into 9% CGST + 9% SGST.
5. Issue and download one invoice only after the preview is correct.
6. Confirm the PDF is one A4 page, selectable text, and displays the selected GST treatment.

## 6. Admin configuration

Administration → Commercial Settings keeps allocation, both rates, HSN/SAC, tax type and effective date editable. Publishing a new version affects only future invoice dates. Issued invoice snapshots never recalculate.

The supplied 5% / 18% rates are the requested business configuration, not a legal opinion. Confirm current rate applicability with the company’s GST adviser before issuing production invoices. See `GST_CONFIGURATION_NOTE.md`.

## New Supabase project

For a new empty project, run `supabase/SETUP.sql` once. It already contains the v8 columns, requested initial rule and final callable invoice function. Then follow the normal first-admin and deployment guides.
