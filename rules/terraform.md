---
description: Terraform and IaC conventions
paths: ["**/*.tf", "**/*.tfvars", "**/*.hcl"]
---

Project-level rules (`.claude/rules/`, `CLAUDE.md`) override everything here — check them first, including naming/tagging schemes and validation commands. Verify any command or path against the actual repo before running it; project docs can be stale.

## Core (any cloud)

- Terraform >= 1.7; pin `required_version` and provider versions (`~>` constraints) in every root module
- Validation pipeline: `terraform fmt -check` → `validate` → `tflint` → `checkov`/`trivy` → `plan`. Run all of it; report results with real output, never claim a step passed without running it
- Plan review: every `destroy`/`replace` must be explained and intended — an unexpected one stops the work. Drift unrelated to the change gets reported separately, never silently absorbed into the PR. If a destroy depends on an out-of-band action, state the required ordering
- Applies: if the project uses remote applies (Terraform Cloud, Atlantis, CI), never `terraform apply` locally
- One state file per environment per service; never share state across blast-radius boundaries
- Naming: `{service}-{env}-{resource}` unless the project defines its own; tag all resources: Environment, Service/Group, Owner, ManagedBy=terraform (use provider `default_tags` where supported)
- Stateful resources (databases, key vaults, storage with data): `lifecycle { prevent_destroy = true }`
- Attributes managed out-of-band: `lifecycle { ignore_changes = [...] }` with a comment saying why and where the runbook lives
- Least-privilege IAM — no `*` actions/resources in production policies
- Encrypt at rest (KMS/CMK) and in transit (TLS)
- Modules: pin sources by version/ref; expose variables with types, descriptions, and `validation` blocks; mark sensitive outputs `sensitive = true`

## Secrets & state

- `sensitive = true` only masks CLI output — the value still sits in **plaintext in state**. Acceptable for credentials already entrusted to the state backend; never acceptable for certificate/PFX blobs, private keys, or their passwords — keep those out of Terraform entirely, manage out-of-band, and document the runbook
- Never hardcode secrets in `.tf`/`.tfvars`; source from the platform's secret store (SSM/Secrets Manager, Key Vault, TF Cloud workspace variables)
- Org policy (Azure Policy, AWS SCP) may reject resources created without required tags — this applies to out-of-band CLI creations too; tag them consistently and mark them as not-Terraform-managed (e.g. `Terraform = "false"`)

## AWS

- Prefer AWSCC provider, fall back to AWS provider when needed
- Remote state: S3 with native locking (`use_lockfile = true`, TF >= 1.11); DynamoDB locking is deprecated — migrate off it
- Terragrunt `include`, `dependency`, `generate` for DRY multi-env

## Azure

- azurerm + azapi (azapi only for preview APIs; `schema_validation_enabled = false` only when the API version is preview)
- Prefer Azure Verified Modules (`Azure/avm-*`), pinned version, `enable_telemetry = false`
- Remote state: Terraform Cloud or azurerm backend with state locking
- Private endpoints + private DNS zones over public network access; diagnostic settings to Log Analytics on every significant resource
