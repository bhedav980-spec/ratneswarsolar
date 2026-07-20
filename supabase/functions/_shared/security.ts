import { createClient } from 'npm:@supabase/supabase-js@2.52.0';

export const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
export const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

export async function authorisedProfile(req: Request, roles: string[]) {
  const auth = req.headers.get('Authorization'); if (!auth) throw new Error('Missing authorization token.');
  const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: auth } } });
  const { data: userData, error: userError } = await client.auth.getUser(); if (userError || !userData.user) throw new Error('Invalid session.');
  const { data: profile, error } = await client.from('profiles').select('*').eq('id', userData.user.id).eq('active', true).single();
  if (error || !profile || !roles.includes(profile.role)) throw new Error('Not authorised.');
  return { client, profile, user: userData.user };
}
