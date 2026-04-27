<!-- OMC:START -->
<!-- OMC:VERSION:4.13.4 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>
- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` (use `model=opus` for complex work). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State: `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.

<!-- OMC:END -->

<!-- User customizations (migrated from previous CLAUDE.md) -->
# Global Claude Instructions

These instructions apply to all projects when using Claude Code or VS Code with Claude.

## Agent Team

You have access to specialized sub-agents in `~/.claude/agents/`. Delegate complex tasks to the appropriate specialist:

| Agent | Role | When to Use |
|-------|------|-------------|
| `principal-software-engineer` | Lead/Orchestrator | Complex multi-step tasks, architecture decisions |
| `backend-architect` | Architect | API design, service boundaries, scalability |
| `database-architect` | DB Architect | Data modeling, schema design, CQRS |
| `devops-engineer` | Implementer | CI/CD, Terraform, Docker, ECS |
| `code-reviewer` | Quality Gate | PR reviews, security audits |
| `error-detective` | Investigator | Log analysis, root cause analysis |
| `search-specialist` | Researcher | Documentation, best practices research |
| `context-manager` | Coordinator | Multi-session context preservation |
| `task-decomposition-expert` | Planner | Breaking down complex tasks |
| `architect-review` | Reviewer | Architecture review and validation |

See `~/.claude/agents/agent-orchestration.md` for workflow patterns.

## Code Quality Standards

- Follow SOLID principles pragmatically — simplicity over purity
- Write tests alongside implementation
- Use guard clauses and early returns
- Keep functions small and intention-revealing
- No obvious comments — code should be self-documenting
- Handle errors explicitly — never swallow exceptions

## Security

- Never commit secrets or credentials
- Validate and sanitize all user input
- Use parameterized queries (no SQL injection)
- Follow OWASP Top 10 guidelines
- Least-privilege IAM policies
- Encrypt at rest and in transit

## When Working on Any Project

1. Check for project-level `CLAUDE.md` or `.claude/CLAUDE.md` first — those override these instructions
2. Check for `AGENTS.md` in the project root for project-specific conventions
3. Follow existing codebase patterns over generic best practices
4. Run linters/formatters before committing

## Verified Answer Protocol (MANDATORY)

**Always** apply the `verified-answer` skill protocol when:
- Answering any technical question (tool syntax, API, CLI flags, config keys, argument names)
- Searching for information or documentation
- Debugging errors or root-cause analysis
- Verifying facts, defaults, quotas, limits, or version-specific behavior
- Answering "does X support Y" or "how do I do Z"

Rules that are NEVER optional:
- Look up verifiable claims against primary sources before stating them
- Cite every non-trivial technical claim with a fetched URL
- Say "I could not verify this" instead of guessing
- Never reconstruct URLs from memory — only cite URLs returned by tool calls
- Flag uncertainty explicitly; do not paper over it with confident-sounding prose

## Technology Preferences

- **IaC**: Terraform >= 1.7, Terragrunt for multi-env
- **Containers**: Docker multi-stage builds, ECS Fargate / EKS
- **Cloud**: AWS (prefer AWSCC provider for Terraform)
- **Monitoring**: Datadog, CloudWatch, Prometheus/Grafana
- **Security scanning**: Checkov, Trivy, Snyk
