---
name: local-worker
description: Delegate edit/implementation work to a local LLM (Ollama-backed) running as a separate claude or opencode CLI process, while this session stays the orchestrator (plan + review). Use when the user wants to "delegate to ollama", "use a local worker", "spawn a worker", "save tokens by offloading edits", or build an orchestrator/worker split with local models.
---

# Local Worker Delegation

Orchestrator (this session, real Anthropic API) plans and reviews. A separate
CLI process, pointed at a local Ollama model, does the actual file edits.
Worker runs as its own OS process — never as a Task-tool subagent — because
Task-tool subagents inherit this session's API config and can't be
redirected to a different backend (no native per-subagent provider override
exists in Claude Code as of June 2026: anthropics/claude-code#38698, open).

Redirecting a worker's `ANTHROPIC_BASE_URL` to `localhost:11434` means the
request never reaches Anthropic's servers — zero Anthropic tokens, zero
subscription/API billing, regardless of how much the worker churns.

## Workflow

1. **Plan.** Write a precise, self-contained task spec for the worker: exact
   files, exact change, acceptance criteria. Worker has no memory of this
   conversation — spec must stand alone.
2. **Dispatch.** Run `scripts/delegate_worker.sh` (see below) with the task
   spec. It blocks until the worker finishes and prints JSON result.
3. **Review.** `git diff` the worker's changes. Check against acceptance
   criteria.
4. **Iterate or land.** If wrong: write a follow-up spec describing exactly
   what's wrong, dispatch again (use `--continue` flag on script to resume
   worker's own session with full context of attempt 1, or run fresh if
   worker botched it badly enough that a clean slate is safer).

## Dispatch script

```bash
scripts/delegate_worker.sh <backend> <model> "<task prompt>" [--continue]
```

- `<backend>`: `claude` or `opencode`
- `<model>`: model tag as pulled in Ollama, e.g. `qwen2.5-coder:latest`
- Prints worker's JSON result to stdout. Check `result`/`session_id` fields.

### Backend notes

**claude** (Ollama via Anthropic-compatible endpoint, native since Ollama
v0.14):
- Full tool-calling support (Read/Edit/Bash), same CLAUDE.md/skills loading
  as interactive Claude Code unless `--bare` is added to the script's
  command — keep `--bare` off if the worker needs repo CLAUDE.md context,
  add it back for deterministic/minimal-context runs.
- Known limitation (Ollama docs): no `tool_choice` forcing, approximate
  token counts, no prompt caching.
- Needs Ollama ≥ v0.14.3-rc1 for reliable streaming tool calls — older
  stable builds can break the agentic loop mid-edit.

**opencode** (native multi-provider, no compat shim needed):
- Model arg form: `ollama/<tag>` (provider/model).
- Only documented auto-approval flag is the blanket
  `--dangerously-skip-permissions` — there is no granular allowedTools
  equivalent confirmed in opencode docs. Only point it at a sandboxed
  worktree/branch, not a directory you care about, until you've watched it
  run a few times.

## Before first use

```bash
ollama pull qwen2.5-coder:latest   # or any tool-calling-capable coder model
ollama serve &                      # if not already running as a service
```

Model must support tool calling — text-only models can't Read/Edit/Bash.

## What this does NOT do

Doesn't give you Claude Code's native Task-tool ergonomics (no automatic
context handoff, no nested subagent tree). It's one orchestrator turn = one
manual worker dispatch = one manual review. That manual loop is the actual
mechanism that keeps Anthropic token spend to orchestrator-only.
