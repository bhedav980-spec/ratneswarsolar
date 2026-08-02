# Quotation Status Transition Fix — Existing Deployment

This update fixes the `Invalid quotation status transition` alert caused by a repeated status request or an invalid Approved → Rejected UI action.

## 1. Run the database migration

In Supabase Dashboard → SQL Editor, open and run the complete contents of:

`supabase/migrations/202608020019_idempotent_quotation_status.sql`

Expected result: `Success. No rows returned.`

## 2. Deploy the application files

Replace the files in the existing local deployment folder with this ZIP's files, while preserving its `.git` folder and production `.env` file. Then run:

```cmd
git add .
git commit -m "Fix quotation status transitions"
git push origin main
```

## 3. Verify

1. Wait until the Vercel deployment is Ready.
2. Hard refresh the CRM with `Ctrl + Shift + R`.
3. Open Quotations.
4. A Draft quotation can be sent or rejected.
5. A Sent/Pending quotation can be approved or rejected.
6. An Approved quotation proceeds to Agreement/Feasibility and no longer displays the invalid Reject action.
7. Repeated clicks or a network retry for the same status no longer produce an error.

No Edge Function redeployment is required for this correction.
