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
9. **Coverage ladder.** Every behavior change ships with tests at every rung the
   stack supports — discovered from the repo's own harness, not assumed:
   unit → integration → e2e → mutation. Mutation testing runs where a maintained
   tool exists for the stack (verify availability at run time; e.g. Stryker for
   JS/TS, mutmut for Python, cargo-mutants for Rust). For declarative stacks
   (Terraform / Helm / K8s manifests) the equivalent rungs are: schema/contract
   tests (kubeconform, conftest/OPA, `terraform validate` + plan assertions),
   policy scans (checkov/trivy), and an empirical probe against a real or
   rendered system. Each rung skipped gets a one-line reason in the ledger —
   silence is not a skip.
10. **Wire-level verification beats simulation.** A simulator/trace/dry-run
   proves matching or rendering, never end-to-end effect. "Config accepted",
   "manifest Valid", "trace matched" are intermediate signals; the claim "it
   works" requires observing the real request/traffic/run land where intended
   (logs, response bodies, run IDs). For deployed third-party config (cloud
   dashboards, SaaS rules), verification includes a read-back of the deployed
   state — the runbook being correct does not prove the deployed object matches it.
11. **Systems Verification Lessons (global CLAUDE.md) apply in full**, notably:
   verify the checker before the code (a failing gate can be a broken gate —
   controlled reproduction decides); fail-safe extension points (invalid config
   input degrades to the safe default, never opens a gate); state claims
   verified at write time; withdrawal is a full unwind.

## Stage checklist (copy per unit, check off as you go)

```
- [ ] Ledger resolved
- [ ] Stage V: adversarial Workflow loop clean (round N ≤ 3)
- [ ] Stage P: probes run (or skip reason in ledger); behavior-delta table written
- [ ] Stage A: verdict line + delta section + change-log rows in ledger (+ .omc/state mirrors)
- [ ] Stage R: report contract complete (summary, behavior+delta, data flow, state machine, key functions, evidence)
- [ ] Stage S: shipped per project rules; gates passed on merit
```

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

**Scaling rule (embed, do not improvise)** — effort follows diff complexity,
per Anthropic's multi-agent guidance (agents overinvest on simple tasks unless
given explicit scaling rules):

- **Tiny diff** (≤2 files AND no security-adjacent path — auth/authz, network
  policy, secrets, input parsing): 3 dimensions — `correctness`, `tests`,
  `regressions`.
- **Standard/broad diff**: all 5 dimensions.
- **Regulated or sensitive data** (PHI/PII) in the diff: add a domain lens.

**Verify phase** — one refuter per finding, judging through a 3-lens rubric in
a single call (a single rubric call proved more consistent than one judge per
component, and costs 1/3). Exception: `critical` findings keep 3 independent
refuters — defense in depth where a wrong kill is costliest.

Template (pick DIMENSIONS by the scaling rule; keep the structure):

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
const LENS = { type:'object', required:['refuted','reason'], properties:{ refuted:{type:'boolean'}, reason:{type:'string'} } }
const RUBRIC = { type:'object', required:['correctness','exploitability','reproduces'],
  properties:{ correctness: LENS, exploitability: LENS, reproduces: LENS } }
const ALL_DIMENSIONS = [
  { key:'correctness', prompt:'Hunt real bugs, broken invariants, unhandled failure modes in the diff. Cite file:line. Report only defects you can articulate a concrete failure scenario for.' },
  { key:'security',    prompt:'Hunt security/permission/tenant-isolation/PHI-or-secret-leak issues in the diff. Cite the violated rule or doc.' },
  { key:'patterns',    prompt:'Review as a senior lead engineer: violations of the project architecture, stack best practices (project CLAUDE.md, ADRs, current framework docs — verify against them, do not assume), and maintainability/extensibility defects (rigid coupling, missing customization seams, copy-paste divergence).' },
  { key:'tests',       prompt:'Hunt untested behavior changes, mocked-to-pass tests, assertions that cannot fail, and parity gaps: tests whose mocks diverge from the real dev/production cloud behavior (API response shapes, queue/async semantics, error paths). Mocks only at true system boundaries.' },
  { key:'regressions', prompt:'Enumerate every behavior delta the diff introduces (per run type / caller / input class). Flag any narrowing not explicitly declared.' },
]
// Scaling rule: tiny diff → these 3; standard → all 5; regulated data → all 5 + domain lens.
const TINY = false  // set from the diff before launching
const DIMENSIONS = TINY ? ALL_DIMENSIONS.filter(d => ['correctness','tests','regressions'].includes(d.key)) : ALL_DIMENSIONS
const refute = f => agent(
  `Adversarially REFUTE this finding through ALL three rubric lenses — correctness (is the claim true in this code?), exploitability (does it actually matter?), reproduces (is the failure scenario reachable?). Default each lens to refuted=true unless you can confirm it concretely: ${JSON.stringify(f)}`,
  { label:`verify:${f.file}`, phase:'Verify', schema: RUBRIC })
const confirms = r => r ? ['correctness','exploitability','reproduces'].filter(k => !r[k].refuted).length : 0
const results = await pipeline(
  DIMENSIONS,
  d => agent(`${d.prompt}\n\nScope: the current git diff (staged+unstaged) plus untracked new files.`,
             { label:`review:${d.key}`, phase:'Review', schema: FINDINGS }),
  r => parallel((r?.findings ?? []).map(f => () =>
    f.severity === 'critical'
      ? parallel([1,2,3].map(() => () => refute(f)))
          .then(vs => ({ ...f, real: vs.filter(v => confirms(v) >= 2).length >= 2 }))
      : refute(f).then(v => ({ ...f, real: confirms(v) >= 2 }))))
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
- **Every unit** → produce the **behavior-delta table** (not only infra): one row
  per affected caller / run type / input class, before vs. after; every narrowing
  or regression is its own flagged row, never buried in prose. A unit with no
  externally visible change writes the single row `none — internal only` (that
  claim is itself verified, not assumed). Infra/CI changes additionally get one
  row per run type (branch / main / tag / prod / schedule …). Where a real run is
  cheaply possible (temporary probe commit, sandbox), run it — "the config
  parses" is not evidence.
- Skipping a probe requires an explicit one-line reason in the ledger.

## Stage A — Gate artifacts

Write into the ledger (and mirror to `.omc/state/` as hook fallback):

1. Verdict line: `Adversarial review: PASSED (round N, <date>)` — also write the
   same line to `.omc/state/adversarial-verdict`.
2. A `## Behavior delta` section with the table (every unit, per Stage P) — also
   mirror the table to `.omc/state/delta-table.md`.
3. Change-log row(s) for the decisions made.

## Stage R — Report contract

The final report — and its mirror in the ledger as a `## Delivery report`
section — MUST contain, per unit:

1. **What was done.** Plain-language summary of the change and why.
2. **Behavior.** Externally visible behavior now, with the behavior-delta table
   inline (or a link to the ledger section holding it).
3. **Logic & data flow.** The call/data path end to end, one line per hop, each
   hop cited `file:line` (e.g. `edge/LB → ingress route (route.yaml:42) →
   auth proxy (values.yaml:17) → upstream service`). For code: entry point → key
   branches → side effects.
4. **State machine.** Any stateful or multi-phase flow (auth handshakes, retries,
   reconciliation loops, lifecycle transitions) gets a `mermaid stateDiagram-v2`
   of states and transitions **as implemented**, not as designed. Pure stateless
   transforms may skip it with a one-line reason.
5. **Key functions / entry points.** The 3–10 symbols or resources a maintainer
   would read first, each with `file:line` and a one-line role.
6. **Evidence links.** Log lines, run IDs, test output, probe results backing
   every claim above.

## Stage S — Ship

Follow the project's own rules (commit message conventions, Co-Authored-By,
draft PR etc.). The spec-gates hooks will now pass on their own merits — if a
gate denies, the missing artifact is real missing work: produce it, never skip
it. The final message delivers the Stage R report plus: what shipped, rounds
needed, and anything escalated.
