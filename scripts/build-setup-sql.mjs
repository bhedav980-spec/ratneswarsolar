import { readdirSync, readFileSync, writeFileSync } from 'node:fs';

const directory = 'supabase/migrations';
const files = readdirSync(directory).filter((name) => name.endsWith('.sql')).sort();
const header = `-- Ratneswar Engineering Solar CRM - complete clean-project setup\n-- Generated from the ordered, idempotent migrations below. Keep this file in GitHub for deployment and audit.\n\n`;
const body = files.map((name) => `-- ==================================================\n-- ${name}\n-- ==================================================\n${readFileSync(`${directory}/${name}`, 'utf8').trim()}\n`).join('\n');
writeFileSync('supabase/SETUP.sql', `${header}${body}`);
console.log(`Generated supabase/SETUP.sql from ${files.length} migrations.`);
