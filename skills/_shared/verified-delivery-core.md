# Verified Delivery Core

Shared stages for `/bmad-verified-tackle` and `/verified-tackle`. The entry skill
handles stage 1 (implementation); everything below is identical for both — this
file is the single source of the quality bar. Do not paraphrase-and-drift: follow
it as written.

## Non-negotiables (inherit into every stage)

1. **DO NOT ASSUME ANYTHING. VERIFY COMPLETELY.** Every claim checked against the
   code, the running system, or primary-source docs. Reconstructed-from-memory
   facts are forbidden (Verified Answer Protocol applies).
2. **Empirical Verification Protocol** (global CLAUDE.md): testable claims get
   tested; opaque errors get decoded by reproduction; approaches are never
   abandoned without a variable-isolating control experiment; creation ≠ working.
3. **DRY, KISS, YAGNI. Clean code.** Smallest correct change.
4. **Author and verifier are separate lanes.** Nothing self-approves.
5. **Done = evidence, not vibes.** Artifacts below, or it didn't happen.
6. **Never bypass the spec-gates hooks** (`OMC_SKIP_HOOKS`) to ship your own work.
7. **Senior lead engineer bar.** Judge every change for long-term maintainability,
   customization points, and extensibility — not just "does it work". Best
   recommended patterns for the current stack, verified against up-to-date
   primary docs (framework/library docs as of today, not training memory).
8. **Test parity with real environments.** Tests mirror the actual dev/production
   cloud implementation as closely as feasible: real API response shapes, real
   queue/async behavior, real error paths. Mocks only at true system boundaries,
   and never shaped to make a failing test pass — a test that cannot fail is a
   defect.

## Ledger resolution (do this first)

The ledger is where findings, solutions, decisions, and verdicts are recorded:

- `_bmad-output/` exists → the story/spike `.md` for this work.
- else `openspec/` exists → the relevant change/spec `.md`.
- else → `.omc/state/findings.md` (create `.omc/state/` if needed).

Every stage that produces findings APPENDS them to the ledger; every fix appends
the implemented solution; every decision gets a change-log row. This is the audit
trail that survives the session and satisfies the commit gate.

## Stage V — Adversarial verification loop (code-enforced)

Run the loop via the **Workflow tool** (this skill directs you to call it — that
is the required opt-in). Do NOT replace it with a single reviewer subagent: the
Workflow's value is code-enforced convergence and schema-validated outputs.

Template (adapt DIMENSIONS to the diff; keep the structure):

```js
export const meta = {
  name: 'verified-delivery',
  description: 'Adversarial verification of the current working-tree diff',
  phases: [{ title: 'Review' }, { title: 'Verify' }],
}
const FINDINGS = { type:'object', required:['findings'], properties:{ findings:{ type:'array', items:{
  type:'object', required:['title','file','severity','claim'], properties:{
    title:{type:'string'}, file:{type:'string'}, line:{type:'integer'},
    severity:{enum:['critical','major','minor']}, claim:{type:'string'}, fix:{type:'string'} } } } } }
const VERDICT = { type:'object', required:['refuted','reason'], properties:{ refuted:{type:'boolean'}, reason:{type:'string'} } }
const DIMENSIONS = [
  { key:'correctness', prompt:'Hunt real bugs, broken invariants, unhandled failure modes in the diff. Cite file:line. Report only defects you can articulate a concrete failure scenario for.' },
  { key:'security',    prompt:'Hunt security/permission/tenant-isolation/PHI-or-secret-leak issues in the diff. Cite the violated rule or doc.' },
  { key:'patterns',    prompt:'Review as a senior lead engineer: violations of the project architecture, stack best practices (project CLAUDE.md, ADRs, current framework docs — verify against them, do not assume), and maintainability/extensibility defects (rigid coupling, missing customization seams, copy-paste divergence).' },
  { key:'tests',       prompt:'Hunt untested behavior changes, mocked-to-pass tests, assertions that cannot fail, and parity gaps: tests whose mocks diverge from the real dev/production cloud behavior (API response shapes, queue/async semantics, error paths). Mocks only at true system boundaries.' },
  { key:'regressions', prompt:'Enumerate every behavior delta the diff introduces (per run type / caller / input class). Flag any narrowing not explicitly declared.' },
]
const results = await pipeline(
  DIMENSIONS,
  d => agent(`${d.prompt}\n\nScope: the current git diff (staged+unstaged) plus untracked new files.`,
             { label:`review:${d.key}`, phase:'Review', schema: FINDINGS }),
  r => parallel((r?.findings ?? []).map(f => () =>
    parallel(['correctness','exploitability','does-it-reproduce'].map(lens => () =>
      agent(`Adversarially REFUTE this finding via the ${lens} lens. Default refuted=true if you cannot confirm it concretely: ${JSON.stringify(f)}`,
            { label:`verify:${f.file}`, phase:'Verify', schema: VERDICT })))
      .then(vs => ({ ...f, real: vs.filter(Boolean).filter(v => !v.refuted).length >= 2 }))))
)
return { confirmed: results.flat().filter(Boolean).filter(f => f.real) }
```

Loop protocol:

```
round = 1
while true:
  confirmed = run the Workflow above on the current diff
  append confirmed findings to the ledger
  if confirmed is empty -> break (verified clean)
  if round == 3        -> STOP; report surviving findings to the user; do NOT ship
  fix the findings (smallest correct fix; disputed findings get rebutted with
  cited evidence in the ledger instead of blind-fixed)
  append the implemented solutions to the ledger
  round += 1
```

## Stage P — Empirical probes (after the loop is clean)

- **Behavior change** → smoke it against the running system, not just unit tests
  (use the project's harness: e2e browser tests, real HTTP with auth, real CLI runs).
  Record the evidence (run IDs, log lines) in the ledger.
- **Infra/CI change** → produce the **behavior-delta table**: one row per run
  type (branch / main / tag / prod / schedule …), before vs. after; every
  narrowing is its own flagged row. Where a real run is cheaply possible
  (temporary probe commit, sandbox), run it — "the config parses" is not evidence.
- Skipping a probe requires an explicit one-line reason in the ledger.

## Stage A — Gate artifacts

Write into the ledger (and mirror to `.omc/state/` as hook fallback):

1. Verdict line: `Adversarial review: PASSED (round N, <date>)` — also write the
   same line to `.omc/state/adversarial-verdict`.
2. If infra was touched: a `## Behavior delta` section with the table — also
   mirror the table to `.omc/state/delta-table.md`.
3. Change-log row(s) for the decisions made.

## Stage S — Ship

Follow the project's own rules (commit message conventions, Co-Authored-By,
draft PR etc.). The spec-gates hooks will now pass on their own merits — if a
gate denies, the missing artifact is real missing work: produce it, never skip
it. Surface in the final report: what shipped, rounds needed, probe evidence,
and anything escalated.
