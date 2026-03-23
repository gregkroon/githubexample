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

### 🔍 Gap 1: The State & Visibility Gap (Stateless Runners)

**File**: `.github/workflows/gap1-cross-env-visibility.yml`

**What it demonstrates:**
- GitHub Actions runners are stateless, ephemeral VMs with no deployment memory
- Manual kubectl queries required across 4 environments (Dev, QA, Staging, Prod)
- 15-20 minutes to compile deployment state for 50 services
- Manual git commit SHA correlation
- Why platform teams build Internal Developer Portals (Backstage) to track state

**The Core Problem**:
> Stateless runners have no memory of what they deployed, what version is running in production, or how to roll it back.

**The Question**:
> "Show me what version of all 50 microservices is deployed in Dev, QA, Staging, and Production right now."

**Run it:**
```bash
gh workflow run "GAP 1 DEMO: The State & Visibility Gap (Stateless Runners)"
```

**What you'll see:**
- How stateless runners force manual state tracking
- Manual kubectl commands for each environment
- The correlation nightmare (200 image tags → git SHAs)
- IDP build requirements (6-8 weeks + 4-6 hrs/week maintenance)
- Harness alternative: Stateful control plane with 5-second API query

**Maps to**: [DEMO.md - Gap 1](DEMO.md#gap-1-the-state--visibility-gap-stateless-runners)

---

### 🚨 Gap 2: The Verification Gap ("Deploy and Pray")

**File**: `.github/workflows/gap2-lambda-terraform-orchestration.yml`

**What it demonstrates:**
- A successful deployment just means the container started (not that the app is healthy)
- Custom bash scripts to curl Datadog/New Relic APIs and guess if deployments are safe
- Hard-coded thresholds (no baseline comparison)
- Terraform is declarative state, not a release orchestrator
- Custom bash orchestration wrapping Terraform applies
- Manual CloudWatch polling for verification
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
gh workflow run "GAP 2 DEMO: The Verification Gap (Deploy and Pray)"
```

**What you'll see:**
- The 5-step custom orchestration dance
- Structural flaws (hard-coded thresholds, fragile API dependencies, guessing if deployments are safe)
- Why this pattern must be rebuilt for ECS, VMs, databases
- Harness Continuous Verification: ML-driven baseline anomaly detection with auto-rollback

**Maps to**: [DEMO.md - Gap 2](DEMO.md#gap-2-the-verification-gap-deploy-and-pray)

---

### 🔧 Gap 3: The Heterogeneous Infrastructure Tax

**File**: `.github/workflows/gap3-reusable-workflow-maintenance.yml`

**What it demonstrates:**
- GitOps (ArgoCD + GHA) is fantastic if you're 100% Kubernetes (most enterprises aren't)
- Typical enterprise: 40% K8s, 30% Serverless/ECS, 20% EC2/VMs, 10% databases
- The GHA workaround: Reusable Workflows + Terraform modules + AWS CLI wrappers for non-K8s infrastructure
- 7 maintenance events in last 6 months (AWS API changes, runtime deprecations)
- 80-120 hours/year maintenance burden when AWS deprecates runtimes or changes APIs
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
- Every step annotated with maintenance burden from heterogeneous infrastructure
- 6-month maintenance timeline (7 breaking AWS changes)
- Emergency fixes (Friday 5pm Lambda outage: 6 hours on-call)
- The buy-vs-build cost calculation ($150k/year maintenance vs vendor roadmap wait)
- Why "control" is expensive when AWS deprecates runtimes
- Harness native templates for K8s, Serverless, VMs - vendor maintains integrations

**Maps to**: [DEMO.md - Gap 3](DEMO.md#gap-3-the-heterogeneous-infrastructure-tax)

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
| `gap1-cross-env-visibility.yml` | Stateless runners, manual kubectl queries, IDP building burden | [DEMO.md Gap 1](DEMO.md#gap-1-the-state--visibility-gap-stateless-runners) |
| `gap2-lambda-terraform-orchestration.yml` | Deploy and pray, Terraform orchestration bash, hard-coded thresholds | [DEMO.md Gap 2](DEMO.md#gap-2-the-verification-gap-deploy-and-pray) |
| `gap3-reusable-workflow-maintenance.yml` | Heterogeneous infrastructure, ongoing AWS API change maintenance | [DEMO.md Gap 3](DEMO.md#gap-3-the-heterogeneous-infrastructure-tax) |
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
# Gap 1: The State & Visibility Gap (Stateless Runners)
gh workflow run "GAP 1 DEMO: The State & Visibility Gap (Stateless Runners)"

# Gap 2: The Verification Gap (Deploy and Pray)
gh workflow run "GAP 2 DEMO: The Verification Gap (Deploy and Pray)"

# Gap 3: The Heterogeneous Infrastructure Tax (best viewed by reading the file)
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

1. **State & Visibility** - Stateless runners have no deployment memory, must build IDP or manual queries
2. **Verification** - Deployment success ≠ app health, custom bash scripts to guess if deployments are safe
3. **Heterogeneous Infrastructure** - ArgoCD/Argo Rollouts is K8s-only, must maintain Terraform modules + AWS CLI wrappers for Lambda/ECS/VMs
4. **Ongoing Maintenance** - Platform team maintains deployment integrations forever when AWS deprecates runtimes/APIs

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
