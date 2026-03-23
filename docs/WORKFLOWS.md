# GitHub Workflows: Live Demonstrations of the 3 Critical Gaps

This repository includes **live, runnable workflows** that demonstrate the exact gaps documented in [DEMO.md](DEMO.md) and [README.md](../README.md).

---

## Quick Start

**Run the gap demonstrations:**

```bash
# From GitHub UI:
# Go to: Actions → Select workflow → Run workflow

# Or trigger via gh CLI:
gh workflow run "GAP 1 DEMO: Cross-Environment Visibility"
gh workflow run "GAP 2 DEMO: Lambda Deployment Terraform Orchestration"
```

Each workflow completes in **2-5 minutes** and generates a detailed **step summary** showing the exact pain points.

---

## Gap Demonstration Workflows

### 🔍 Gap 1: Cross-Environment Visibility

**File**: `.github/workflows/gap1-cross-env-visibility.yml`

**What it demonstrates:**
- Manual kubectl queries required across 4 environments (Dev, QA, Staging, Prod)
- 15-20 minutes to compile deployment state for 50 services
- Manual git commit SHA correlation
- Why platform teams build Internal Developer Portals (Backstage)

**The Question This Answers**:
> "Show me what version of all 50 microservices is deployed in Dev, QA, Staging, and Production right now."

**Run it:**
```bash
gh workflow run "GAP 1 DEMO: Cross-Environment Visibility"
```

**What you'll see:**
- Manual kubectl commands for each environment
- The correlation nightmare (200 image tags → git SHAs)
- IDP build requirements (6-8 weeks + 4-6 hrs/week maintenance)
- Harness alternative (5-second API query)

**Maps to**: [DEMO.md - Gap 1](DEMO.md#gap-1-cross-environment-visibility-not-single-service-state)

---

### 🚨 Gap 2: Lambda Deployment Terraform Orchestration

**File**: `.github/workflows/gap2-lambda-terraform-orchestration.yml`

**What it demonstrates:**
- Terraform is declarative state, not a release orchestrator
- Custom bash orchestration wrapping Terraform applies
- Manual CloudWatch polling for verification
- Hard-coded thresholds (no baseline comparison)
- 5-minute sleep wastes GitHub Actions runner time

**The Workflow Shows**:
```yaml
# Step 1: terraform apply -var="canary_weight=0.1"
# Step 2: sleep 300  # Waste runner time
# Step 3: Manual CloudWatch query (custom bash)
# Step 4: Hard-coded threshold check
# Step 5: terraform apply -var="canary_weight=1.0" OR rollback
```

**Run it:**
```bash
gh workflow run "GAP 2 DEMO: Lambda Deployment Terraform Orchestration"
```

**What you'll see:**
- The 5-step custom orchestration dance
- Structural flaws (hard-coded thresholds, fragile API dependencies)
- Why this pattern must be rebuilt for ECS, VMs, databases
- Harness native Lambda canary (15 lines YAML, ML-driven verification)

**Maps to**: [DEMO.md - Gap 2](DEMO.md#gap-2-advanced-deployments--verification-beyond-kubernetes)

---

### 🔧 Gap 3: Reusable Workflow Maintenance Burden

**File**: `.github/workflows/gap3-reusable-workflow-maintenance.yml`

**What it demonstrates:**
- Reusable Workflows centralize deployment logic (GOOD!)
- But your platform team maintains them forever (EXPENSIVE!)
- 7 maintenance events in last 6 months (AWS API changes, runtime deprecations)
- 80-120 hours/year maintenance burden
- The Vendor Lock-In Paradox

**The Workflow Shows**:
Every step has comments like:
```yaml
# ⚠️ MAINTENANCE: AWS deprecated Node 18 in Lambda
# UPDATED: 2024-11-15 (2 weeks of platform team work)
# NEXT UPDATE DUE: ~2026 when AWS deprecates Node 20
```

**Run it:**
```bash
# This is a reusable workflow - see usage in cd-payment-service.yml
# Or view directly:
cat .github/workflows/gap3-reusable-workflow-maintenance.yml
```

**What you'll see:**
- 6-month maintenance timeline (7 breaking AWS changes)
- Emergency fixes (Friday 5pm Lambda outage: 6 hours on-call)
- The buy-vs-build cost calculation ($150k/year maintenance vs vendor roadmap wait)
- Why "control" is expensive

**Maps to**: [DEMO.md - Gap 3](DEMO.md#gap-3-ongoing-maintenance-burden-of-reusable-workflows)

---

## Standard CI/CD Workflows

### CI Workflows (Build, Scan, Sign)

**Files**:
- `.github/workflows/ci-user-service.yml`
- `.github/workflows/ci-payment-service.yml`
- `.github/workflows/ci-notification-service.yml`

**What they demonstrate:**
- ✅ GitHub Actions **excels** at CI (build, test, security scan)
- SBOM generation (Syft)
- Image signing (Cosign with OIDC keyless)
- Security scanning (Trivy, Grype)
- SARIF upload (with workarounds for org permission restrictions)

**Trigger**: Automatically on push to `services/*/`

---

### CD Workflows (Deploy to Dev → Prod)

**Files**:
- `.github/workflows/cd-user-service.yml`
- `.github/workflows/cd-payment-service.yml`
- `.github/workflows/cd-notification-service.yml`

**What they demonstrate:**
- Kubernetes deployment with GitHub Environments (manual approval gate)
- SBOM attestation verification (50 lines of Cosign logic per environment)
- Smoke tests
- The complexity of secure CD (150 lines just for SBOM enforcement)

**Trigger**: Automatically after CI workflow completes

---

## How the Workflows Map to Documentation

| Workflow | Demonstrates | Documented In |
|----------|--------------|---------------|
| `gap1-cross-env-visibility.yml` | Manual kubectl queries, IDP building burden | [DEMO.md Gap 1](DEMO.md#gap-1-cross-environment-visibility-not-single-service-state) |
| `gap2-lambda-terraform-orchestration.yml` | Terraform orchestration bash, hard-coded thresholds | [DEMO.md Gap 2](DEMO.md#gap-2-advanced-deployments--verification-beyond-kubernetes) |
| `gap3-reusable-workflow-maintenance.yml` | Ongoing AWS API change maintenance | [DEMO.md Gap 3](DEMO.md#gap-3-ongoing-maintenance-burden-of-reusable-workflows) |
| `ci-*.yml` | GitHub Actions CI strengths | [README.md](../README.md) |
| `cd-*.yml` | Kubernetes CD complexity | [README.md](../README.md) |

---

## Running the Full Demo

**Step 1: Fork the repository**
```bash
gh repo fork gregkroon/githubexperiment
cd githubexperiment
```

**Step 2: Trigger all gap demonstrations**
```bash
# Gap 1: Cross-Environment Visibility
gh workflow run "GAP 1 DEMO: Cross-Environment Visibility"

# Gap 2: Lambda Terraform Orchestration
gh workflow run "GAP 2 DEMO: Lambda Deployment Terraform Orchestration"

# Gap 3 is best viewed by reading the file:
cat .github/workflows/gap3-reusable-workflow-maintenance.yml
```

**Step 3: Trigger a real CI/CD flow**
```bash
# Make a change to user-service
echo "// Demo change" >> services/user-service/src/index.js

# Commit and push
git add services/user-service/src/index.js
git commit -m "Trigger full CI/CD pipeline"
git push

# Watch the workflows
gh run watch
```

**What you'll see:**
1. ✅ CI workflow completes (build, scan, sign, SBOM)
2. ✅ CD workflow starts (deploy to dev)
3. ⏸️  Manual approval required for production
4. ✅ Deploy to production (after approval)

---

## Key Takeaways from the Workflows

### What GitHub Actions Does Well ✅

1. **CI (Build, Test, Scan)** - Industry standard, works great
2. **Security Scanning** - Trivy, Grype, Snyk all integrate natively
3. **SBOM Generation** - Syft/Anchore work perfectly
4. **Image Signing** - Cosign integration is solid
5. **Kubernetes Deployment** - With ArgoCD, works beautifully

### What Requires Custom Engineering ⚠️

1. **Cross-Environment Visibility** - Build IDP or manual queries
2. **Lambda/ECS/VM Verification** - Custom orchestration bash around Terraform
3. **Ongoing Maintenance** - Platform team maintains deployment integrations forever
4. **Stateless Runners** - No deployment history, must build custom tracker
5. **Heterogeneous Infrastructure** - Argo Rollouts is K8s-only, rebuild for Lambda/ECS

---

## The Honest Assessment

**Use GitHub Actions for CD if:**
- < 50 services
- 90%+ Kubernetes (ArgoCD handles this well)
- Platform team has bandwidth to build/maintain IDP and orchestration logic

**Use Harness for CD if:**
- 100+ services across heterogeneous infrastructure
- Need cross-environment visibility without building IDP
- Want ML-driven verification for Lambda/ECS/VMs (not just K8s)
- **Want platform team building features, not maintaining deployment glue**

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions (CI) ✅                                 │
│  ├─ Build                                               │
│  ├─ Test                                                │
│  ├─ Security Scan                                       │
│  └─ Push to GHCR                                        │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions (CD) ⚠️                                 │
│  ├─ ArgoCD (K8s only) ✅                                │
│  ├─ Terraform (needs orchestration bash) ⚠️             │
│  ├─ Custom Lambda deployment (60-80 lines) ⚠️           │
│  ├─ Custom ECS deployment (60-80 lines) ⚠️              │
│  ├─ Custom health checks (no ML) ⚠️                     │
│  ├─ Manual cross-env visibility (15-20 min) ⚠️          │
│  └─ Ongoing AWS API maintenance (80-120 hrs/year) ⚠️    │
└─────────────────────────────────────────────────────────┘
                          ↓
                "The Frankenstein Stack"
```

---

## Next Steps

1. **Read**: [README.md](../README.md) for the business case
2. **Demo**: [DEMO.md](DEMO.md) for technical proof
3. **Run**: The gap workflows (this guide)
4. **Share**: [EXECUTIVE_EMAIL.md](EXECUTIVE_EMAIL.md) to leadership

---

**[← Back to README](../README.md)**
