# Backup and Rollback

1. Enable Supabase point-in-time recovery where the plan supports it and schedule database exports.
2. Before every migration, take a database backup and retain the deployed frontend commit and Edge Function versions.
3. Never delete or overwrite issued invoices, accepted quotation snapshots, legacy agreement records, audit logs, stock postings or commission payments. Use cancellation, credit or compensating transactions.
4. Test restores into a separate Supabase project. Validate counts, document links, RLS and signed URLs before switching traffic.
5. Frontend rollback: redeploy the prior known-good commit. Database rollback: apply a reviewed forward repair or restore the pre-migration backup into a separate project. Do not use destructive drops on production.
6. Rotate service-role/AI secrets immediately after suspected exposure and revoke affected sessions.
