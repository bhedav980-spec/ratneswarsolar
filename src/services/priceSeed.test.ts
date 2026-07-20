import { readFileSync } from 'node:fs';
import { describe,expect,it } from 'vitest';
const sql=readFileSync('supabase/migrations/202607120004_verified_reference_seed.sql','utf8');
describe('verified official price seed',()=>{it('contains all recovered Waaree TOPCon 580 W rows',()=>{for(const expected of ['580,4,2.320,124129','580,7,4.060,203010','580,18,10.440,494294'])expect(sql).toContain(expected);});it('separates 610 W and 615 W configurations',()=>{expect(sql).toContain("'TOPCon',610,17,10.370,494698");expect(sql).toContain("'TOPCon',615,17,10.455,494698");});it('never seeds after-subsidy amount as gross price',()=>{expect(sql).toContain('580,4,2.320,124129,65760,58369');expect(sql).not.toContain('580,4,2.320,58369,');});});
