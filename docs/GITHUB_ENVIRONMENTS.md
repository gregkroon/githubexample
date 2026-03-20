# GitHub Environments Configuration

## Overview

GitHub Environments provide deployment gates with:
- Required reviewers
- Wait timers
- Branch restrictions
- Custom deployment protection rules (webhooks)

**CRITICAL LIMITATION**: These must be configured **per repository** via UI or API.
At 1000+ repos, this becomes a significant operational burden.

## Environment Hierarchy

```
dev → staging → production
```

## Environment Configuration

### Dev Environment

**Purpose**: Rapid iteration, auto-deploy on merge to main

```yaml
name: dev
deployment_branch_policy:
  protected_branches: false
  custom_branch_policies: true
  custom_branches:
    - main
    - develop

protection_rules:
  reviewers: []  # No manual approval required
  wait_timer: 0  # No wait time
  prevent_self_review: false

secrets:
  CLUSTER_NAME: dev-cluster
  CLOUD_PROJECT: myorg-dev

variables:
  ENVIRONMENT: dev
  LOG_LEVEL: debug
```

**Automation**: Auto-deploy on every merge to main

---

### Staging Environment

**Purpose**: Pre-production testing, requires tech lead approval

```yaml
name: staging
deployment_branch_policy:
  protected_branches: true
  custom_branch_policies: false

protection_rules:
  reviewers:
    - type: teams
      teams:
        - platform-engineering
        - tech-leads
      required_count: 1

  wait_timer: 300  # 5 minute wait before deployment

  prevent_self_review: true

  # Custom deployment protection rule (webhook)
  custom_deployment_protection_rules:
    - name: dev-metrics-validation
      endpoint: https://deployment-gates.example.com/validate/staging
      enabled: true

secrets:
  CLUSTER_NAME: staging-cluster
  CLOUD_PROJECT: myorg-staging

variables:
  ENVIRONMENT: staging
  LOG_LEVEL: info
```

**Approval Flow**:
1. Developer merges to main
2. Dev deployment completes successfully
3. 5-minute wait timer starts
4. Custom webhook validates dev metrics
5. Requires 1 tech lead approval
6. Staging deployment proceeds

---

### Production Environment

**Purpose**: Production workloads, strict controls

```yaml
name: production
deployment_branch_policy:
  protected_branches: true
  custom_branch_policies: false

protection_rules:
  reviewers:
    - type: teams
      teams:
        - platform-engineering
      required_count: 2  # Requires 2 approvals

  wait_timer: 1800  # 30 minute wait

  prevent_self_review: true

  # Multiple protection rules
  custom_deployment_protection_rules:
    - name: staging-validation
      endpoint: https://deployment-gates.example.com/validate/production
      enabled: true

    - name: business-hours-check
      endpoint: https://deployment-gates.example.com/business-hours
      enabled: true

    - name: incident-status-check
      endpoint: https://deployment-gates.example.com/incidents
      enabled: true

    - name: compliance-scan
      endpoint: https://deployment-gates.example.com/compliance
      enabled: true

secrets:
  CLUSTER_NAME: prod-cluster
  CLOUD_PROJECT: myorg-prod

variables:
  ENVIRONMENT: production
  LOG_LEVEL: warn
```

**Approval Flow**:
1. Staging deployment completes successfully
2. 30-minute wait timer (allows time to catch issues in staging)
3. Custom webhooks validate:
   - Staging metrics are healthy
   - Within business hours (9 AM - 5 PM, Mon-Fri)
   - No active incidents
   - Compliance requirements met
4. Requires 2 platform engineer approvals
5. Production deployment proceeds

---

## Custom Deployment Protection Rules (Webhooks)

GitHub can call external webhooks to approve/reject deployments.

### Webhook Service Implementation

We must build and maintain a highly available service:

```
┌─────────────────────────────────────────────────────┐
│  GitHub Actions Workflow                            │
│  (waiting for environment approval)                  │
└────────────────┬────────────────────────────────────┘
                 │
                 │ POST /deployments/{deployment_id}
                 ▼
┌─────────────────────────────────────────────────────┐
│  Deployment Gate Service                            │
│  (custom service we must build)                     │
│  ├── Validate metrics from previous environment     │
│  ├── Check incident management system               │
│  ├── Verify business hours                          │
│  ├── Check compliance requirements                  │
│  └── Return: { "approved": true/false, "reason": ""}│
└────────────────┬────────────────────────────────────┘
                 │
                 │ If approved
                 ▼
┌─────────────────────────────────────────────────────┐
│  GitHub Environment                                  │
│  (deployment proceeds)                               │
└─────────────────────────────────────────────────────┘
```

### Webhook Request Format

```json
{
  "deployment": {
    "id": 123456,
    "sha": "abc123...",
    "ref": "refs/heads/main",
    "environment": "production",
    "creator": {
      "login": "developer"
    }
  },
  "repository": {
    "full_name": "myorg/user-service"
  }
}
```

### Webhook Response Format

```json
{
  "approved": true,
  "reason": "All validation checks passed",
  "checks": [
    {
      "name": "staging-metrics",
      "status": "passed",
      "details": "Error rate: 0.01%, Latency p99: 150ms"
    },
    {
      "name": "business-hours",
      "status": "passed",
      "details": "Current time: 2:30 PM EST, within deployment window"
    },
    {
      "name": "incidents",
      "status": "passed",
      "details": "No active P0/P1 incidents"
    }
  ]
}
```

---

## Operational Challenges

### 1. Configuration at Scale

**Problem**: 1000 repos × 3 environments = 3000 environment configurations

**Solutions**:

#### Option A: Manual UI Configuration
- Time: ~5 minutes per environment
- Total: 3000 × 5 = 15,000 minutes = **250 hours**
- NOT SCALABLE

#### Option B: GitHub API + Terraform
```hcl
resource "github_repository_environment" "production" {
  for_each    = var.repositories
  repository  = each.key
  environment = "production"

  reviewers {
    teams = [data.github_team.platform.id]
  }

  deployment_branch_policy {
    protected_branches     = true
    custom_branch_policies = false
  }
}
```

**Challenges**:
- API rate limits (5000 requests/hour)
- State management for 1000+ repos
- Terraform state file size
- Requires GitHub Admin token

#### Option C: GitHub API + Custom Automation
```python
# automation/setup-environments.py
for repo in get_all_repositories():
    for env in ['dev', 'staging', 'production']:
        create_environment(repo, env, config[env])
        set_reviewers(repo, env, reviewers[env])
        set_secrets(repo, env, secrets[env])
        set_variables(repo, env, variables[env])
```

**Still requires**:
- Custom tooling
- Error handling
- Idempotency
- Audit logging

---

### 2. Secret Management

**Problem**: Each environment needs cloud credentials, API keys, etc.

**At Scale**:
- 1000 repos × 3 environments × 5 secrets = **15,000 secret configurations**

**Options**:

#### Option A: GitHub Secrets (current approach)
- Secrets stored per repo/environment
- Rotation requires updating 15,000 values
- No centralized management
- **DOES NOT SCALE**

#### Option B: External Secrets + OIDC (recommended)
```yaml
# Use OIDC to federate to cloud provider
- name: Authenticate to GCP
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: 'projects/.../providers/github'
    service_account: 'github-actions@project.iam.gserviceaccount.com'
```

**Benefits**:
- No long-lived credentials
- Centralized IAM management
- Automatic rotation

**Still needs**:
- OIDC configuration per repo (or org-wide)
- Cloud IAM setup
- Service account management

#### Option C: HashiCorp Vault Integration
```yaml
- name: Import Secrets
  uses: hashicorp/vault-action@v2
  with:
    url: https://vault.example.com
    method: jwt
    role: github-actions
    secrets: |
      secret/data/production/database password | DB_PASSWORD
```

**Benefits**:
- Centralized secret management
- Automatic rotation
- Audit logging

**Adds**:
- Another system to maintain (Vault)
- Custom GitHub Action
- Vault authentication setup

---

### 3. Environment Drift

**Problem**: Configuration drift across 1000 repos

**Scenarios**:
- Developer manually changes environment config
- Different teams use different approval requirements
- Secrets expire and aren't rotated
- Protection rules become out of sync

**Mitigation**:
- Continuous compliance scanning
- Automated drift detection
- Policy-as-code enforcement

**Requires**:
- Custom tooling
- Monitoring
- Remediation workflows

---

### 4. Webhook Service Reliability

**CRITICAL**: If webhook service is down, ALL deployments are blocked.

**Requirements**:
- High availability (99.9%+)
- Low latency (< 1 second response)
- Comprehensive monitoring
- Fallback strategy

**Complexity**:
- Multi-region deployment
- Load balancing
- Database for state
- Authentication/authorization
- Rate limiting
- Audit logging

**Cost**:
- Infrastructure
- Development time
- Ongoing maintenance

---

## Configuration Automation Script

Example Terraform for managing environments:

```hcl
# terraform/github-environments.tf

locals {
  services = toset([
    "user-service",
    "payment-service",
    "notification-service",
    # ... 997 more services
  ])

  environments = {
    dev = {
      reviewers      = []
      wait_timer     = 0
      protected_only = false
    }
    staging = {
      reviewers      = [var.tech_leads_team_id]
      wait_timer     = 300
      protected_only = true
    }
    production = {
      reviewers      = [var.platform_team_id]
      wait_timer     = 1800
      protected_only = true
    }
  }
}

resource "github_repository_environment" "env" {
  for_each = {
    for pair in setproduct(local.services, keys(local.environments)) :
    "${pair[0]}-${pair[1]}" => {
      repository  = pair[0]
      environment = pair[1]
      config      = local.environments[pair[1]]
    }
  }

  repository  = each.value.repository
  environment = each.value.environment

  dynamic "reviewers" {
    for_each = each.value.config.reviewers
    content {
      teams = [reviewers.value]
    }
  }

  wait_timer = each.value.config.wait_timer

  deployment_branch_policy {
    protected_branches     = each.value.config.protected_only
    custom_branch_policies = !each.value.config.protected_only
  }
}

# This creates 3000 resources...
# Terraform plan/apply will take 30+ minutes
# State file will be massive
```

---

## Comparison: GitHub Environments vs Dedicated CD Platform

| Feature | GitHub Environments | Harness/Spinnaker |
|---------|-------------------|-------------------|
| **Setup** | Per-repo configuration | Centralized config |
| **Scale** | Manual or API per repo | Multi-tenant by design |
| **Approval Gates** | Basic + webhooks | Advanced with policies |
| **Rollback** | Manual workflow trigger | Built-in one-click |
| **Metrics Integration** | Custom webhook | Native integration |
| **Secret Management** | Per-repo secrets or OIDC | Centralized connectors |
| **Audit Trail** | GitHub audit log | Comprehensive dashboard |
| **Operational Burden** | **HIGH** at 1000+ repos | **LOW** (centralized) |

---

## Recommendation

For 1000+ repositories:

1. **Use OIDC** instead of secrets wherever possible
2. **Automate environment setup** with Terraform or custom scripts
3. **Build webhook service** for deployment gates (or use external platform)
4. **Monitor for drift** continuously
5. **Document runbooks** for common scenarios

**Brutal Truth**: Managing GitHub Environments at scale requires significant automation, custom tooling, and ongoing operational effort that dedicated CD platforms handle out-of-the-box.
