# Load the project rule set (worktree/sandbox-safe)

Shared procedure referenced by `bmad-tackle-story`, `bmad-resolve-review`, and
`complete-pr-review`. Single source of truth — edit here, not in the skills.

Load engineering rules from **absolute paths** — you may be running in a git
**worktree** (cwd ≠ main checkout) under a **sandbox** (reads succeed anywhere;
only writes are scoped). Relative paths like `.claude/rules/*.md` silently
resolve to the *worktree* copy, which is often empty or missing — known failure
mode. Read every source that exists; missing ones are fine (absent ≠ ignore):

1. **Global user rules** — `~/.claude/CLAUDE.md` and every `~/.claude/rules/*.md`.
2. **Project rules from the real repo root** (survives worktrees — never use a
   relative path):

   ```sh
   root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   # Read, if present: "$root/CLAUDE.md", "$root/AGENTS.md",
   #   "$root"/.claude/rules/*.md, and "$root"/_bmad/custom/*.toml
   ```

   `_bmad/custom/*.toml` (`persistent_facts`) is where BMAD projects keep
   engineering guardrails (comment style, naming, "no PM references in shipped
   code/docs", commit/PR conventions). It is often **gitignored** → absent in
   the worktree → reachable only via `$root` from the main checkout. If it is
   gitignored, note that to the user (it won't reach fresh clones elsewhere).
   Some projects don't have it; skip silently.

Call the union of 1+2 **the loaded rule set**. Verify findings, fixes,
rebuttals, and "done" claims against it. When spawning subagents, pass them the
absolute paths plus the substance of any `_bmad/custom/*.toml` guardrails —
they run in the same worktree/sandbox and must honor the same rules.

## Validation chain selection (stack-appropriate)

The validation chain must match the story's/change's actual stack, as evidenced
by the repo's CI (`.github/workflows/*`), pre-commit config, and dev scripts:

- Terraform: `terraform fmt` → `tflint` → `checkov` → `terraform validate`
- Helm/Kustomize/ArgoCD manifests: `yamllint` → `helm lint` → `kubeconform` → `checkov`
- App code: the repo's own lint/typecheck/test commands

Never run Terraform commands on a non-Terraform change. Report pre-existing
failures separately from ones you introduced — never claim a fix passed checks
it didn't run.
