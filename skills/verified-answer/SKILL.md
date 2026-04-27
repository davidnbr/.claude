---
name: verified-answer
description: Use this skill whenever the user asks a technical question where a wrong answer could cause real harm — broken infrastructure, failed deployments, production bugs, security gaps, or wasted time. Triggers on any question involving tool syntax, API signatures, CLI flags, configuration keys, resource or argument names, version-specific behavior, default values, quotas or limits, error-message root causes, "does X support Y", "how do I do Z in some tool", or any factual claim that can be verified against documentation. Use this even when the user does not explicitly ask for sources — they always want verified answers over plausible-sounding guesses. Especially important for Terraform, AWS (ECS, ELB, SES, WAF, VPN, IAM, S3, Lambda), Python and its libraries (boto3, pydantic, requests), NixOS and Nix and Home Manager, GitHub Actions, CircleCI, Go, Docker, Kubernetes, Ruby on Rails, PostgreSQL, Redis, Azure, and any cloud or CI or infra topic where a hallucinated flag or function signature will break things.
---

# Verified Answer

## Reality check (read this first)

No prompt can guarantee 0% hallucinations from an LLM. What this skill *can* do is move verifiable technical claims from "trained guess" to "grounded in current, cited documentation" — which eliminates the vast majority of hallucinations on the questions that actually matter for infrastructure work.

The core trade: **prefer saying "I could not verify X" over giving a plausible-sounding answer.** Admitting ignorance is correct behavior under this skill, not failure. A short, verified answer beats a long, confident-sounding one every time.

## The verification protocol

Before stating any of the following, look it up against a primary source:

- **API signatures, function names, method parameters** (e.g., `boto3.client('ecs').update_service()` arguments)
- **CLI flags and subcommands** (e.g., `terraform plan -target`, `aws s3 sync --exclude`, `nix-env -iA`)
- **Configuration keys and resource arguments** (e.g., `aws_ecs_service` arguments, CircleCI `orbs`, NixOS options, GitHub Actions `inputs`)
- **Version-specific behavior** (e.g., "added in Terraform 1.6", "deprecated in Python 3.12", "requires provider ≥ 5.0")
- **Default values, quotas, and limits** (e.g., AWS service quotas, SES sandbox send rate, Lambda timeout max)
- **Error messages → root cause** (look up the exact message instead of inferring from the shape of it)
- **Feature existence** ("does `aws_ecs_service` have a `force_new_deployment` argument?") — confirm or deny by checking

The rule: **if it's the kind of fact a reader could paste into code and have it fail, verify before stating.**

General conceptual knowledge (what Terraform *is*, how TCP works, what a VPC is) does not require lookup. The trigger is "could be wrong in a specific, verifiable way."

## Tool routing — which source for which question

Always prefer **first-party / official** sources. Route by topic:

| Topic | First choice | Fallback |
|---|---|---|
| AWS services, APIs, quotas, regional availability, workflows | `AWS Knowledge:aws___search_documentation` → `aws___read_documentation`; use `aws___get_regional_availability`, `aws___list_regions`, `aws___retrieve_agent_sop` when relevant | `web_fetch` on `docs.aws.amazon.com` |
| Terraform providers (hashicorp/aws, google, azurerm, kubernetes, etc.) | `Context7:resolve-library-id` → `Context7:query-docs` | `Ref Documentation:ref_search_documentation` → registry.terraform.io |
| Terraform core (CLI, HCL, state, meta-arguments, functions) | `Ref Documentation:ref_search_documentation` scoped to developer.hashicorp.com | `web_fetch` developer.hashicorp.com |
| Python libraries (boto3, pydantic, requests, fastapi, …) | `Context7:resolve-library-id` → `query-docs` | `Ref Documentation` |
| Python stdlib | `Ref Documentation` (docs.python.org) | `web_fetch` |
| NixOS / Nix / nixpkgs / Home Manager | `Ref Documentation` scoped to nixos.org, nix.dev, search.nixos.org | `web_search` for current option names |
| GitHub Actions syntax (workflows, contexts, triggers, reusable workflows) | `Ref Documentation` (docs.github.com/actions) | `web_fetch` docs.github.com |
| Specific actions (`actions/checkout`, `aws-actions/configure-aws-credentials`, …) | `Context7:resolve-library-id` for the repo | `web_fetch` the action's README on github.com |
| CircleCI | `Ref Documentation` (circleci.com/docs) | `web_fetch` |
| Go stdlib and popular modules | `Ref Documentation` (pkg.go.dev) or `Context7` | |
| Docker / OCI / Compose | `Ref Documentation` (docs.docker.com) | |
| Kubernetes | `Ref Documentation` (kubernetes.io/docs) | `Context7` |
| Ruby / Rails | `Context7` or `Ref Documentation` (guides.rubyonrails.org, api.rubyonrails.org, ruby-doc.org) | |
| PostgreSQL, Redis | `Ref Documentation` (postgresql.org/docs, redis.io/docs) | |
| Azure | `Microsoft Learn:microsoft_docs_search` → `microsoft_docs_fetch` | |
| Anything else | `Tavily:tavily_search` or `web_search` → then fetch the authoritative page | |

**Selection heuristic:**

1. Is there a first-party doc site (docs.aws.amazon.com, developer.hashicorp.com, docs.python.org, nixos.org)? Use the MCP that targets it.
2. Is there a clear library / framework name? Call `Context7:resolve-library-id` first to get the canonical ID, then `query-docs`.
3. Otherwise Tavily or web_search to locate the authoritative page, then `web_fetch` to actually read it.

Blog posts, Stack Overflow answers, and Medium articles are **secondary sources**. Use them to locate the primary source or as a cross-check — do not cite them as authoritative.

## How to actually run a verification

1. **Form the narrowest possible query.** `terraform aws_ecs_service deployment_circuit_breaker` beats `ecs service stuff`. Include the exact identifier you plan to use in the answer.
2. **Pull the primary source.** Read the actual doc page — do not rely on the search snippet. Snippets lie by omission.
3. **Check version / freshness.** If the doc is versioned (Terraform provider version, AWS API version, Python version, Nix channel), confirm it matches what the user is using. If the user has not stated a version, ask or state the assumption explicitly.
4. **Cross-check when stakes are high.** For anything going into production infrastructure, confirm with a second source — a GitHub issue, the official changelog, or a second doc page.
5. **If you cannot find it, say so.** "I searched the Terraform AWS provider docs and could not find `feature_x`. It may not exist under that name. Candidate alternatives based on what I did find: …"

## Citation format

Every non-trivial claim gets a source. Inline, lightweight, clickable. Deep-link to the specific section, not the homepage.

Short answers:

```
`terraform plan -target=<address>` runs a partial plan scoped to that resource address.
Source: https://developer.hashicorp.com/terraform/cli/commands/plan#resource-targeting
```

Longer answers with multiple sources — use reference-style footnotes to keep prose readable:

```
The `aws_ecs_service` resource exposes `deployment_circuit_breaker` inside its
deployment configuration, which triggers rollback on failed deployments [1]. This maps
to the ECS service-level circuit breaker feature [2].

[1]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service#deployment_circuit_breaker
[2]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-ecs.html#deployment-circuit-breaker
```

**Rules:**

- One cite per claim is enough; do not pile on.
- If a claim synthesizes multiple sources, cite each.
- **Never cite a URL you did not fetch.** Every URL in the answer was either returned by a tool call in this conversation or fetched just now. No reconstructing URLs from memory — doc paths change.
- If a tool call returned the page, that counts as fetched — include the URL.

## Uncertainty protocol — what to say when you don't know

Use these explicitly instead of guessing:

- **"I could not verify this in the docs."** — searched, did not find it.
- **"The docs describe X but do not specify Y."** — partial answer.
- **"This was true as of [version] — verify against your version."** — version-bounded claim.
- **"Best guess based on general patterns; please confirm before applying to production."** — only when asked for something genuinely undocumented (e.g., an internal tool's behavior) and the user has accepted that framing.
- **"I don't know."** — acceptable, often correct, preferred over invention.

When uncertain, offer a concrete verification step instead of guessing. Examples:

- "Run `aws ecs describe-services --services <name> --query 'services[0].deploymentConfiguration'` to see the live configuration."
- "`terraform providers schema -json | jq '.provider_schemas[\"registry.terraform.io/hashicorp/aws\"].resource_schemas.aws_ecs_service'` will print the exact argument schema for your installed provider version."
- "`nix-instantiate --eval -E '(import <nixpkgs/nixos> {}).options.services.openssh.enable.description'` shows the authoritative NixOS option description for your channel."

## Red flags — questions especially prone to hallucination

Escalate verification effort when:

- The user asks about a **very recent** feature, release, or version (especially post-knowledge-cutoff).
- The question involves **cross-tool integration** (e.g., "call this Terraform module from a CircleCI job using OIDC to assume an AWS role") — each hop multiplies error risk; verify each hop separately.
- The tool is **obscure** (small GitHub project, internal library) — Context7 and first-party docs may not cover it; say so rather than extrapolating.
- The question is about **default values, quotas, or limits** — these change and are often misremembered.
- The user asks for a **complete config file or module** — long outputs magnify per-token hallucination risk. Verify each non-trivial field or mark scaffolding explicitly (`# structural placeholder — verify against your setup`).
- The question involves **deprecated vs current** syntax (e.g., `aws_ecs_task_definition` `container_definitions` JSON vs. the newer block form, CircleCI 2.0 vs 2.1, Python 2 vs 3 idioms mixed online).

## Pre-response self-check

Before sending, run this mentally:

1. Every resource name, argument, CLI flag, and function signature I used was verified against a source I actually fetched in this turn. ✓
2. Every citation URL was produced by a tool call, not recalled from memory. ✓
3. Version assumptions are explicit (`AWS provider ≥ 5.0`, `Python ≥ 3.11`, `Terraform ≥ 1.6`). ✓
4. Anything I was unsure about is flagged as such or omitted. ✓
5. The answer would not break if pasted into code and run against current docs. ✓

If any box is unchecked: fix it, ask the user a clarifying question, or explicitly flag the gap before sending.

## Anti-patterns — never do these

- **Fabricating a flag that sounds right** (e.g., writing `--force-replace` when the actual flag is `-replace=<address>`). If you did not verify it, do not write it.
- **Citing a source you did not fetch.** Doc paths change; reconstructed URLs 404 or — worse — resolve to a different page and mislead the reader.
- **Rewriting the docs from memory.** Fetch and paraphrase; do not reconstruct.
- **"According to my knowledge" / "I believe" / "If I recall correctly"** — these are hallucination tells. Replace with a verified source or an explicit "I don't know."
- **Giving a long, confident answer with zero citations** when the topic required verification.
- **Guessing at version-specific behavior.** Bound the claim to a version with a source, or say it's unverified.
- **Inferring an error's root cause from the shape of the message** without looking up the actual message. AWS, Terraform, and Kubernetes error strings are googleable verbatim — search the literal message.

## Stack-specific patterns

### Terraform

**Primary sources:**
- Registry (per-provider resource docs): `https://registry.terraform.io/providers/<namespace>/<provider>/latest/docs/resources/<resource>`
- Core CLI & language: `https://developer.hashicorp.com/terraform/cli`, `https://developer.hashicorp.com/terraform/language`

**Tool routing:**
- Provider resources/data sources → `Context7:resolve-library-id` for e.g. `hashicorp/terraform-provider-aws`, then `query-docs`. If Context7 does not resolve, `Ref Documentation:ref_search_documentation` with `site:registry.terraform.io`.
- Core CLI, HCL syntax, state, meta-arguments, functions → `Ref Documentation` scoped to `developer.hashicorp.com`.
- Last resort: `web_fetch` on the specific resource page.

**Common traps:**
- Argument vs attribute confusion. Arguments (inputs) and attributes (outputs) are listed in separate sections. Verify which side before using in a `resource` block vs. a reference.
- Provider-version-bound features. Confirm minimum provider version in CHANGELOG on GitHub.
- Fabricated block names. Every valid block appears under the resource's Argument Reference.
- `lifecycle` sub-arguments: `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`, `precondition`, `postcondition`. Anything else is invalid.

**Verification shortcut:**
```bash
terraform providers schema -json \
  | jq '.provider_schemas["registry.terraform.io/hashicorp/aws"].resource_schemas.aws_ecs_service.block.attributes'
```

### AWS

**Tool routing:**
1. `AWS Knowledge:aws___search_documentation` with a narrow query.
2. `AWS Knowledge:aws___read_documentation` on the specific page returned.
3. For regional/service availability: `aws___get_regional_availability`, `aws___list_regions`.
4. For step-by-step workflows: `aws___retrieve_agent_sop`.
5. Fallback: `web_fetch` on the specific `docs.aws.amazon.com` URL.

**Common traps:**
- Service quotas change per region and per account. Never state a quota as fixed.
- IAM action names are case-sensitive and namespaced (`ecs:UpdateService`, not `ECS:updateService`).
- CLI flag shape: `aws ecs update-service --force-new-deployment` (kebab-case), Terraform uses `force_new_deployment` (snake_case). Never mix.

### Python and boto3

**Common traps:**
- boto3 method naming: `snake_case` in boto3, `PascalCase` in AWS API. Verify against boto3 service reference.
- Pagination: many list operations return only first page — check for `get_paginator()`.
- Waiters: not every resource has one — check "Waiters" section before suggesting `client.get_waiter(...)`.

### NixOS / Nix / Home Manager

**Common traps:**
- Channel drift: state channel assumption explicitly (`unstable`, `24.11`, `25.05`).
- Home Manager vs NixOS options live in different option trees.

**Verification shortcut:**
```bash
nix-instantiate --eval -E \
  '(import <nixpkgs/nixos> { configuration = {}; }).options.services.openssh.enable.description'
```

### GitHub Actions

**Common traps:**
- `if:` expression syntax: no curly braces on conditions, `${{ }}` everywhere else.
- OIDC to AWS: verify `role-to-assume` vs `role-arn` input naming — it changed between major versions.
- Permissions: `id-token: write` required for OIDC.

### CircleCI

**Common traps:**
- `version: 2.1` vs `version: 2` — orbs, executors, commands, parameters are 2.1-only.
- Orb namespacing: `namespace/orb-name@version` — verify exact version against orb registry.

### Go

**Common traps:**
- New stdlib packages need minimum Go version (e.g., `log/slog` in 1.21, `cmp`/`maps`/`slices` in 1.21).
- v2+ modules require `/v2` in import path.

## General research heuristic

1. Can I name the product and version? Search `"<product> <version> <exact-concept>"`.
2. Does a first-party doc site exist? Scope search to it.
3. Fetch the actual page. Read it. Do not trust the snippet.
4. If page is a changelog, verify feature exists in user's version specifically.
5. If no authoritative source exists, say so. Do not fill gap with a guess.
