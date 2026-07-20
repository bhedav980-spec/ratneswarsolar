import { createClient } from 'npm:@supabase/supabase-js@2.52.0';
import { authorisedProfile, cors, json } from '../_shared/security.ts';

type AppRole = 'admin' | 'district_partner' | 'dealer';

function validateScope(body: Record<string, unknown>) {
  const role = String(body.role ?? '') as AppRole;
  if (!['admin', 'district_partner', 'dealer'].includes(role)) throw new Error('Invalid role.');
  if (role !== 'admin' && !body.districtId) throw new Error('District is required.');
  if (role === 'dealer' && !body.dealerId) throw new Error('Dealer master is required.');
  return role;
}

function strongPassword(password: string) {
  return password.length >= 12 && /[a-z]/.test(password) && /[A-Z]/.test(password) && /\d/.test(password) && /[^A-Za-z0-9]/.test(password);
}

async function provisionProfile(service: ReturnType<typeof createClient>, userId: string, values: Record<string, unknown>) {
  // The auth trigger creates a suspended placeholder profile. Replacing that
  // placeholder avoids legacy update triggers/constraints while keeping the
  // final role scope atomic from the application's point of view.
  const { data: current, error: readError } = await service.from('profiles').select('id,active').eq('id', userId).maybeSingle();
  if (readError) throw new Error(`Unable to read the new profile: ${readError.message}`);
  if (current) {
    const { error: deleteError } = await service.from('profiles').delete().eq('id', userId).eq('active', false);
    if (deleteError) throw new Error(`Unable to replace the login placeholder: ${deleteError.message}`);
  }
  const { error: insertError } = await service.from('profiles').insert({ id: userId, ...values });
  if (insertError) throw new Error(`Unable to assign login access: ${insertError.message}`);
}

function errorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (error && typeof error === 'object') {
    const value = error as Record<string, unknown>;
    return [value.message, value.details, value.hint, value.code].filter(Boolean).join(' | ') || 'User administration failed.';
  }
  return 'User administration failed.';
}

function productionAppUrl(body: Record<string, unknown>, request: Request) {
  const candidates = [body.appUrl, Deno.env.get('APP_URL'), request.headers.get('origin')];
  for (const candidate of candidates) {
    if (!candidate) continue;
    try {
      const url = new URL(String(candidate));
      const local = ['localhost', '127.0.0.1', '0.0.0.0'].includes(url.hostname);
      if (url.protocol === 'https:' && !local) return url.origin;
    } catch { /* try the next configured URL */ }
  }
  throw new Error('Production APP_URL is missing. Set APP_URL to the deployed HTTPS CRM URL and add it in Supabase Auth URL Configuration.');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const caller = await authorisedProfile(request, ['admin']);
    const body = await request.json() as Record<string, any>;
    const service = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    if (body.action === 'set_active') {
      if (body.userId === caller.user.id && !body.active) throw new Error('You cannot suspend your own account.');
      const { error: profileError } = await service.from('profiles').update({ active: Boolean(body.active), suspended_at: body.active ? null : new Date().toISOString(), suspended_reason: body.active ? null : String(body.reason || 'Suspended by Admin') }).eq('id', body.userId);
      if (profileError) throw profileError;
      const { error: authError } = await service.auth.admin.updateUserById(body.userId, { ban_duration: body.active ? 'none' : '876000h' });
      if (authError) throw authError;
      await service.from('audit_logs').insert({ actor_id: caller.user.id, action: body.active ? 'user_reactivated' : 'user_suspended', entity_type: 'profile', entity_id: body.userId, reason: body.reason });
      return json({ ok: true });
    }

    if (body.action === 'delete_user') {
      if (body.userId === caller.user.id) throw new Error('You cannot delete your own account.');
      const { data: target, error: targetError } = await service.from('profiles').select('id,active,full_name,role').eq('id', body.userId).maybeSingle();
      if (targetError) throw targetError;
      if (!target) throw new Error('User profile not found.');
      if (target.active) throw new Error('Suspend the user before permanent deletion.');
      await service.from('audit_logs').insert({ actor_id: caller.user.id, action: 'user_permanently_deleted', entity_type: 'profile', entity_id: body.userId, reason: String(body.reason || 'Deleted by Admin'), metadata: { fullName: target.full_name, role: target.role } });
      const { error: deleteError } = await service.auth.admin.deleteUser(body.userId);
      if (deleteError) throw deleteError;
      return json({ ok: true });
    }

    if (body.action === 'reset_password') {
      const { data: userData, error: userError } = await service.auth.admin.getUserById(body.userId);
      if (userError || !userData.user?.email) throw userError ?? new Error('User email not found.');
      const redirectTo = `${productionAppUrl(body, request)}/`;
      const { error: resetError } = await service.auth.resetPasswordForEmail(userData.user.email, { redirectTo });
      if (resetError) throw resetError;
      await service.from('audit_logs').insert({ actor_id: caller.user.id, action: 'password_reset_requested', entity_type: 'profile', entity_id: body.userId, metadata: { redirectTo } });
      return json({ ok: true });
    }

    if (body.action === 'update_profile') {
      const role = validateScope(body);
      const { error: updateError } = await service.from('profiles').update({ full_name: String(body.fullName).trim(), role, district_id: role === 'admin' ? null : body.districtId, dealer_id: role === 'dealer' ? body.dealerId : null }).eq('id', body.userId);
      if (updateError) throw updateError;
      await service.from('audit_logs').insert({ actor_id: caller.user.id, action: 'user_profile_updated', entity_type: 'profile', entity_id: body.userId, metadata: { role, districtId: body.districtId, dealerId: body.dealerId } });
      return json({ ok: true });
    }

    if (body.action === 'create_user') {
      const role = validateScope(body);
      const email = String(body.email ?? '').trim().toLowerCase();
      const password = String(body.password ?? '');
      if (!email) throw new Error('Email is required.');
      if (!strongPassword(password)) throw new Error('Temporary password must be at least 12 characters and contain uppercase, lowercase, number and symbol.');
      const { data, error } = await service.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name: String(body.fullName ?? '').trim() } });
      if (error) throw error;
      try {
        await provisionProfile(service, data.user.id, { full_name: String(body.fullName).trim(), role, district_id: role === 'admin' ? null : body.districtId, dealer_id: role === 'dealer' ? body.dealerId : null, active: true, suspended_at: null, suspended_reason: null });
      } catch (profileError) {
        await service.auth.admin.deleteUser(data.user.id);
        throw profileError;
      }
      await service.from('audit_logs').insert({ actor_id: caller.user.id, action: 'user_created_manually', entity_type: 'profile', entity_id: data.user.id, metadata: { email, role, districtId: body.districtId, dealerId: body.dealerId } });
      return json({ ok: true, userId: data.user.id });
    }

    if (body.action !== 'invite') return json({ error: 'Unsupported action.' }, 400);
    const role = validateScope(body);
    const redirectTo = `${productionAppUrl(body, request)}/`;
    const email = String(body.email ?? '').trim().toLowerCase();
    const { data, error } = await service.auth.admin.inviteUserByEmail(email, { redirectTo, data: { full_name: String(body.fullName ?? '').trim() } });
    if (error) throw error;
    const { error: profileError } = await service.from('profiles').update({ full_name: String(body.fullName).trim(), role, district_id: role === 'admin' ? null : body.districtId, dealer_id: role === 'dealer' ? body.dealerId : null, active: true }).eq('id', data.user.id);
    if (profileError) { await service.auth.admin.deleteUser(data.user.id); throw profileError; }
    await service.from('audit_logs').insert({ actor_id: caller.user.id, action: 'user_invited', entity_type: 'profile', entity_id: data.user.id, metadata: { email, role, districtId: body.districtId, dealerId: body.dealerId, redirectTo } });
    return json({ ok: true, userId: data.user.id });
  } catch (error) {
    console.error('admin-users request failed', error);
    return json({ error: errorMessage(error) }, 400);
  }
});
