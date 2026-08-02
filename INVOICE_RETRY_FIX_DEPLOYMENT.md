# Retry-Safe Invoice Fix — Existing Deployment

## 1. Run the migration

In Supabase Dashboard → SQL Editor, run the complete contents of:

`supabase/migrations/202608020021_retry_safe_invoice_issuance.sql`

Expected result: `Success. No rows returned.`

## 2. Deploy the frontend

Replace application files from this ZIP, preserve `.git` and production `.env`, then run:

```cmd
git add .
git commit -m "Fix retry-safe invoice issuance"
git push origin main
```

## 3. Verify

After Vercel is Ready, hard refresh with `Ctrl + Shift + R`, open the project invoice form and submit it again. Do not delete the quotation. A remaining backend problem will now appear as an exact red message inside the invoice form.

No Edge Function redeployment is required.
