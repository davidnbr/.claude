#!/usr/bin/env bash
# Re-runnable test for the Stage V workflow template in verified-delivery-core.md.
# Extracts the live ```js block, stubs the Workflow runtime, and verifies:
#   1. the template parses (node --check)
#   2. voting math: minor/major finding needs >=2 rubric-lens confirms from its
#      single refuter; critical needs >=2 of 3 refuters each with >=2 confirms;
#      a finding with only 1 confirmed lens is killed
#   3. scaling: TINY=1 runs 3 review dimensions, default runs 5
set -euo pipefail
CORE="$HOME/.claude/skills/_shared/verified-delivery-core.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 - "$CORE" "$TMP/stagev.mjs" <<'EOF'
import re, sys
md = open(sys.argv[1]).read()
src = re.search(r'```js\n(.*?)```', md, re.S).group(1)
src = src.replace("export const meta", "const meta")
src = src.replace("const TINY = false", "const TINY = globalThis.TINY ?? false")
harness = """
globalThis.TINY = process.env.TINY === '1';
const calls = { review: 0, verify: 0 };
async function agent(prompt, opts) {
  if (opts.phase === 'Review') {
    calls.review++;
    if (!opts.label.includes('correctness')) return { findings: [] };
    return { findings: [
      { title:'real crit', file:'a.ts', severity:'critical', claim:'x' },
      { title:'real minor', file:'b.ts', severity:'minor', claim:'y' },
      { title:'bogus', file:'c.ts', severity:'major', claim:'z' },
    ]};
  }
  calls.verify++;
  const f = JSON.parse(prompt.slice(prompt.indexOf(': {') + 2));
  const ok = { refuted:false, reason:'confirmed' }, no = { refuted:true, reason:'refuted' };
  if (f.title === 'bogus') return { correctness: no, exploitability: no, reproduces: ok };
  return { correctness: ok, exploitability: ok, reproduces: no };
}
const parallel = thunks => Promise.all(thunks.map(t => t().catch(() => null)));
async function pipeline(items, ...stages) {
  return Promise.all(items.map(async (it, i) => {
    let v = it;
    for (const s of stages) v = await s(v, it, i);
    return v;
  }));
}
async function main() {
"""
footer = """
}
main().then(() => {
  const expectReview = globalThis.TINY ? 3 : 5;
  if (calls.review !== expectReview) throw new Error(`SCALING WRONG: ${calls.review} review agents, expected ${expectReview}`);
  console.log('PASS: review agents:', calls.review, '| verify agents:', calls.verify);
});
"""
body = src.replace("return { confirmed:", "const OUT = { confirmed:").rstrip() + """
const got = JSON.stringify(OUT.confirmed.map(f=>f.title).sort());
if (got !== JSON.stringify(['real crit','real minor'])) throw new Error('VOTING MATH WRONG: ' + got);
"""
open(sys.argv[2], 'w').write(harness + body + footer)
EOF

node --check "$TMP/stagev.mjs" && echo "PASS: parse"
node "$TMP/stagev.mjs"
TINY=1 node "$TMP/stagev.mjs"
echo "ALL PASS"
