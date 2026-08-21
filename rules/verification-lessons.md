# Systems Verification Lessons (general — every project)

Extend the Empirical Verification and Delivery protocols in ~/.claude/CLAUDE.md.

## Scoping

- This file and ~/.claude/CLAUDE.md carry general rules only. One repo's
  paths, commands, vendors, or ticket prefixes go in project-local files
  (project CLAUDE.md / AGENTS.md, `.claude/` config, `_bmad/custom/*.toml`).
- Per-repo spec-gate opt-ins: `~/.claude/spec-gates-infra.d/<basename>.regex`.
- Rules that must ALWAYS run are hooks, not instructions — CLAUDE.md and
  rules files are advisory context; hooks are deterministic.

## Sources

- **Never use the Fetch/WebFetch tools.** Find candidate URLs with search
  (WebSearch, doc-search MCP tools), then `curl` the URL yourself and
  grep/strip the content locally. Cite only URLs you actually retrieved.

## Verification

- **Reconciled systems: mutate the source of truth.** Where a reconciler
  runs (GitOps controllers, config management, drift correction), manual
  edits to the live object are silently reverted — change what the
  reconciler reads. Inverse trap: a declarative file that is NOT
  auto-applied changes nothing; name its apply step when you edit it.
- **Only end-to-end observation proves "it works".** "Accepted / valid /
  rendered / synced / trace matched / dry-run clean" are intermediate. The
  claim requires the real request or run observed landing: logs, response
  bodies, status codes, run IDs.
- **Read back deployed third-party config** (cloud dashboard, SaaS rule,
  identity provider): field-by-field read-back of the DEPLOYED object —
  including type/kind fields, which silently change semantics — plus an
  empirical probe. A correct runbook proves nothing about deployed state.
- **Default-deny is directional.** Attaching a policy to an endpoint flips
  it to deny in that direction; every edge A→B needs allows on A's egress
  AND B's ingress. Verify new edges with real traffic.
- **Verify the checker before the code.** On a test/gate/hook failure, a
  controlled reproduction decides whether the checker or the product is
  broken. Editing product code to satisfy a broken checker corrupts both.
- **Fail-safe extension points.** User/config-supplied input to automation
  (regexes, hooks, templates) is validated in isolation first; invalid
  input degrades to the safe default — never silently widens a gate or
  crashes the tool.
- **Evidence is persisted and re-runnable**: saved script + literal output
  a reviewer can re-run independently. Unreproducible evidence is an
  anecdote.
- **State claims verified at write time.** Any written claim about repo or
  system state ("committed", "gitignored", "deployed", "canonical copy at
  X") is checked when written and re-checked when the fact changes.
- **Withdrawal is a full unwind**: close the PR with the reason, delete
  remote branches, relocate value, record the pivot in the ledger.
- **Instructions to humans are complete**: exact location, exact target
  value, why, expected success and failure output. Never "fix the value".
