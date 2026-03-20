# GitHub Rulesets

This directory contains **GitHub Repository Rulesets** for organization-wide governance.

Rulesets provide centralized enforcement of repository rules across all 1000 repositories.

---

## What GitHub Rulesets Solve ✅

GitHub Rulesets (introduced in 2023) allow **organization-level** enforcement of repository policies, automatically applied to all repos.

### Pre-Merge Governance (Centralized)

```json
{
  "name": "Production Branch Protection",
  "target": "branch",
  "enforcement": "active",
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 2,
        "require_code_owner_reviews": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "required_status_checks": [
          { "context": "CI / build-and-test" },
          { "context": "Security / code-scanning" },
          { "context": "Security / dependency-review" }
        ]
      }
    },
    {
      "type": "required_signatures",
      "parameters": {}
    }
  ]
}
```

**This applies automatically to all 1000 repositories.**

### What Rulesets Centralize

✅ **Branch protection**: Required reviews, approval counts, code owners
✅ **Required CI checks**: Tests, security scans, linting must pass before merge
✅ **Commit requirements**: Signed commits, linear history, no force pushes
✅ **Consistency**: Same rules across all 1000 repos, no per-repo configuration
✅ **Enforcement**: Impossible to bypass (enforced at API level)

**This is genuinely helpful and solves a real problem!**

Rulesets eliminate the need to configure branch protection separately in each repo.

---

## What GitHub Rulesets DON'T Solve ❌

### Limitation 1: Pre-Merge Only, NOT Deployment-Time

Rulesets control what happens **before code is merged** (Git-level governance).

They do **NOT** control what happens **during deployment** (runtime governance).

| What Rulesets CAN Enforce | What Rulesets CANNOT Enforce |
|---------------------------|-------------------------------|
| ✅ PR requires 2 approvals | ❌ Production deploy requires 2 approvals |
| ✅ CI tests must pass | ❌ Canary analysis must pass |
| ✅ Code scanning must pass | ❌ Deployment verification must pass |
| ✅ Commits must be signed | ❌ Images must be signed (they validate at deploy) |
| ✅ Staging deployment required | ❌ Must wait 1 hour between staging and prod |

**Example: What you CAN'T enforce with rulesets**

```yaml
# You CANNOT create a ruleset that says:
#
# "Production deployments require:
#   - 2 platform engineer approvals (at deployment time, not PR time)
#   - Successful canary analysis (error rate < 1%)
#   - At least 1 hour soak time in staging
#   - Automated rollback if P99 latency > 500ms
#   - No deployments on Fridays after 5pm
#   - Deployment must be signed off by security team"
#
# Rulesets only work at the Git/PR level, not deployment level
```

### Limitation 2: GitHub Environments Still Need Per-Repo Config

Even with rulesets, **GitHub Environments** are configured per-repository:

```bash
# Rulesets DON'T configure environments
# You STILL need to do this for all 1000 repos:

for repo in $(gh repo list myorg --limit 1000 --json name -q '.[].name'); do
  # Create production environment
  gh api repos/myorg/$repo/environments/production -X PUT \
    -f deployment_branch_policy=null

  # Configure deployment approvals (NOT controlled by rulesets)
  gh api repos/myorg/$repo/environments/production -X PUT \
    -f reviewers='[{"type":"Team","id":12345}]'

  # Add environment secrets
  gh secret set KUBE_CONFIG \
    --env production \
    --repo myorg/$repo \
    --body "$PROD_KUBE_CONFIG"
done

# Result: Still 3000 environment configurations
#         (1000 repos × 3 environments)
```

**Rulesets control branch protection, NOT deployment governance.**

### Limitation 3: Doesn't Reduce Deployment Tool Complexity

Even with perfect pre-merge governance via rulesets, you still need:

```
Deployment Infrastructure (Still Required):
├── ArgoCD (GitOps continuous delivery)
├── Argo Rollouts (Progressive delivery)
├── Istio (Service mesh for traffic splitting)
├── Prometheus (Metrics collection)
├── Grafana (Dashboards)
├── Custom deployment gate webhook (3 weeks to build)
├── Custom DORA metrics collector (3 weeks to build)
├── Custom policy enforcement service (3 weeks to build)
└── Secret management (HashiCorp Vault or similar)

Total: 24 tools to integrate and maintain
```

**Rulesets = 0 additional tools**
**Deployment infrastructure = still need 24 tools**

### Limitation 4: No Deployment Visibility or Control

```bash
# Questions rulesets CAN'T answer:
❌ Which version is deployed to production right now?
❌ When was the last deployment to staging?
❌ Which services deployed today?
❌ What's the deployment success rate this week?
❌ Can I rollback user-service to the previous version?
❌ Which deployments are currently in a canary state?
❌ What's the error rate of the current production deployment?

# Rulesets only know about branches and PRs, not deployments
```

### Limitation 5: Can't Prevent Deployment-Time Issues

**Scenario**: Code passes all PR checks and is merged to main.

**Rulesets ensure**:
- ✅ 2 reviewers approved the PR
- ✅ All CI tests passed
- ✅ Code scanning found no vulnerabilities
- ✅ Commits are signed

**Rulesets do NOT prevent**:
- ❌ Deploying to production without approval (deployment-time)
- ❌ Deploying a version that increases error rates by 50%
- ❌ Deploying to production immediately after staging (no soak time)
- ❌ Deploying outside business hours (e.g., Friday 6pm)
- ❌ Deploying during a production incident
- ❌ Deploying multiple services in the wrong order

**These are deployment-time governance issues, NOT Git-level issues.**

---

## Rulesets vs Harness Governance Policies

### GitHub Rulesets (Pre-Merge Governance)

```json
{
  "name": "Production Branch Protection",
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 2
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "required_status_checks": [
          { "context": "CI / build-and-test" }
        ]
      }
    }
  ]
}
```

**Scope**: Controls what gets merged to main branch
**Applied**: Before code is merged
**Enforces**: Code quality, test coverage, security scans

### Harness Governance Policies (Deployment-Time Governance)

```yaml
# Organization-level policy (applies to all 1000 services)
policy:
  name: "Production Deployment Policy"
  enforcement: mandatory
  scope: production  # Applies only to production deployments

  rules:
    # Deployment approvals (NOT PR approvals)
    - approval:
        minimumCount: 2
        userGroups: ["platform-engineers", "security-team"]
        timeout: 24h
        approvalMessage: "Production deployment for ${service.name} v${artifact.tag}"

    # Automated verification (statistical analysis)
    - verification:
        type: Auto  # ML-based anomaly detection
        sensitivity: MEDIUM
        duration: 10m
        metrics:
          - error_rate < 1%
          - latency_p99 < 500ms
          - cpu_usage < 80%
        failureStrategy:
          action: ROLLBACK  # Auto-rollback on failure

    # Time delay between environments
    - stagingGate:
        minimumSoakTime: 1h
        requiredEnvironment: staging
        requireSuccessfulDeployment: true

    # Deployment windows
    - deploymentWindow:
        environment: production
        allowedDays: ["Mon", "Tue", "Wed", "Thu"]
        allowedHours: "09:00-17:00"
        timezone: "America/New_York"
        blockOnIncidents: true  # Check PagerDuty for active incidents

    # Freeze periods
    - freeze:
        periods:
          - name: "Holiday Freeze"
            start: "2024-12-20"
            end: "2024-01-02"
          - name: "Black Friday Freeze"
            start: "2024-11-25"
            end: "2024-11-29"

    # Multi-service orchestration
    - dependencies:
        mustDeployFirst: ["database-migration"]
        mustDeployAfter: []
        parallelDeploymentAllowed: false

    # Audit and compliance
    - audit:
        requireJiraTicket: true
        requireChangeRequest: true
        notifyOnDeployment: ["#production-deploys"]
```

**Scope**: Controls what gets deployed to production
**Applied**: During deployment
**Enforces**: Deployment safety, operational standards, business rules

---

## Real-World Deployment Scenarios

### Scenario 1: Prevent Deployment with High Error Rate

**GitHub Rulesets**: ❌ Can't prevent this
- Code passed all PR checks (tests, security scans)
- Code was merged to main
- Ruleset job is done (enforced PR rules)

**Problem**: Deployment increases error rate from 0.1% to 5%
- Rulesets don't monitor production metrics
- Rulesets don't trigger rollback
- Manual intervention required

**Harness Policy**: ✅ Prevents and auto-remediates
```yaml
- verification:
    type: Auto
    metrics: { error_rate < 1% }
    failureStrategy: { action: ROLLBACK }
```
- Deployment proceeds to 25% traffic (canary)
- Harness detects error rate at 5%
- Automatically rolls back
- Notifies platform team

### Scenario 2: Prevent Friday Evening Deployments

**GitHub Rulesets**: ❌ Can't prevent this
- Code can be merged to main any time
- Deployment can be triggered any time
- No concept of "deployment windows"

**Harness Policy**: ✅ Enforces deployment windows
```yaml
- deploymentWindow:
    allowedDays: ["Mon", "Tue", "Wed", "Thu"]
    allowedHours: "09:00-17:00"
```
- Deployment attempted Friday 6pm
- Harness blocks: "Outside deployment window"
- Provides next available time: Monday 9am

### Scenario 3: Require Staging Soak Time

**GitHub Rulesets**: ❌ Can't enforce this
- Can require "staging deployment" before prod
- Can't enforce time delay (soak time)
- Developer can deploy to prod immediately after staging

**Harness Policy**: ✅ Enforces soak time
```yaml
- stagingGate:
    minimumSoakTime: 1h
    requiredEnvironment: staging
```
- Staging deployed at 10:00am
- Production deploy attempted at 10:15am
- Harness blocks: "Staging soak time not met (45min remaining)"

---

## What You Still Need Even With Rulesets

Even with perfect GitHub Rulesets for pre-merge governance, you still need:

### 1. **GitHub Environments (3000 configurations)**

```bash
# One for each repo × each environment
user-service: dev, staging, production
payment-service: dev, staging, production
# ... × 1000 repos = 3000 configurations
```

### 2. **Deployment Tools (24 tools)**

- ArgoCD, Argo Rollouts, Istio, Prometheus, Grafana
- Trivy, Grype, Syft, Cosign, Conftest
- Custom webhooks, metrics collectors, policy services

### 3. **Custom Services (6 services, 17 weeks to build)**

- Deployment gate webhook
- DORA metrics collector
- Policy enforcement service
- Environment automation
- Secret rotation service
- Deployment verification service

### 4. **Operational Burden (2-4 FTE)**

- Daily: Triage deployment failures, debug integrations
- Weekly: Update policies, review metrics
- Monthly: Rotate credentials, update dependencies
- Quarterly: Tool upgrades, security patches

### 5. **5-Year TCO ($5.2M)**

- Year 1: $1,277,000 (build + operate)
- Years 2-5: $902k-$1,082k/year (operate)

**Rulesets reduce none of this.**

---

## Summary: GitHub Rulesets

### What They Solve ✅

✅ **Centralized branch protection** (genuinely helpful!)
✅ **Pre-merge governance** (required reviews, CI checks, signed commits)
✅ **Consistency across 1000 repos** (same rules everywhere)
✅ **Enforcement** (impossible to bypass at Git level)

### What They Don't Solve ❌

❌ **Deployment approvals** (still need GitHub Environments × 3000)
❌ **Deployment gates** (still need custom webhooks)
❌ **Progressive delivery** (still need Argo Rollouts + Istio)
❌ **Deployment verification** (still need custom Prometheus queries)
❌ **Automated rollback** (still manual)
❌ **Deployment observability** (no dashboard or metrics)
❌ **Deployment windows** (can't enforce "no Friday deploys")
❌ **Soak time requirements** (can't enforce "wait 1 hour between envs")
❌ **The 24 deployment tools** (still need to integrate and maintain)
❌ **The 6 custom services** (still need to build)
❌ **Operational burden** (still 2-4 FTE)
❌ **Cost** (still $5.2M over 5 years)

---

## Recommendation

**Use GitHub Rulesets** for:
- ✅ Branch protection (required reviews, status checks)
- ✅ Pre-merge governance (code quality gates)
- ✅ Consistency across repos

**Don't expect Rulesets to solve**:
- ❌ Deployment-time governance
- ❌ Progressive delivery
- ❌ Deployment verification and rollback
- ❌ Operational burden at scale

**Both are needed:**
- **GitHub Rulesets**: Control what goes into Git (pre-merge)
- **Harness Policies**: Control what goes into production (deployment-time)

**See [HARNESS_COMPARISON.md](../../docs/HARNESS_COMPARISON.md) for the complete analysis.**

---

## How to Apply Organization Rulesets

```bash
# Using GitHub CLI to create organization-wide ruleset:

gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  /orgs/YOUR_ORG/rulesets \
  --input production-branch-protection.json

# This applies to ALL repositories in the organization
# No per-repo configuration needed
```

**This is one of GitHub's best features for enterprise governance at scale.**

**But it only solves pre-merge governance, not deployment governance.**
