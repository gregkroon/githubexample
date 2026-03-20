# Gaps Analysis: GitHub vs Dedicated CD Platforms

## Introduction

This document identifies specific capabilities where GitHub-native tooling either:
1. **Cannot** replicate the functionality
2. **Can** replicate but requires significant custom engineering
3. **Lacks** mature solutions compared to dedicated platforms

---

## Critical Gaps

### 1. Deployment Verification & Automated Rollback

#### What Dedicated Platforms Provide

**Harness Example**:
```yaml
verificationStrategy:
  type: canary
  canarySteps:
    - name: canary-10
      traffic: 10%
      verify:
        - prometheus:
            query: error_rate
            threshold: < 0.05
        - datadog:
            metric: p99_latency
            threshold: < 500ms
        - newrelic:
            transactionErrorRate: < 1%
      duration: 10m
      autoRollback: true  # Automatic rollback if verification fails
```

**Key Features**:
- Native integration with metrics providers (Prometheus, Datadog, New Relic)
- Statistical analysis of metrics (baseline comparison, anomaly detection)
- Automatic rollback trigger
- Built-in understanding of "good" vs "bad" deployment

#### GitHub-Native Approach

**What we must build**:
```yaml
# Custom verification in workflow
- name: Continuous verification
  run: |
    # 1. Query Prometheus manually
    error_rate=$(curl "prometheus/api/v1/query?query=...")

    # 2. Parse JSON response
    # 3. Compare to threshold (hardcoded)
    # 4. If fails, trigger rollback workflow via GitHub API
    # 5. Wait for rollback to complete
    # 6. Verify rollback succeeded
```

**Problems**:
- No baseline comparison (we manually define thresholds)
- No anomaly detection
- No statistical significance testing
- Rollback requires triggering separate workflow
- No built-in understanding of metrics
- Every service needs custom verification logic

**Engineering Effort**: 4-6 weeks to build reusable verification framework

**Ongoing Maintenance**: Tuning thresholds per service (never-ending)

#### Gap Severity: 🔴 **CRITICAL**

---

### 2. Progressive Delivery Orchestration

#### What Dedicated Platforms Provide

**Spinnaker/Harness**:
- Built-in canary deployments
- Blue/Green deployments
- Traffic splitting (automatic)
- Manual judgment steps
- Automated promotion/rollback
- Visual deployment pipeline
- Works with any infrastructure (K8s, VMs, Lambda)

**Single configuration file controls entire strategy**.

#### GitHub-Native Approach

**Requires combining 4 separate tools**:

1. **Argo Rollouts** for K8s progressive delivery
2. **Istio/Nginx** for traffic splitting
3. **Prometheus** for metrics
4. **GitHub Actions** for orchestration

**Configuration spread across**:
- Rollout manifest (Argo Rollouts)
- VirtualService (Istio)
- AnalysisTemplate (Argo Rollouts)
- GitHub Actions workflow

**Example complexity**:
```yaml
# 1. Argo Rollout manifest (100+ lines)
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps: [...]
      trafficRouting:
        istio: [...]

# 2. Istio VirtualService (50+ lines)
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec: [...]

# 3. AnalysisTemplate (50+ lines per metric)
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
spec: [...]

# 4. GitHub Actions workflow (100+ lines)
# To update GitOps repo
```

**Limitations**:
- Only works for Kubernetes (VMs, serverless excluded)
- Requires service mesh (Istio) or ingress controller
- No visual pipeline view
- Debugging failures is complex (check 4 different places)
- Different strategies require different tooling

**Engineering Effort**: 8-12 weeks (includes Argo Rollouts + Istio setup)

**Ongoing Complexity**: Every developer must understand 4 systems

#### Gap Severity: 🔴 **CRITICAL**

---

### 3. Centralized Deployment Configuration

#### What Dedicated Platforms Provide

**Harness**:
```yaml
# Single centralized config for ALL services
organization:
  pipelines:
    templates:
      - name: standard-k8s-deployment
        stages:
          - dev (auto)
          - staging (approval: tech-leads)
          - prod (approval: platform-team, verification: enabled)

  services:
    - user-service: uses standard-k8s-deployment
    - payment-service: uses standard-k8s-deployment
    # ... 998 more services
```

**Key capability**: Change approval policy ONCE, applies to all 1000 services.

#### GitHub-Native Approach

**Configuration per repository**:
- Each repo has `.github/workflows/ci-cd.yml`
- Each repo has GitHub Environments configured (via API/UI)
- Each repo references reusable workflow

**To change approval policy across all services**:
1. Update reusable workflow
2. Update GitHub Environment settings (1000 repos × 3 envs = 3000 API calls)
3. Verify changes propagated correctly
4. Handle repos that fail to update

**Or**: Use Terraform to manage environments
```hcl
# terraform/github-environments.tf
# 3000 resource blocks (one per repo per environment)
# terraform apply takes 30+ minutes
```

**Problems**:
- No single source of truth
- Configuration drift inevitable
- Updates require touching 1000 repos
- Rollback is complex

#### Gap Severity: 🔴 **CRITICAL** at scale

---

### 4. Deployment Observability & Audit Trail

#### What Dedicated Platforms Provide

**Comprehensive deployment dashboard**:
- All deployments across all services (single view)
- Visual pipeline execution
- Deployment duration trends
- Failure analysis
- Deployment frequency per service
- Who deployed what, when
- Compliance reports (SOC2, HIPAA ready)

**Example**: Harness Deployment Dashboard
```
Service          Env     Status    Duration    Deployed By    Time
user-service     prod    ✅ Success  8m 23s     alice         2m ago
payment-service  staging ⏸️ Paused   -          bob           5m ago (waiting approval)
notification-svc prod    ❌ Failed   3m 12s     charlie       10m ago (rolled back)
```

#### GitHub-Native Approach

**Deployment data scattered across**:
1. GitHub Actions workflow runs (per repo)
2. GitHub Environments deployment history (per repo)
3. ArgoCD UI (if using GitOps)
4. Kubernetes events
5. Custom DORA metrics database (if built)

**To answer "What deployed to prod in the last hour?"**:
1. Query GitHub API for all repos
2. Filter workflow runs by environment
3. Parse workflow logs
4. Aggregate results
5. Build custom dashboard

**Engineering Effort**: 4-6 weeks for comprehensive dashboard

**Limitation**: GitHub audit log is general-purpose, not deployment-specific

#### Gap Severity: 🟡 **MAJOR**

---

### 5. Multi-Cloud & Multi-Cluster Deployments

#### What Dedicated Platforms Provide

**Cloud-agnostic deployment**:
```yaml
infrastructure:
  clusters:
    - aws-us-east-1: k8s
    - aws-us-west-2: k8s
    - gcp-us-central1: k8s
    - azure-eastus: k8s

deployment:
  strategy: rolling
  targets: all-clusters  # Deploy to all 4 clusters simultaneously
  verification: per-cluster
```

**Built-in connectors**:
- AWS (OIDC, IAM roles, EKS)
- GCP (Workload Identity, GKE)
- Azure (Managed Identity, AKS)
- On-prem Kubernetes
- VMs (via SSH, WinRM)
- Serverless (Lambda, Cloud Functions)

#### GitHub-Native Approach

**Requires separate configuration per cluster/cloud**:

```yaml
# In GitHub Actions workflow
- name: Deploy to AWS clusters
  run: |
    for cluster in aws-east aws-west; do
      aws eks update-kubeconfig --name $cluster
      kubectl apply -f k8s/
    done

- name: Deploy to GCP clusters
  run: |
    gcloud container clusters get-credentials gcp-central
    kubectl apply -f k8s/

- name: Deploy to Azure clusters
  run: |
    az aks get-credentials --name azure-east
    kubectl apply -f k8s/
```

**Problems**:
- No abstraction layer
- Different authentication per cloud
- Manual orchestration across clusters
- No unified verification
- Error in one cluster doesn't prevent others (partial deployment)

**Engineering Effort**: 2-3 weeks per cloud provider

#### Gap Severity: 🟡 **MAJOR** for multi-cloud orgs

---

### 6. Feature Flags & Release Decoupling

#### What Dedicated Platforms Provide

**Integrated feature flag support**:
```yaml
deployment:
  strategy: canary
  featureFlags:
    - new-checkout-flow:
        enabled: true
        rollout: 10%  # Only 10% see new feature
        verify: true  # Monitor metrics for users with flag enabled
```

**Benefits**:
- Deploy code to prod WITHOUT releasing feature
- Gradual rollout independent of deployment
- Instant disable if issues found (no redeploy)

#### GitHub-Native Approach

**Requires external feature flag service**:
- LaunchDarkly
- Split.io
- Unleash (self-hosted)
- Flagsmith (self-hosted)

**Integration**:
- Application code calls feature flag SDK
- Feature flags configured in separate system
- No integration with deployment pipeline
- Cannot tie feature rollout to deployment verification

**Gap**: Feature flag rollout is separate from deployment rollout (manual coordination)

#### Gap Severity: 🟡 **MODERATE** (workaround exists)

---

### 7. Secrets Management at Scale

#### What Dedicated Platforms Provide

**Centralized secret management**:
```yaml
# Harness connector to HashiCorp Vault
secrets:
  vault:
    url: https://vault.example.com
    namespace: production
    paths:
      - database/*
      - api-keys/*

# All 1000 services can reference secrets
# No per-service configuration needed
```

**Features**:
- Native integrations: Vault, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager
- Automatic secret rotation
- Access control via platform RBAC
- Audit logging
- Secret versioning

#### GitHub-Native Approach

**Option 1: GitHub Secrets** (doesn't scale)
- 1000 repos × 3 envs × 5 secrets = **15,000 secret configurations**
- Rotation requires 15,000 updates
- No centralized rotation
- Configured via UI or API (manual)

**Option 2: OIDC + Cloud Provider Secrets**
```yaml
# Better, but requires configuration per service
- name: Get secrets from AWS
  run: |
    export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id prod/db-password --query SecretString)
```

**Option 3: Vault Integration** (requires custom action)
```yaml
- uses: hashicorp/vault-action@v2
  with:
    url: https://vault.example.com
    role: github-actions
    secrets: |
      secret/data/db password | DB_PASSWORD
```

**Problems**:
- Custom action required
- Configuration per repo
- No centralized management of which services can access which secrets
- Vault authentication setup per service

#### Gap Severity: 🟡 **MAJOR**

---

### 8. Approval Workflows & Compliance

#### What Dedicated Platforms Provide

**Advanced approval logic**:
```yaml
approvals:
  production:
    - type: manual
      approvers:
        - platform-team (2 required)

    - type: automated
      conditions:
        - jira-ticket-exists: true
        - jira-ticket-approved: true
        - staging-deployed-successfully: true
        - no-active-incidents: true
        - business-hours: true (9am-5pm Mon-Fri)
        - security-scan-passed: true
        - compliance-check: SOC2

    - type: time-window
      window: "Tue-Thu 10am-2pm EST"  # Only allow prod deploys in this window
```

**Audit trail**:
- Who approved
- When approved
- What conditions were evaluated
- Exportable for compliance audits

#### GitHub-Native Approach

**GitHub Environments provide**:
- Required reviewers ✅
- Wait timer ✅
- Branch restrictions ✅
- Custom webhooks ✅ (but we must build the webhook service)

**Custom webhook must implement**:
```python
@app.route('/approve-deployment', methods=['POST'])
def approve_deployment():
    # WE MUST BUILD ALL THIS LOGIC:

    # 1. Check Jira for ticket
    ticket = jira_api.get_ticket(...)
    if not ticket or ticket.status != 'approved':
        return {'approved': False, 'reason': 'No approved Jira ticket'}

    # 2. Check staging deployed successfully
    staging_deployment = github_api.get_deployment(...)
    if staging_deployment.status != 'success':
        return {'approved': False}

    # 3. Check for incidents
    incidents = pagerduty_api.get_incidents(...)
    if any(i.severity in ['P0', 'P1'] for i in incidents):
        return {'approved': False, 'reason': 'Active P0/P1 incident'}

    # 4. Check business hours
    if not is_business_hours():
        return {'approved': False}

    # 5. Check security scan
    scan = get_security_scan_result(...)
    if scan.critical_vulns > 0:
        return {'approved': False}

    return {'approved': True}
```

**Problems**:
- We must build and maintain this service
- It's a critical path (if down, deployments blocked)
- Requires integrations with multiple systems
- Audit trail is custom (must build reporting)

#### Gap Severity: 🟡 **MAJOR**

---

### 9. Multi-Service Orchestration

#### What Dedicated Platforms Provide

**Pipeline dependencies**:
```yaml
pipelines:
  - name: backend-services
    parallelStages:
      - user-service
      - auth-service
      - payment-service

  - name: frontend
    dependsOn: backend-services
    stages:
      - web-app
      - mobile-api

# Automatically orchestrates deployment order
# Rolls back all if any fails
```

#### GitHub-Native Approach

**No native cross-repo orchestration**.

**Workaround 1**: Repository dispatch
```yaml
# In service-a workflow
- name: Trigger service-b deployment
  run: |
    curl -X POST \
      https://api.github.com/repos/org/service-b/dispatches \
      -H "Authorization: token ${{ secrets.PAT }}" \
      -d '{"event_type": "deploy-prod"}'
```

**Problems**:
- Complex to orchestrate
- No visual pipeline
- No automatic rollback
- Error handling is manual

**Workaround 2**: Monorepo
- All services in one repo
- One workflow orchestrates all
- Defeats purpose of microservices

#### Gap Severity: 🟡 **MAJOR** for microservices

---

### 10. Cost Visibility & Optimization

#### What Dedicated Platforms Provide

**Deployment cost tracking**:
```
Service          Deployments/mo   Compute Cost   Total Cost
user-service     150             $450           $450
payment-service  200             $600           $600
legacy-monolith  10              $2,400         $2,400  ← Optimize this!

Total: $3,450/month
```

**Features**:
- Cost per deployment
- Identify expensive pipelines
- Optimization recommendations

#### GitHub-Native Approach

**GitHub provides**:
- Actions minutes used (org-wide)
- No per-service breakdown
- No cost allocation

**To get service-level costs**:
- Parse workflow run durations from GitHub API
- Calculate costs manually
- Build custom dashboard

#### Gap Severity: 🟢 **MINOR** (nice to have)

---

## Summary Table

| Capability | GitHub-Native | Dedicated Platform | Gap Severity | Custom Engineering Required |
|------------|---------------|--------------------|--------------|-----------------------------|
| **Deployment Verification** | Manual scripting | Built-in | 🔴 Critical | 6-8 weeks |
| **Progressive Delivery** | 4 tools (Argo+Istio+Prom+GHA) | Native | 🔴 Critical | 8-12 weeks |
| **Centralized Config** | Per-repo | Centralized | 🔴 Critical | 4-6 weeks |
| **Deployment Observability** | Scattered | Unified dashboard | 🟡 Major | 4-6 weeks |
| **Multi-Cloud** | Manual per cloud | Cloud connectors | 🟡 Major | 2-3 weeks/cloud |
| **Feature Flags** | External service | Integrated | 🟡 Moderate | N/A (use external) |
| **Secrets Management** | Per-repo or custom | Centralized | 🟡 Major | 3-4 weeks |
| **Approval Workflows** | Basic + webhook | Advanced | 🟡 Major | 4-6 weeks |
| **Multi-Service Orchestration** | Workarounds | Native | 🟡 Major | 6-8 weeks |
| **Cost Visibility** | Org-level only | Per-service | 🟢 Minor | 2-3 weeks |

**Total Custom Engineering**: **45-65 weeks** (11-16 months)

---

## Features That Simply Don't Exist

### 1. One-Click Rollback

**Harness/Spinnaker**: Click "Rollback" button → previous version deployed in 2 minutes

**GitHub Actions**:
- Option A: Re-run old workflow (must find it, might fail if environment changed)
- Option B: Revert git commit + trigger new deployment (slow)
- Option C: Manual kubectl/helm rollback (bypasses all gates)

**Gap**: No simple rollback mechanism

---

### 2. Deployment Comparison

**Dedicated platforms**: Visual diff between deployed version and proposed version

**GitHub**: No built-in comparison. Must manually compare:
- Git commits
- Docker images
- Kubernetes manifests

---

### 3. Deployment Templates

**Harness**: 50+ pre-built templates (Kubernetes, ECS, Lambda, VMs, etc.)

**GitHub**: Must build every deployment pattern from scratch

---

### 4. Pipeline as Code Validation

**Dedicated platforms**: Validate pipeline BEFORE execution

**GitHub Actions**: Syntax errors only discovered at runtime

---

### 5. Dependency Management

**Spinnaker**: Visual dependency graph, automatic ordering

**GitHub**: No dependency management

---

## Workarounds & Their Costs

| Missing Feature | Workaround | Cost |
|-----------------|-----------|------|
| Deployment verification | Custom Prometheus queries + manual rollback | 6 weeks dev + ongoing tuning |
| Progressive delivery | Argo Rollouts + Istio + custom integration | 12 weeks dev + operational complexity |
| Centralized config | Terraform + GitHub API automation | 6 weeks dev + state management |
| Multi-service orchestration | Repository dispatch + custom orchestrator | 8 weeks dev |
| Deployment dashboard | Custom metrics collector + Grafana | 6 weeks dev |
| Secrets at scale | Vault + custom action | 4 weeks dev + Vault ops |
| Rollback | Manual process + runbooks | Slow, error-prone |

**Total**: 42 weeks (10.5 months) of custom development

---

## Conclusion

GitHub-native CI/CD can achieve **~70% feature parity** with dedicated CD platforms through custom engineering.

The remaining **30%** includes:
- Automated deployment verification
- Sophisticated progressive delivery
- Centralized deployment configuration
- Advanced approval workflows
- Multi-service orchestration
- One-click rollback

**These gaps can be bridged with 10-16 months of custom engineering.**

**But then you're maintaining a custom CD platform built on GitHub Actions.**

**At which point: Why not use a platform that already solved these problems?**

---

## Recommendation

✅ **Use GitHub for CI**: It's excellent for build, test, security scanning

❌ **Don't build custom CD platform**: Use Harness, Spinnaker, or similar

**Hybrid approach**:
- CI in GitHub Actions (tight integration with code)
- CD in dedicated platform (sophisticated deployment capabilities)

**This provides**:
- Best developer experience
- Least operational burden
- Fastest time to production capabilities
- Lower TCO at enterprise scale
