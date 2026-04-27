# Agent Orchestration System

## Overview

This document defines how agents work as a team, reviewing and validating each other's work based on the type of issue. The **Lead** (main Claude session) orchestrates the workflow, routing tasks to specialists and ensuring quality gates are passed.

---

## Agent Roster

| Agent                           | Role                  | Specialty                                                           | Model  |
| ------------------------------- | --------------------- | ------------------------------------------------------------------- | ------ |
| **principal-software-engineer** | **Lead/Orchestrator** | Technical leadership, engineering excellence, workflow coordination | sonnet |
| **backend-architect**           | Architect             | API design, service boundaries, scalability                         | sonnet |
| **database-architect**          | Architect             | Data modeling, DB selection, CQRS/event sourcing                    | opus   |
| **devops-engineer**             | Implementer           | CI/CD, infrastructure, deployment                                   | sonnet |
| **database-optimization**       | Implementer           | Query tuning, indexing, performance                                 | sonnet |
| **error-detective**             | Investigator          | Log analysis, error patterns, root cause                            | sonnet |
| **code-reviewer**               | Quality Gate          | Code quality, security, maintainability                             | sonnet |
| **context-manager**             | Coordinator           | Context preservation, session handoffs                              | opus   |
| **search-specialist**           | Researcher            | Web research, documentation, trends                                 | haiku  |
| **mcp-expert**                  | Specialist            | MCP server configurations, integrations                             | sonnet |

### Lead Role: `principal-software-engineer`

The **principal-software-engineer** serves as the team lead and workflow orchestrator:

- **Triage**: Classifies issues and selects appropriate workflow
- **Coordination**: Spawns specialists in correct sequence
- **Quality Bar**: Ensures engineering fundamentals are maintained
- **Technical Debt**: Creates GitHub issues for deferred work
- **Final Review**: Synthesizes outputs before presenting to user
- **Escalation**: Decides when to escalate to user for decisions

When to spawn the Lead explicitly:

- Complex multi-agent workflows requiring coordination
- Technical debt assessment and remediation planning
- Architecture decisions needing principal-level guidance
- When multiple specialists need orchestration

---

## Workflow Patterns

### Pattern 1: DESIGN → IMPLEMENT → REVIEW → APPROVE

```
principal-software-engineer → Architect → Implementer → code-reviewer → principal-software-engineer → User
                                                ↑___________________|
                                                (if issues found)
```

### Pattern 2: INVESTIGATE → DIAGNOSE → FIX → VALIDATE

```
principal-software-engineer → error-detective → Architect → Implementer → code-reviewer → principal-software-engineer → User
                                     ↓
                               (root cause)
```

### Pattern 3: RESEARCH → DESIGN → IMPLEMENT → REVIEW

```
principal-software-engineer → search-specialist → Architect → Implementer → code-reviewer → principal-software-engineer → User
```

---

## Issue-Specific Workflows

### 1. DevOps / Infrastructure Issue

**Trigger**: CI/CD failures, deployment issues, infrastructure changes, scaling needs

```
WORKFLOW: devops-pipeline
Step 1: TRIAGE (Lead)
   └─ Classify: deployment | infrastructure | monitoring | security
Step 2: ARCHITECTURE REVIEW (backend-architect)
   └─ If infrastructure change affects services
   └─ Output: Architecture impact assessment
   └─ Pass criteria: No breaking changes to service contracts
Step 3: IMPLEMENTATION (devops-engineer)
   └─ Implement CI/CD, Terraform, Kubernetes changes
   └─ Output: Configuration files, scripts, documentation
   └─ Pass criteria: All configs valid, security best practices
Step 4: REVIEW (code-reviewer)
   └─ Review for: security vulnerabilities, best practices, completeness
   └─ Output: Approval or rejection with specific issues
   └─ If REJECTED → return to Step 3 with feedback
Step 5: APPROVAL (Lead)
   └─ Summarize changes for user
   └─ Present deployment plan
```

**Example invocation**:

```
Lead: "I'll orchestrate this deployment issue using the devops workflow."
1. Task(backend-architect): "Review this infrastructure change for service impact..."
2. Task(devops-engineer): "Implement the Terraform changes based on architect review..."
3. Task(code-reviewer): "Review the devops changes for security and best practices..."
```

---

### 2. Backend Feature Development

**Trigger**: New API endpoints, service changes, business logic

```
WORKFLOW: backend-feature
Step 1: TRIAGE (Lead)
   └─ Gather requirements from user
   └─ Check existing patterns in codebase
Step 2: ARCHITECTURE (backend-architect)
   └─ Design API contracts, service boundaries
   └─ Output: API specs, service diagrams, data flow
   └─ Pass criteria: RESTful, scalable, consistent with existing patterns
Step 3: DATABASE DESIGN (database-architect) [if data model changes]
   └─ Review data model, migrations, indexes
   └─ Output: Schema changes, migration plan
   └─ Pass criteria: Normalized, indexed, backward compatible
Step 4: IMPLEMENTATION (Lead or spawned implementer)
   └─ Write the code following architect specs
   └─ Output: Code changes
Step 5: REVIEW (code-reviewer)
   └─ Review for: quality, security, test coverage
   └─ Output: Approval or rejection
   └─ If REJECTED → return to Step 4 with feedback
Step 6: CONTEXT SAVE (context-manager) [for complex features]
   └─ Document decisions for future reference
```

---

### 3. Database Performance Issue

**Trigger**: Slow queries, high load, scaling concerns

```
WORKFLOW: database-performance
Step 1: INVESTIGATE (database-optimization)
   └─ Analyze slow query logs, EXPLAIN plans
   └─ Output: Performance report, bottleneck identification
   └─ Pass criteria: Clear root cause identified
Step 2: ARCHITECTURE REVIEW (database-architect) [if schema changes needed]
   └─ Review schema design, indexing strategy
   └─ Output: Optimization recommendations
   └─ Pass criteria: Maintains data integrity, backward compatible
Step 3: IMPLEMENTATION (database-optimization)
   └─ Create indexes, optimize queries, add caching
   └─ Output: SQL migrations, query rewrites
   └─ Pass criteria: Measurable performance improvement
Step 4: REVIEW (code-reviewer)
   └─ Review migrations, ensure no regressions
   └─ Output: Approval or rejection
   └─ If REJECTED → return to Step 3
Step 5: VALIDATION (database-optimization)
   └─ Run benchmarks, compare before/after
   └─ Output: Performance metrics
```

---

### 4. Production Error Investigation

**Trigger**: Error spikes, customer reports, alert fires

```
WORKFLOW: error-investigation
Step 1: DETECT (error-detective)
   └─ Parse logs, identify error patterns
   └─ Correlate with recent deployments
   └─ Output: Error timeline, affected components, hypothesis
Step 2: ANALYZE (backend-architect or database-architect)
   └─ Based on error type, route to appropriate architect
   └─ Output: Root cause confirmation, fix approach
Step 3: FIX (Lead or appropriate implementer)
   └─ Implement the fix
   └─ Output: Code/config changes
Step 4: REVIEW (code-reviewer)
   └─ Fast-track review for production issues
   └─ Focus: Does it fix the issue? Any new risks?
   └─ If REJECTED → return to Step 3
Step 5: MONITOR (error-detective)
   └─ Provide monitoring queries to verify fix
   └─ Output: Alerting rules, dashboard queries
```

---

### 5. Security Vulnerability

**Trigger**: Security audit findings, CVE reports, penetration test results

```
WORKFLOW: security-fix
Step 1: ASSESS (code-reviewer)
   └─ Evaluate severity, attack vectors
   └─ Output: Risk assessment, affected components
Step 2: RESEARCH (search-specialist) [if unknown vulnerability]
   └─ Research CVE, find patches, best practices
   └─ Output: Remediation options
Step 3: ARCHITECTURE (backend-architect)
   └─ Design fix approach, ensure no regressions
   └─ Output: Fix specification
Step 4: IMPLEMENTATION (Lead)
   └─ Implement security fix
   └─ Output: Code changes
Step 5: REVIEW (code-reviewer)
   └─ Security-focused review
   └─ OWASP checklist validation
   └─ If REJECTED → return to Step 4
Step 6: VALIDATION (devops-engineer)
   └─ Update security scanning configs
   └─ Verify fix in staging
```

---

### 6. New Integration / MCP Setup

**Trigger**: New external service integration, MCP server creation

```
WORKFLOW: integration-setup
Step 1: RESEARCH (search-specialist)
   └─ Research API documentation, best practices
   └─ Output: Integration requirements, auth methods
Step 2: ARCHITECTURE (backend-architect)
   └─ Design integration pattern, error handling
   └─ Output: Integration architecture
Step 3: MCP CREATION (mcp-expert) [if MCP needed]
   └─ Create MCP server configuration
   └─ Output: MCP JSON config, setup docs
Step 4: IMPLEMENTATION (Lead)
   └─ Implement integration code
   └─ Output: Service code, tests
Step 5: REVIEW (code-reviewer)
   └─ Review security, error handling, rate limiting
   └─ If REJECTED → return to Step 4
```

---

### 7. Complex Multi-Session Project

**Trigger**: Large features spanning multiple sessions

```
WORKFLOW: long-running-project
Step 1: SETUP (context-manager)
   └─ Create project context file
   └─ Document goals, constraints, progress
   └─ Output: Context index for future sessions
Step 2: [Execute appropriate workflow per task]
Step 3: CHECKPOINT (context-manager)
   └─ After each major milestone
   └─ Update context, document decisions
   └─ Prune stale information
Step 4: HANDOFF (context-manager)
   └─ Prepare briefing for next session
   └─ Output: Quick context for continuation
```

---

## Review Gate Criteria

### Code Reviewer Checklist

**MUST PASS**:

- [ ] No exposed secrets or credentials
- [ ] Input validation on all external inputs
- [ ] Proper error handling
- [ ] No SQL injection, XSS, or OWASP Top 10 vulnerabilities
- [ ] Tests exist for new functionality

**SHOULD PASS**:

- [ ] Code is readable and well-named
- [ ] No unnecessary duplication
- [ ] Performance considerations addressed
- [ ] Documentation updated if needed

**REJECTION TRIGGERS**:

- Critical security vulnerability
- Missing tests for core logic
- Breaking changes without migration path
- Exposed credentials

---

## Orchestration Commands

### For the Lead to invoke workflows

```markdown
# DevOps Issue

"I'll handle this using the devops-pipeline workflow:

1. First, I'll have backend-architect assess service impact
2. Then devops-engineer will implement
3. Finally, code-reviewer will validate"

# Error Investigation

"This looks like a production error. Starting error-investigation workflow:

1. error-detective will analyze logs and identify patterns
2. Based on findings, I'll route to the appropriate architect
3. After fix, code-reviewer will fast-track review"

# Feature Development

"For this new feature, I'll use backend-feature workflow:

1. backend-architect will design the API contract
2. database-architect will review any schema changes
3. I'll implement following the specs
4. code-reviewer will ensure quality"
```

---

## Parallel Execution Rules

**CAN run in parallel**:

- Research (search-specialist) + Architecture design (if independent)
- Multiple code-reviewers on different files
- Database optimization analysis + Error log analysis

**MUST run sequentially**:

- Architecture → Implementation (implementation depends on design)
- Implementation → Review (review depends on code)
- Review rejection → Re-implementation (fix depends on feedback)

---

## Escalation Paths

### When to escalate to user

1. **Conflicting requirements**: Architects disagree on approach
2. **Security vs. Speed tradeoff**: Need business decision
3. **Breaking changes**: Require user approval
4. **Multiple review rejections**: 3+ iterations without resolution
5. **Out of scope**: Task requires capabilities not available

### Escalation format

```markdown
## Escalation Required

**Issue**: [Brief description]
**Workflow Stage**: [Which step]
**Options**:

1. [Option A] - [Tradeoff]
2. [Option B] - [Tradeoff]

**Recommendation**: [Agent's recommendation if any]
**Blocking**: [What's blocked until resolved]
```

---

## Quick Reference

| Issue Type   | Start With            | Key Reviewers                        |
| ------------ | --------------------- | ------------------------------------ |
| API/Backend  | backend-architect     | code-reviewer                        |
| Database     | database-architect    | database-optimization, code-reviewer |
| DevOps/Infra | backend-architect     | devops-engineer, code-reviewer       |
| Errors/Bugs  | error-detective       | backend-architect, code-reviewer     |
| Performance  | database-optimization | backend-architect                    |
| Security     | code-reviewer         | backend-architect                    |
| Integration  | search-specialist     | mcp-expert, code-reviewer            |
| Research     | search-specialist     | backend-architect                    |

---

## Example: Full DevOps Workflow Execution

```markdown
User: "Our CircleCI pipeline is failing on the staging deployment"

principal-software-engineer: "I'll investigate this using the devops-pipeline workflow."

--- Step 1: TRIAGE ---
principal-software-engineer: Checking CI logs... This is a deployment failure, classified as 'deployment'.

--- Step 2: ARCHITECTURE REVIEW ---
principal-software-engineer spawns: Task(backend-architect)
Prompt: "Review the current deployment configuration and recent changes.
Check if any service contract changes affect deployment.
Files: .circleci/config.yml, docker-compose.yml, helm/"

backend-architect returns:
"No service contract changes. Issue appears to be infrastructure-level.
Helm chart has outdated image tag reference. Safe to proceed with fix."

--- Step 3: IMPLEMENTATION ---
principal-software-engineer spawns: Task(devops-engineer)
Prompt: "Fix the CircleCI deployment failure. Architect confirmed it's an
outdated image tag in Helm. Update the configuration and ensure
proper image tag propagation."

devops-engineer returns:
"Fixed. Changes:

1.  Updated helm-chart/values.yaml to use {{ .Values.image.tag }}
2.  Modified .circleci/config.yml to pass image tag correctly
3.  Added validation step before deployment"

--- Step 4: REVIEW ---
principal-software-engineer spawns: Task(code-reviewer)
Prompt: "Review the devops changes for security and best practices.
Focus on: secrets handling, deployment safety, rollback capability."

code-reviewer returns:
"APPROVED with suggestions:

- Critical: None
- Warnings: Consider adding deployment timeout
- Suggestions: Add Slack notification on failure
  Changes are safe to deploy."

--- Step 5: APPROVAL ---
principal-software-engineer to User:
"Fixed the CircleCI deployment failure:

- Root cause: Helm chart had hardcoded image tag
- Fix: Dynamic tag passing from CI to Helm
- Reviewed: Passed security and best practices review

Ready to commit and test. Shall I proceed?"
```
