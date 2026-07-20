import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const allowedActions = new Set(['extract_bill','review_survey','preview_price_import','suggest_bom','missing_documents','project_summary','followup_draft','daily_summary','calculation_check']);

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type, apikey' } });
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader) throw new Error('Authentication required.');
    const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await client.auth.getUser();
    if (!user) throw new Error('Invalid session.');
    const { action, input, sources = [] } = await request.json();
    if (!allowedActions.has(action)) throw new Error('Unsupported or irreversible AI action.');
    const apiKey = Deno.env.get('OPENAI_API_KEY');
    if (!apiKey) return Response.json({ available: false, message: 'AI key is not configured. Core CRM remains available.', confidence: 0, sources: [] });
    const prompt = `You assist a solar EPC CRM. Action: ${action}. Return strict JSON with fields result, confidence (0-1), sourceEvidence (array), needsHumanConfirmation (boolean), warnings (array). Never invent customer, legal, subsidy, tax, payment or technical facts. Low confidence must require confirmation. Never approve, delete, issue an invoice or mark payment received. Input: ${JSON.stringify(input)}`;
    const response = await fetch('https://api.openai.com/v1/responses', { method: 'POST', headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ model: 'gpt-5-mini', input: prompt, text: { format: { type: 'json_object' } } }) });
    if (!response.ok) throw new Error(`AI service failed (${response.status}).`);
    const raw = await response.json();
    const text = raw.output?.flatMap((x: any) => x.content ?? []).find((x: any) => x.type === 'output_text')?.text;
    const result = JSON.parse(text || '{}');
    await client.from('ai_action_logs').insert({ user_id: user.id, action_type: action, source_refs: sources, result });
    return Response.json(result, { headers: { 'Access-Control-Allow-Origin': '*' } });
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : 'AI request failed.' }, { status: 400, headers: { 'Access-Control-Allow-Origin': '*' } });
  }
});
