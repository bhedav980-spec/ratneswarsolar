import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

describe('mobile modal reachability', () => {
  it('uses the dynamic viewport and keeps feasibility actions reachable', () => {
    const css = readFileSync('src/styles.css', 'utf8');
    expect(css).toContain('height: 100dvh');
    expect(css).toContain('max-height: 100dvh');
    expect(css).toContain('.modal__body { min-height: 0; flex: 1 1 auto;');
    expect(css).toContain('.modal__actions { position: sticky;');
    expect(css).toContain('env(safe-area-inset-bottom)');
  });
});
