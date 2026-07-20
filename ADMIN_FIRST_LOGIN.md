# First Admin Login

1. In Supabase Authentication → Users, create `ratneswarengineering@gmail.com` with a strong email/password and mark the email verified only after ownership is confirmed.
2. Run this once in SQL Editor, replacing the email:

```sql
update public.profiles
set role='admin', district_id=null, dealer_id=null, active=true, suspended_at=null, suspended_reason=null
where id=(select id from auth.users where lower(email)=lower('YOUR_ADMIN_EMAIL'));
```

3. Sign in with the verified email and strong password. No paid authenticator application is required.
4. Confirm that password reset email works and that the session automatically signs out after 30 minutes of inactivity.
5. Create editable Areas/Territories, then create Area Partner and Dealer users from Administration. Multiple partners may share an area, but each partner sees only customers created by or explicitly assigned to that partner. Never edit Auth role metadata to grant authority; profiles and RLS policies are authoritative.
6. Publish the verified tax/subsidy rules and confirm company/bank settings before customer use.
