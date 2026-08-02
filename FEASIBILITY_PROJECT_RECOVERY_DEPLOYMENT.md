# Feasibility Project Recovery — Existing Deployment

This update fixes an Approved quotation where a Feasibility report exists but the linked Project is missing.

## 1. Run the database migration

In Supabase Dashboard → SQL Editor, run the complete contents of:

`supabase/migrations/202608020020_recover_feasibility_project_creation.sql`

Expected result: `Success. No rows returned.`

## 2. Deploy the application files

Replace the existing application files with this ZIP's files while preserving the deployment folder's `.git` and production `.env` files. Then run:

```cmd
git add .
git commit -m "Recover project creation from feasibility"
git push origin main
```

## 3. Recover the affected quotation

1. Wait for Vercel to show Ready and hard refresh with `Ctrl + Shift + R`.
2. Open the Approved quotation.
3. Click Feasibility.
4. Confirm/correct the details and click `Update & Create Project`.
5. The quotation changes to Project Created and exactly one Project appears in Projects.

No Edge Function redeployment is required.
