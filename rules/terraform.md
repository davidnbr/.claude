---
description: Terraform and IaC conventions
paths: ["**/*.tf", "**/*.tfvars", "**/*.hcl"]
---

- Prefer AWSCC provider, fall back to AWS provider when needed
- Naming: `{service}-{env}-{resource}`
- Validation: `terraform fmt` → `validate` → `checkov` → `plan`
- Least-privilege IAM — no wildcards in production
- Encrypt at rest (KMS) and in transit (TLS)
- Tag all resources: Environment, Service, Owner, ManagedBy=terraform
- Remote state: S3 + DynamoDB for locking
- One state file per environment per service
- Use Terragrunt `include`, `dependency`, `generate` for DRY multi-env
