---
description: Terraform and IaC conventions
paths: ["**/*.tf", "**/*.tfvars", "**/*.hcl"]
---

- Terraform >= 1.7; pin `required_version` and provider versions (`~>` constraints) in every root module
- Prefer AWSCC provider, fall back to AWS provider when needed
- Naming: `{service}-{env}-{resource}`; tag all resources: Environment, Service, Owner, ManagedBy=terraform (use provider `default_tags` where supported)
- Validation pipeline: `terraform fmt -check` → `validate` → `checkov`/`trivy` → `plan` (review before apply)
- Least-privilege IAM — no `*` actions/resources in production policies
- Encrypt at rest (KMS) and in transit (TLS); never put secrets in state-visible plaintext variables — use SSM/Secrets Manager data sources
- Remote state: S3 with native locking (`use_lockfile = true`, TF >= 1.11); DynamoDB locking is deprecated — migrate off it
- One state file per environment per service; never share state across blast-radius boundaries
- Terragrunt `include`, `dependency`, `generate` for DRY multi-env
- Modules: pin sources by version/ref; expose variables with types, descriptions, and `validation` blocks; mark sensitive outputs `sensitive = true`
