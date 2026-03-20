# Harness.io Comparison: How It Would Be Different

**A detailed comparison of implementing the same enterprise CI/CD system with Harness**

This document shows what changes if you use **Harness for CD** (while keeping GitHub Actions for CI).

---

## TL;DR - The Difference

| Aspect | GitHub-Native (This Repo) | Hybrid (GitHub CI + Harness CD) |
|--------|---------------------------|----------------------------------|
| **Tools Required** | 24 tools | 8 tools (67% reduction) |
| **Custom Services** | 6 services to build | 0 services (Harness provides) |
| **Setup Time** | 4-6 months | 2-4 weeks |
| **Ongoing FTE** | 2-4 platform engineers | 0.5-1 platform engineer |
| **Configuration** | Per-repo (3000 configs) | Centralized |
| **Progressive Delivery** | Argo Rollouts + Istio + Custom | Built-in (one config) |
| **Deployment Verification** | Custom Prometheus queries | Built-in ML-based |
| **Rollback** | Manual workflow trigger | One-click button |
| **5-Year TCO** | $5.2M | $3.9M (25% savings) |

---

## "But Don't GitHub Reusable Workflows Solve This?"

**Short answer**: They centralize workflow LOGIC (~30% of the problem), but not configuration, secrets, or governance (~70% of the problem).

### What Reusable Workflows Actually Centralize

GitHub reusable workflows let you define deployment steps once:

```yaml
# platform/.github/workflows/cd-deploy.yml (CENTRALIZED LOGIC)
name: Deploy
on:
  workflow_call:
    inputs:
      environment: { required: true, type: string }
      image: { required: true, type: string }

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}  # Still references per-repo config
    steps:
      - name: Scan for CVEs
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ inputs.image }}
      - name: Deploy
        run: kubectl apply -f deployment.yaml
```

✅ **Centralized**: The scanning and deployment steps
❌ **NOT centralized**: Environment configuration, approvals, secrets

### The @main vs Version Pinning Trade-off

**Option 1: Auto-update with `@main`**

```yaml
# user-service/.github/workflows/deploy.yml
jobs:
  deploy:
    uses: platform/.github/workflows/cd-deploy.yml@main  # Auto-updates
```

✅ **Pros**: Services automatically get new features (like CVE scanning)
❌ **Cons**:
- One bug breaks all 1000 repos instantly
- No gradual rollout or testing possible
- Too risky at enterprise scale

**Option 2: Version pinning (safer)**

```yaml
# user-service/.github/workflows/deploy.yml
jobs:
  deploy:
    uses: platform/.github/workflows/cd-deploy.yml@v1.2.0  # Pinned
```

✅ **Pros**: Safe, can test before rolling out
❌ **Cons**:
- **Must update 1000 workflow files** to roll out new features
- Some repos lag behind on old versions forever
- Configuration drift inevitable

**Most enterprises choose version pinning** (safer), which means back to updating 1000 repos.

### What STILL Requires Per-Repo Configuration

Even with reusable workflows, you must still manage:

**1. GitHub Environments (3000 configurations)**
```bash
# For each repo × each environment, you must configure:
gh api repos/myorg/user-service/environments/production -X PUT \
  -f reviewers='[{"type":"Team","id":12345}]' \
  -f deployment_branch_policy=null

# Scenario: Change from "2 approvers" to "3 approvers"
# Result: Update 1000 GitHub Environments (4-8 hours of scripting)
```

**2. Secrets Management (1000+ configurations)**
```bash
# Scenario: Rotate Kubernetes credentials
# GitHub: Update secret in 1000 repos
for repo in $(gh repo list --limit 1000); do
  gh secret set KUBE_CONFIG --repo $repo --body "$NEW_CRED"
done

# Harness: Update one connector (2 minutes)
# Done. All 1000 services use the new credential.
```

**3. No Enforcement Mechanism**
```yaml
# A team can bypass your reusable workflow entirely:
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: kubectl apply -f deployment.yaml  # No scanning, no approvals
```

❌ No way to enforce all repos use your reusable workflow
❌ No central visibility into which repos are compliant

**4. Configuration Drift After 6 Months**
```bash
$ gh api graphql ... | jq '.repositories[] | {name, workflow_version}'

{"name": "user-service", "workflow_version": "v1.3.0"}     # Latest
{"name": "payment-service", "workflow_version": "v1.2.0"}  # Missing CVE scan
{"name": "legacy-service", "workflow_version": "v0.9.0"}   # Ancient

# Result: Some repos have security scanning, some don't
```

### Harness Templates: TRUE Centralization

With Harness, you centralize **everything**:

```yaml
# Platform team: Define ONCE
template:
  name: Standard Deployment
  spec:
    execution:
      steps:
        - step:
            type: Approval
            spec:
              approvers: { userGroups: [prod-approvers] }
              minimumCount: 3  # ← Change here, affects all 1000 services instantly
        - step:
            type: Verify
            spec: { type: Cosign }  # ← Add CVE scanning, all services get it
        - step:
            type: K8sRollingDeploy
```

**Services just reference the template:**
```yaml
service:
  name: user-service
  # That's it. No workflow file, no environment config, no secrets
```

**Change approval from "2 reviewers" to "3 reviewers":**
- GitHub: Script to update 1000 repos (4-8 hours)
- Harness: Edit template (2 minutes, all services updated)

**Rotate Kubernetes credentials:**
- GitHub: Update secret in 1000 repos (scripting + debugging)
- Harness: Update connector (2 minutes, all services updated)

**Add CVE scanning step:**
- GitHub (with @main): All services get it, but one bug breaks everything
- GitHub (with pinning): Must update 1000 workflow files
- Harness: Add to template, all services get it safely

### Summary

**Reusable workflows centralize ~30% of the problem** (workflow logic)

**They DON'T centralize ~70% of the problem:**
- ❌ GitHub Environment configurations (3000 of them)
- ❌ Secrets management (1000+ repos)
- ❌ Approval rules (per-environment)
- ❌ Infrastructure configuration
- ❌ Enforcement (teams can bypass workflows)
- ❌ Visibility (which repos use which versions)
- ❌ Rollback capability
- ❌ Deployment verification

**That's why the 5-year cost is still $5.2M vs $3.9M** even with reusable workflows.

---

## Architecture: Side-by-Side

### Current (GitHub-Native)

```
┌─────────────────────────────────────────────────────────────┐
│  Developer pushes code to GitHub                            │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions CI (KEEP THIS)                              │
│  ├── CodeQL, Semgrep (SAST)                                 │
│  ├── Trivy, Grype (Container scan)                          │
│  ├── Syft (SBOM), Cosign (Signing)                         │
│  └── Conftest (Policy validation)                          │
└────────────────┬────────────────────────────────────────────┘
                 │ Publishes image to GHCR
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  GitHub Environments (3000 configs)                          │
│  ├── Custom webhook (we built)                              │
│  ├── Approval workflows (manual setup)                      │
│  └── OIDC to cloud (per-repo config)                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  GitOps Repository                                           │
│  └── GitHub Actions updates image tag                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  ArgoCD (we maintain)                                        │
│  └── Syncs to Kubernetes                                    │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  Argo Rollouts + Istio + Prometheus (we maintain)           │
│  └── Progressive delivery with custom analysis              │
└─────────────────────────────────────────────────────────────┘
```

**Total components WE maintain**: 10+

---

### With Harness

```
┌─────────────────────────────────────────────────────────────┐
│  Developer pushes code to GitHub                            │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions CI (SAME - KEEP THIS)                       │
│  ├── CodeQL, Semgrep (SAST)                                 │
│  ├── Trivy, Grype (Container scan)                          │
│  ├── Syft (SBOM), Cosign (Signing)                         │
│  └── Conftest (Policy validation)                          │
└────────────────┬────────────────────────────────────────────┘
                 │ Publishes image to GHCR
                 │ Triggers Harness webhook
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  HARNESS (Single Platform)                                   │
│  ├── Pipeline orchestration (replaces GitHub Environments)  │
│  ├── Approval workflows (built-in)                          │
│  ├── Cloud connectors (replaces OIDC setup)                │
│  ├── Progressive delivery (replaces Argo Rollouts)         │
│  ├── Deployment verification (replaces custom scripts)     │
│  ├── Rollback (one-click)                                   │
│  ├── DORA metrics (built-in dashboard)                     │
│  └── Policy engine (OPA built-in)                          │
└────────────────┬────────────────────────────────────────────┘
                 │ Directly deploys to Kubernetes
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                          │
│  └── No ArgoCD, Argo Rollouts, or Istio needed             │
└─────────────────────────────────────────────────────────────┘
```

**Total components WE maintain**: 2 (GitHub Actions + Harness config)

---

## What You Don't Need to Build

### ❌ Custom Services (All Replaced by Harness)

| Service We Built | Harness Equivalent | Effort Saved |
|------------------|-------------------|--------------|
| **Deployment Gate Webhook** | Harness Approval Policies | 4 weeks + ongoing |
| **DORA Metrics Collector** | Harness Insights Dashboard | 3 weeks + maintenance |
| **Policy Enforcement Service** | Harness OPA Engine | 3 weeks |
| **Environment Setup Automation** | Harness Centralized Config | 2 weeks |
| **Workflow Update Bot** | Template inheritance | 2 weeks |
| **Deployment Verification** | Harness CV (Continuous Verification) | 3 weeks |

**Total savings**: 17 weeks (4+ months) of development

---

### ❌ Infrastructure Components (Harness Provides)

| Component | GitHub-Native | Harness |
|-----------|---------------|---------|
| **ArgoCD** | We install, maintain, upgrade | Not needed |
| **Argo Rollouts** | We install, maintain | Not needed |
| **Istio/Service Mesh** | We install, maintain (complex!) | Not needed |
| **GitOps Repository** | We manage | Optional |
| **Prometheus** | We maintain (for verification) | Harness integrates |
| **Grafana** | We maintain dashboards | Harness dashboards |

**Total eliminated**: 6 complex systems we don't maintain

---

## Configuration: Side-by-Side

### Scenario: Deploying user-service to Production

#### GitHub-Native Approach

**Step 1: Configure GitHub Environment** (per repository):

```yaml
# Must be done via UI or API for EACH repository
Repository: user-service
Environment: production
  Protection Rules:
    - Required reviewers: platform-engineering (2)
    - Wait timer: 1800 seconds
    - Branch restrictions: main only

  Custom Protection Rules:
    - Webhook: https://our-webhook.com/validate
      (We built and maintain this service!)

  Secrets (per environment):
    - CLUSTER_NAME: prod-cluster
    - DEPLOYMENT_ROLE: arn:aws:...

  Variables:
    - ENVIRONMENT: production
    - NAMESPACE: production
```

**Multiply by**: 1000 repos × 3 environments = **3000 configurations**

---

**Step 2: Create Workflow** (in each repository):

```yaml
# .github/workflows/deploy.yml (in user-service repo)
name: Deploy to Production
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

jobs:
  deploy:
    uses: org/platform/.github/workflows/cd-deploy.yml@v2.3.0
    with:
      service-name: user-service
      environment: production
      image-digest: ${{ needs.ci.outputs.digest }}
    secrets: inherit
```

**Problems**:
- Workflow must be in EVERY repository
- Updates require updating 1000 repos
- Version pinning creates lag

---

**Step 3: Create Reusable Workflow** (in platform repo):

```yaml
# platform/.github/workflows/cd-deploy.yml (300+ lines)
name: CD Deployment
on:
  workflow_call:
    inputs: [...]

jobs:
  pre-deployment:
    # Verify image signature (30 lines)
    # Check deployment gates (40 lines)
    # Custom webhook validation (20 lines)

  deploy:
    # Authenticate to cloud (20 lines)
    # Update manifests (30 lines)
    # Deploy to K8s (40 lines)
    # Progressive delivery logic (60 lines)

  verify:
    # Health checks (20 lines)
    # Metrics verification (40 lines)
    # Custom Prometheus queries (30 lines)

  rollback:
    # Rollback logic (40 lines)
```

**Ongoing maintenance**: Every time we add a feature

---

#### Harness Approach

**Step 1: Create Pipeline Template** (ONCE, for all 1000 services):

```yaml
# Harness UI or YAML - ONE configuration
pipeline:
  name: Standard Kubernetes Deployment
  identifier: standard_k8s_deploy

  stages:
    - stage:
        name: Deploy to Production
        identifier: prod_deploy

        spec:
          infrastructure:
            environmentRef: <+pipeline.variables.environment>
            infrastructureDefinition:
              type: KubernetesDirect
              spec:
                connectorRef: k8s_prod_cluster
                namespace: <+service.name>

          execution:
            steps:
              # Image verification (built-in)
              - step:
                  type: Verify
                  spec:
                    type: Cosign

              # Approval (built-in)
              - step:
                  type: HarnessApproval
                  spec:
                    approvers:
                      userGroups:
                        - platform_engineers
                    minimumCount: 2
                    approvalMessage: "Approve production deployment of ${service.name}"

              # Deploy (built-in)
              - step:
                  type: K8sRollingDeploy
                  spec:
                    skipDryRun: false

              # Continuous Verification (built-in ML)
              - step:
                  type: Verify
                  spec:
                    type: Auto  # ML-based anomaly detection
                    spec:
                      sensitivity: MEDIUM
                      duration: 10m
                      deploymentTag: <+service.name>

                      # Harness connects to Prometheus automatically
                      connectorRef: prometheus_prod

                      # Or use Datadog, New Relic, etc.
                      # connectorRef: datadog_prod

          # Rollback (automatic)
          rollbackSteps:
            - step:
                type: K8sRollingRollback
```

**That's it.**

Now apply to 1000 services:

```yaml
# For each service, just reference the template
service:
  name: user-service
  identifier: user_service

  # Reference the template (inherits everything)
  serviceDefinition:
    type: Kubernetes
    spec:
      manifests:
        - manifest:
            identifier: k8s_manifests
            type: K8sManifest
            spec:
              store:
                type: Github
                spec:
                  connectorRef: github_connector
                  gitFetchType: Branch
                  paths:
                    - k8s/

      artifacts:
        primary:
          primaryArtifactRef: <+input>
          sources:
            - identifier: ghcr_image
              type: DockerRegistry
              spec:
                connectorRef: ghcr_connector
                imagePath: yourorg/user-service
                tag: <+trigger.artifact.build>
```

**No per-repo configuration needed!**

---

## Feature Comparison

### 1. Progressive Delivery (Canary/Blue-Green)

#### GitHub-Native

**What you need**:
1. **Argo Rollouts** controller installed
2. **Istio** service mesh (or Nginx Ingress with modifications)
3. **Prometheus** for metrics
4. **Custom AnalysisTemplate** per service

**Configuration** (100+ lines per service):

```yaml
# gitops/apps/prod/user-service/rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: user-service
spec:
  strategy:
    canary:
      canaryService: user-service-canary
      stableService: user-service-stable
      trafficRouting:
        istio:
          virtualService:
            name: user-service-vsvc
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - analysis:
            templates:
              - templateName: error-rate-check
        - setWeight: 25
        # ... many more steps

---
# Separate AnalysisTemplate
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate-check
spec:
  metrics:
    - name: error-rate
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{status=~"5..",service="user-service"}[5m])) /
            sum(rate(http_requests_total{service="user-service"}[5m]))
      successCondition: result < 0.05

---
# Istio VirtualService
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
# ... another 40 lines
```

**Operational burden**:
- Install and maintain Istio (notoriously complex)
- Write Prometheus queries manually
- Define thresholds per service
- Debug across 3 systems when issues occur

---

#### Harness

**Configuration** (10 lines):

```yaml
execution:
  steps:
    - step:
        type: K8sBlueGreenDeploy  # or K8sCanaryDeploy
        spec:
          skipDryRun: false

    - step:
        type: Verify
        spec:
          type: Auto  # Harness ML automatically learns your baselines
          sensitivity: MEDIUM
          duration: 10m
```

**That's it.**

Harness:
- ✅ Manages traffic splitting (no Istio needed)
- ✅ Uses ML to learn baselines (no manual thresholds)
- ✅ Supports multiple metrics sources (Prometheus, Datadog, New Relic, etc.)
- ✅ Automatically rolls back on anomaly detection
- ✅ Works with any deployment strategy (canary, blue-green, rolling)

---

### 2. Deployment Verification

#### GitHub-Native

**We must build**:

```yaml
# In workflow
- name: Verify deployment
  run: |
    # 1. Query Prometheus manually
    ERROR_RATE=$(curl -s "http://prometheus:9090/api/v1/query" \
      --data-urlencode "query=rate(http_requests_total{status=~\"5..\"}[5m])" \
      | jq -r '.data.result[0].value[1]')

    # 2. Compare to hardcoded threshold
    if (( $(echo "$ERROR_RATE > 0.05" | bc -l) )); then
      echo "Error rate too high: $ERROR_RATE"
      exit 1
    fi

    # 3. Check latency
    LATENCY=$(curl -s "http://prometheus:9090/api/v1/query" \
      --data-urlencode "query=histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))" \
      | jq -r '.data.result[0].value[1]')

    # 4. More manual comparisons...
```

**Problems**:
- Hardcoded thresholds (what if traffic patterns change?)
- Manual query writing (error-prone)
- No statistical significance testing
- No anomaly detection
- Must define for every service

---

#### Harness

```yaml
- step:
    type: Verify
    spec:
      type: Auto
      sensitivity: MEDIUM
```

**Harness automatically**:
- ✅ Learns baseline from previous deployments
- ✅ Detects anomalies using ML
- ✅ Considers statistical significance
- ✅ Adapts to traffic patterns
- ✅ Works across all services without configuration

---

### 3. Approval Workflows

#### GitHub-Native

**Per repository configuration**:

```yaml
# Settings → Environments → production
Required reviewers: platform-engineering (2)
Wait timer: 30 minutes

# Custom webhook (we built and maintain):
POST https://our-webhook.com/validate
{
  "service": "user-service",
  "environment": "production",
  "checks": [
    "staging_healthy",
    "business_hours",
    "no_incidents"
  ]
}
```

**Our webhook service must**:
- Check Prometheus for staging metrics
- Check PagerDuty for incidents
- Check business hours
- Validate JIRA ticket
- Return approval decision
- Be highly available (critical path!)

**Operational burden**: We maintain this service 24/7

---

#### Harness

```yaml
- step:
    type: HarnessApproval
    spec:
      approvers:
        userGroups: [platform_engineers]
      minimumCount: 2

      # Built-in conditional approvals
      includePipelineExecutionHistory: true

      # Auto-reject conditions
      autoReject:
        action: StageRollback
        conditions:
          - key: PagerDuty
            operator: equals
            value: "active_incident"
```

**Harness provides**:
- ✅ RBAC built-in
- ✅ PagerDuty integration (no custom code)
- ✅ JIRA integration (built-in)
- ✅ Conditional approvals
- ✅ Auto-reject rules
- ✅ Approval history and audit trail

---

### 4. Rollback

#### GitHub-Native

**Option 1**: Re-run old workflow

```bash
# Find old workflow run
gh run list --workflow=deploy.yml --limit 10

# Re-run it
gh run rerun <run_id>

# Wait 15+ minutes for full deployment
```

**Option 2**: GitOps revert

```bash
# Revert commit in GitOps repo
cd gitops
git revert HEAD
git push

# Wait for ArgoCD to sync (3-5 minutes)
```

**Option 3**: Manual kubectl

```bash
# Find previous ReplicaSet
kubectl get rs -n production

# Scale down new, scale up old
kubectl scale rs/<new-rs> --replicas=0 -n production
kubectl scale rs/<old-rs> --replicas=10 -n production
```

**Time**: 5-20 minutes
**Risk**: Manual, error-prone

---

#### Harness

**In the UI**: Click "Rollback" button.

**Via API**:
```bash
harness rollback --execution-id <id>
```

**Time**: 2-3 minutes
**Risk**: Automated, tested rollback

**Harness tracks**:
- ✅ What was deployed
- ✅ Previous stable version
- ✅ Automatic rollback on verification failure
- ✅ One-click manual rollback

---

### 5. Multi-Environment Management

#### GitHub-Native

**For 1000 services × 3 environments**:

```bash
# Create 3000 GitHub Environments (via API or Terraform)
for repo in $(cat repos.txt); do
  for env in dev staging production; do
    gh api repos/$ORG/$repo/environments/$env \
      -X PUT \
      --field "reviewers[0][id]=12345" \
      --field "reviewers[0][type]=Team"
  done
done

# Time: Hours to days
# Ongoing: Drift detection, updates, secret rotation
```

**Challenges**:
- Configuration spread across 1000 repos
- Secrets per repo/environment
- Updates require touching all repos
- Drift management

---

#### Harness

**Centralized environments**:

```yaml
# Define once, use everywhere
environments:
  - environment:
      name: Production
      identifier: production
      type: Production

      # All 1000 services use this
      infrastructureDefinitions:
        - infrastructureDefinition:
            name: Prod K8s Cluster
            identifier: prod_k8s
            type: KubernetesDirect
            spec:
              connectorRef: prod_cluster_connector

      # Centralized overrides
      overrides:
        manifests:
          - manifest:
              identifier: resource_limits
              type: Values
              spec:
                store:
                  type: Inline
                  spec:
                    content: |
                      resources:
                        limits:
                          memory: 1Gi
                          cpu: 500m
```

**Benefits**:
- ✅ Configure once, applies to all services
- ✅ Update once, all services updated
- ✅ No per-repo configuration
- ✅ Centralized secret management

---

### 6. DORA Metrics

#### GitHub-Native

**We must build** (see `governance/metrics-collector/dora-metrics-design.md`):

```python
# Custom service we maintain
@app.route('/webhooks/github', methods=['POST'])
def github_webhook():
    # Parse GitHub webhook
    # Extract deployment info
    # Calculate lead time
    # Store in database
    # Generate metrics

# Separate Grafana dashboard
# Manual threshold configuration
# Custom reporting logic
```

**Effort**: 3 weeks to build + ongoing maintenance

---

#### Harness

**Built-in dashboard**. That's it.

Harness automatically tracks:
- ✅ Deployment frequency (per service, per environment)
- ✅ Lead time (from commit to production)
- ✅ Change failure rate (links deployments to incidents)
- ✅ MTTR (automatic incident correlation)

**With visualizations, trends, and exportable reports.**

---

## Developer Experience Comparison

### Making a Code Change

Both approaches start the same:

1. ✅ Write code
2. ✅ Create PR
3. ✅ GitHub Actions CI runs (same in both)
4. ✅ Merge to main

**Then they diverge**:

---

#### GitHub-Native (Current Approach)

```
Merge PR
  ↓
GitHub Actions triggers deployment workflow
  ↓
Wait for dev environment approval (auto, but configurable)
  ↓ 5 minutes
Deploy to dev
  ↓
Wait 5 minutes for staging approval
  ↓
Manual approval from tech lead
  ↓ 10-60 minutes
Deploy to staging
  ↓
Wait 30 minutes minimum for production
  ↓
Custom webhook validates staging metrics
  ↓
Manual approval from 2 platform engineers
  ↓ 30 minutes - 4 hours
GitOps update → ArgoCD sync → Argo Rollouts canary
  ↓ 28 minutes
Production deployed

Total time: 1.5 - 6 hours
```

**Developer sees**: Multiple systems, waiting, manual coordination

---

#### Harness Approach

```
Merge PR
  ↓
GitHub Actions triggers Harness webhook
  ↓
Harness pipeline starts
  ↓ (all automatic from here)
Deploy to dev
  ↓
Verify dev (ML-based, automatic)
  ↓ 5 minutes
Deploy to staging
  ↓
Verify staging (ML-based, automatic)
  ↓ 10 minutes
Wait 30 minutes + request approvals
  ↓
2 approvals required (Slack notification)
  ↓ 30 minutes - 2 hours
Deploy to production (progressive canary)
  ↓
Verify production (ML-based, automatic)
  ↓ 15 minutes
Production deployed

Total time: 1 - 3 hours
```

**Developer sees**: Single Harness UI, clear pipeline visualization, less waiting

---

## Cost Comparison (5 Years)

### GitHub-Native

```
Year 1 (Build + Operate):
  Platform engineering: 4 FTE × $180k     = $720,000
  GitHub Enterprise + GH Security         = $243,600
  GitHub Actions compute                  = $219,000
  GHCR storage                            = $45,000
  Infrastructure (webhooks, ArgoCD, etc.) = $50,000
  ─────────────────────────────────────────────────
  Year 1 Total:                           = $1,277,600

Years 2-5 (Operate):
  Platform engineering: 2.5 FTE × $180k   = $450,000/year
  GitHub costs                            = $507,600/year
  Infrastructure                          = $50,000/year
  ─────────────────────────────────────────────────
  Annual:                                 = $1,007,600/year
  Years 2-5 Total:                        = $4,030,400

5-Year Total: $5,308,000
```

---

### Hybrid (GitHub CI + Harness CD)

```
Year 1 (Implement):
  Platform engineering: 2 FTE × $180k     = $360,000
  GitHub (CI only, fewer Actions minutes) = $365,000
  Harness Enterprise (1000 services)      = $200,000
  ─────────────────────────────────────────────────
  Year 1 Total:                           = $925,000

Years 2-5 (Operate):
  Platform engineering: 1 FTE × $180k     = $180,000/year
  GitHub                                  = $365,000/year
  Harness                                 = $200,000/year
  ─────────────────────────────────────────────────
  Annual:                                 = $745,000/year
  Years 2-5 Total:                        = $2,980,000

5-Year Total: $3,905,000
```

---

### Savings with Harness

```
GitHub-Native: $5,308,000
Hybrid:        $3,905,000
─────────────────────────
Savings:       $1,403,000 (26% reduction)

Breakdown:
  Year 1: Save $352,600 (faster implementation)
  Years 2-5: Save $262,600/year (less ongoing cost)
```

---

## What You Give Up

### ❌ Vendor Lock-In

**GitHub-Native**:
- ✅ All open source (ArgoCD, Argo Rollouts, OPA)
- ✅ Can migrate easily
- ✅ No vendor dependency (except GitHub)

**Harness**:
- ❌ Vendor-specific pipeline YAML
- ❌ Migration requires rewriting pipelines
- ❌ Dependent on Harness for CD

**Mitigation**: Keep CI in GitHub Actions, only CD in Harness

---

### ❌ Cost

**Harness licensing**: ~$200k/year for 1000 services

**But**: Saves $262k/year in operational costs, so net positive

---

### ❌ Control

**GitHub-Native**:
- ✅ Full control over all components
- ✅ Can customize everything
- ✅ Own the infrastructure

**Harness**:
- ❌ Limited customization
- ❌ Dependent on Harness features/roadmap
- ❌ SaaS service (unless self-hosted)

---

## What You Gain

### ✅ Time to Value

**GitHub-Native**: 4-6 months to build
**Harness**: 2-4 weeks to implement

**6-month head start** on production deployments

---

### ✅ Reduced Complexity

**GitHub-Native**: 24 tools, 6 custom services
**Harness**: 8 tools, 0 custom services

**67% fewer components** to maintain

---

### ✅ Better Features

- ✅ ML-based verification (vs manual thresholds)
- ✅ One-click rollback (vs manual process)
- ✅ Built-in DORA metrics (vs custom build)
- ✅ Centralized configuration (vs per-repo)
- ✅ Advanced approval workflows (vs basic + webhook)

---

### ✅ Lower Operational Burden

**GitHub-Native**: 2-4 FTE platform engineers
**Harness**: 0.5-1 FTE platform engineer

**75% reduction** in ongoing effort

---

## Real-World Scenario: Updating Deployment Logic

### Scenario: Add deployment to new region (Asia-Pacific)

#### GitHub-Native Approach

1. **Update reusable workflow** (2 hours)
   ```yaml
   # platform/.github/workflows/cd-deploy.yml
   # Add new cluster logic
   ```

2. **Update deployment gate webhook** (4 hours)
   ```python
   # Add Asia-Pacific checks
   ```

3. **Create new GitHub Environments** (8 hours)
   ```bash
   # 1000 repos × 1 new environment = 1000 configs
   ```

4. **Update Terraform/OIDC** (4 hours)
   ```hcl
   # Add APAC cluster connectors
   ```

5. **Install ArgoCD in new cluster** (8 hours)
   ```bash
   # Install, configure, test
   ```

6. **Update GitOps repo structure** (4 hours)
   ```bash
   # Add APAC overlays
   ```

7. **Test with pilot services** (8 hours)

8. **Roll out to all services** (40 hours)
   ```bash
   # Update 1000 repos to use new workflow version
   ```

**Total**: ~78 hours (2 weeks) + coordination across teams

---

#### Harness Approach

1. **Add new infrastructure** (1 hour)
   ```yaml
   # Harness UI
   Infrastructure Definition:
     Name: APAC K8s Cluster
     Connector: <select K8s connector>
     Namespace: <+service.name>
   ```

2. **Update pipeline template** (30 minutes)
   ```yaml
   # Add APAC to deployment sequence
   stages:
     - dev
     - staging
     - production-us
     - production-eu
     - production-apac  # New!
   ```

3. **Test with pilot service** (1 hour)

4. **Enable for all services** (5 minutes)
   ```yaml
   # All 1000 services automatically inherit the change
   ```

**Total**: ~3 hours

**Difference**: 75 hours saved (26× faster)

---

## Migration Path

### Phase 1: Start with Hybrid (Recommended)

```
Month 1-2: Setup
  - Keep existing GitHub Actions CI (no changes)
  - Install Harness
  - Configure cloud connectors
  - Set up base pipeline templates

Month 3-4: Pilot
  - Migrate 10 services to Harness CD
  - Test all environments
  - Validate progressive delivery
  - Train teams

Month 5-6: Rollout
  - Migrate 100 services
  - Measure improvements
  - Refine templates

Month 7-12: Complete
  - Migrate remaining 890 services
  - Decommission ArgoCD/Argo Rollouts
  - Optimize costs
  - Establish patterns
```

---

### Phase 2: Optimize (Optional)

```
Option A: Keep Hybrid
  CI: GitHub Actions ✅
  CD: Harness ✅

  Benefits:
  - Best of both worlds
  - CI stays close to code
  - CD gets platform benefits

Option B: All-in on Harness
  CI: Harness CI ✅
  CD: Harness CD ✅

  Benefits:
  - Single platform
  - Unified pipelines
  - Potentially lower cost

  Drawbacks:
  - Full vendor lock-in
  - Less GitHub integration
```

**Recommendation**: Stay hybrid (keep GitHub Actions for CI)

---

## Summary: When to Choose Each

### Choose GitHub-Native When:

✅ **Startup with <50 repositories**
- Operational burden is manageable
- Cost-conscious (year 1 only)
- Strong platform engineering team
- Want full control

✅ **GitHub-first culture**
- Everything in GitHub is a requirement
- Existing GitHub expertise
- Simple deployment patterns

✅ **No budget for platform**
- Can invest engineering time instead
- Long-term TCO isn't primary concern

---

### Choose Harness When:

✅ **Enterprise with 500+ repositories**
- Configuration sprawl becomes unmanageable
- Need centralized control
- Limited platform engineering capacity

✅ **Need advanced CD features**
- Progressive delivery (canary, blue-green)
- ML-based verification
- One-click rollback
- Multi-cloud deployments

✅ **Compliance requirements**
- Comprehensive audit trails
- Built-in RBAC and governance
- Standardized approvals

✅ **Want lower TCO**
- 26% cost savings over 5 years
- Faster time to value (2-4 weeks vs 4-6 months)
- Less ongoing maintenance

---

## Conclusion

### The Truth

**Both approaches work.**

**GitHub-native** is:
- ✅ Technically complete
- ✅ Fully open source
- ✅ No vendor lock-in
- ❌ High operational burden
- ❌ Longer to implement
- ❌ Missing advanced features

**Harness** is:
- ✅ Faster to implement
- ✅ Lower operational burden
- ✅ Advanced features built-in
- ✅ Lower 5-year TCO
- ❌ Vendor lock-in
- ❌ License cost

---

### The Recommendation

For **1000+ repositories**:

**Use GitHub Actions for CI** ✅
- Excellent for build/test/scan
- Native GitHub integration
- Already have the expertise

**Use Harness for CD** ✅
- Purpose-built for deployment
- Handles complexity better
- Lower TCO at scale

**This hybrid approach gives you**:
- ✅ Best developer experience (GitHub for daily work)
- ✅ Least operational burden (Harness handles deployment complexity)
- ✅ Flexibility (can change CD platform without touching CI)
- ✅ Cost savings ($1.4M over 5 years)

---

### The Honest Truth

**You built a CD platform when you implemented GitHub-native CI/CD.**

**Harness already built that platform.**

**The question isn't** "Can GitHub do it?"

**The question is** "Do we want to maintain a CD platform, or use one?"

**At enterprise scale, the answer is usually**: Use a platform.

---

## See It in Action

1. **Current implementation**: [TUTORIAL_WALKTHROUGH.md](TUTORIAL_WALKTHROUGH.md)
   - Experience the GitHub-native complexity

2. **Operational reality**: [OPERATIONAL_BURDEN.md](OPERATIONAL_BURDEN.md)
   - See what it takes to maintain at scale

3. **Feature gaps**: [GAPS_ANALYSIS.md](GAPS_ANALYSIS.md)
   - Understand what's missing

4. **This document**: Understand how Harness would simplify it

**Then make an informed decision.**
