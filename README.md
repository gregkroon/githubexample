# Can You Build Enterprise CI/CD with GitHub?

**Yes. And it might actually be cheaper than enterprise platforms - if you do it right.**

This repository shows:
- ✅ What works (complete CI/CD with approval gates, SBOM attestation, security scanning)
- ⚠️ What's hard (configuration at scale, parallel execution challenges)
- 💡 How to solve it (reusable workflows, open source tools, proper governance)
- 💰 What it really costs (realistic analysis, not vendor marketing)

---

## The Proof

**3 production microservices** with **real CI/CD pipelines** running on every push:

| Service | Language | Pipeline |
|---------|----------|----------|
| user-service | Node.js | Build → Test → Scan → SBOM → Sign → Attest → Dev → Prod |
| payment-service | Go | Build → Test → Scan → SBOM → Sign → Attest → Dev → Prod |
| notification-service | Python | Build → Test → Scan → SBOM → Sign → Attest → Dev → Prod |

**Watch them run**: https://github.com/gregkroon/githubexample/actions

---

## Two Ways to Understand This

### 1. Try It Yourself (35 min)

**[→ Follow the Step-by-Step Demo](docs/DEMO.md)**

**You'll see**:
- ✅ Complete working CI/CD with environments, SBOM, signing
- ✅ Reusable workflow solutions (how to avoid duplication)
- ❌ What's genuinely hard at scale (configuration sprawl)
- 💡 How to solve parallel execution (workflow_run)
- 💰 Realistic cost breakdown (not vendor marketing)

**Best for**: Engineers who need to make technical decisions

---

### 2. Read the Honest Business Case (15 min)

**[→ Read the Executive Summary](docs/EXECUTIVE_SUMMARY.md)**

**You'll learn**:
- What GitHub does well (and what it doesn't)
- Realistic cost analysis (corrected for reusable workflows)
- Open source alternatives (Argo CD, Flux - free)
- When GitHub is cheaper (< 500 services)
- When platforms make sense (500+ services)
- Recommendations by actual company size

**Best for**: Leadership making budget decisions

---

## The Bottom Line

### What Works ✅

**GitHub Actions is excellent for CI/CD**:
- Automated builds, tests, security scanning
- Native GitHub integration (no sync issues)
- OIDC for cloud providers (eliminate secrets)
- Reusable workflows (write once, use everywhere)
- Massive ecosystem (thousands of actions)
- **No vendor lock-in** (workflows are portable YAML)

---

### What's Hard at Scale (But Solvable) ⚠️

**1. Configuration Sprawl** (✅ Solvable with reusable workflows)
- ❌ Without reusable workflows: 1,000 duplicate workflow files
- ✅ With reusable workflows: Write once, reference 1000 times
- ✅ With IaC (Terraform): Automate environment setup
- **Solution**: Use GitHub's reusable workflow feature (demonstrated in this repo)

**2. Parallel Execution** (✅ Solvable with workflow_run)
- ❌ Claimed as "architectural limitation"
- ✅ Actually solvable with `workflow_run` trigger:
```yaml
on:
  workflow_run:
    workflows: ["Security Scan"]
    types: [completed]
jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
```
- ✅ Also: Status checks, environment protection rules
- **Solution**: Proper workflow orchestration (examples in docs)

**3. SBOM Attestation** (✅ Simpler with reusable workflows)
- ❌ Naive approach: 210 lines × 1000 services = 210,000 lines
- ✅ Reusable workflow: 210 lines once, 1 line per service = 1,210 lines total
- ✅ Or use Argo CD with policy controller (free, open source)
- **Solution**: Reusable workflow (shown in demo)

**4. Environment Configuration** (⚠️ Manual but automatable)
- ❌ Manual UI: 3,000 environments to configure
- ✅ Terraform/Pulumi: Automate environment creation
- ✅ OIDC: Eliminate 80% of secrets
- ✅ Vault integration: Centralize secret management
- **Solution**: Infrastructure as Code (not demonstrated, but standard practice)

**5. Missing Features** (⚠️ Some gaps are real)
- ❌ One-click rollback (real gap - need to redeploy previous version)
- ❌ Advanced deployment strategies (canary/blue-green need custom code)
- ⚠️ Deployment verification (can build or use Argo Rollouts)
- ✅ Template locking (use Required Workflows + CODEOWNERS)
- ✅ Centralized config (use reusable workflows)

**6. What You Actually Need to Build** (Much less than claimed)
- SBOM enforcement: ✅ Reusable workflow (2 weeks, not 9)
- DORA metrics: ✅ Use third-party tool ($10-50k/year, not custom build)
- Multi-service orchestration: ✅ Use Argo Workflows or Flux (free)
- Deployment verification: ✅ Use Argo Rollouts (free) or Flagger (free)
- **Total: 2-4 weeks + open source tools (not 32 weeks custom engineering)**

---

### The Honest Cost Comparison (1000 Services, 200 Engineers)

**Scenario A: GitHub-Native (Properly Configured)**
| | Year 1 | Years 2-5 (each) |
|---|--------|------------------|
| GitHub Enterprise (200 users) | $50k | $50k |
| Reusable workflows setup | $40k | - |
| IaC for environments (Terraform) | $40k | - |
| Third-party tools (DORA, secrets) | $50k | $50k |
| Platform engineers (1.5 FTE) | $300k | $300k |
| **Total** | **$480k** | **$400k** |
| **5-Year Total** | | **$2,080,000** |

**Scenario B: GitHub + Open Source CD (Argo/Flux)**
| | Year 1 | Years 2-5 (each) |
|---|--------|------------------|
| GitHub Team (CI only, 200 users) | $50k | $50k |
| Argo CD / Flux | $0 | $0 |
| Setup and integration | $60k | - |
| Platform engineers (1.5 FTE) | $300k | $300k |
| **Total** | **$410k** | **$350k** |
| **5-Year Total** | | **$1,810,000** |

**Scenario C: GitHub + Harness**
| | Year 1 | Years 2-5 (each) |
|---|--------|------------------|
| GitHub Team (CI, 200 users) | $50k | $50k |
| Harness (realistic enterprise pricing) | $600k | $600k |
| Professional services + training | $300k | - |
| Support (20% annually) | - | $120k |
| Platform engineers (1.5 FTE) | $300k | $300k |
| **Total** | **$1,250k** | **$1,070k** |
| **5-Year Total** | | **$5,530,000** |

### Honest Comparison

| Approach | 5-Year Cost | vs GitHub-Native | vs Argo CD |
|----------|-------------|------------------|------------|
| **GitHub-Native** | **$2,080,000** | Baseline | +$270k |
| **GitHub + Argo CD** | **$1,810,000** | **-$270k** | Baseline |
| **GitHub + Harness** | **$5,530,000** | **+$3,450k** | **+$3,720k** |

**Key insight**: Harness is 3× more expensive than GitHub+Argo, not cheaper.

---

### The Honest Recommendations

**< 50 services** (Startups, Series A-B):
- ✅ **GitHub Actions** (CI + CD)
- ✅ Use reusable workflows
- 💰 Cost: **~$300k over 5 years**
- 👥 Team: 0.5 FTE platform engineer

**50-200 services** (Series C, growth companies):
- ✅ **GitHub Actions** (CI + CD)
- ✅ Reusable workflows + OIDC
- ✅ Optional: Argo CD for advanced deployments
- 💰 Cost: **$800k-1.2M over 5 years**
- 👥 Team: 1 FTE platform engineer

**200-500 services** (Public companies):
- ✅ **GitHub Actions** (CI)
- ✅ **Argo CD or Flux** (CD) - free, proven at scale
- ✅ Reusable workflows + proper governance
- 💰 Cost: **$1.5-2M over 5 years**
- 👥 Team: 1-2 FTE platform engineers
- **Why not Harness**: Save $3-4M, no vendor lock-in

**500-1000+ services** (Netflix, Uber scale):
- ⚠️ **Evaluate all options**:
  - GitHub + Argo CD: $2-3M (recommended for most)
  - GitHub + Harness: $5-6M (if budget allows)
  - Custom platform: $3-5M (if you have resources)
- 💰 Most cost-effective: **GitHub + Argo CD**
- 👥 Team: 2-3 FTE platform engineers

**Key factors**:
- **User count matters more than service count** (200 engineers ≠ 1000 licenses)
- **Reusable workflows eliminate duplication** (write once, not 1000 times)
- **Open source alternatives exist** (Argo, Flux - battle-tested, free)
- **Vendor lock-in is expensive** (Harness proprietary YAML)

---

## The Key Differences (Honest Assessment)

### What GitHub Does Better
- ✅ **Native integration** - no sync issues, single source of truth
- ✅ **No vendor lock-in** - workflows are portable YAML, not proprietary
- ✅ **Massive ecosystem** - 20,000+ actions, active community
- ✅ **OIDC built-in** - eliminate secrets for AWS, Azure, GCP
- ✅ **Lower cost** - $2M vs $5.5M (with proper configuration)
- ✅ **Developer familiarity** - GitHub Actions is industry standard

### What Harness Does Better
- ✅ **One-click rollback** - instant revert to previous version
- ✅ **Advanced deployment strategies** - canary, blue-green built-in
- ✅ **ML-based verification** - automatic anomaly detection
- ✅ **Better UI/UX** - purpose-built for CD workflows
- ✅ **Template management** - centralized, version-controlled
- ⚠️ **Support** - dedicated CD platform support (but costly)

### What Open Source Does Best (Argo CD / Flux)
- ✅ **GitOps native** - declarative, auditable, rollback-friendly
- ✅ **Zero cost** - no licensing fees
- ✅ **Battle-tested** - Netflix, Intuit, Adobe, Alibaba
- ✅ **Kubernetes-native** - purpose-built for K8s
- ✅ **Active community** - CNCF graduated projects
- ✅ **No vendor lock-in** - open source, portable

### The "Parallel Execution Gap" (Solvable)

**Claimed problem**: "Cannot enforce security before deploy"

**Actual solution**:
```yaml
# CD workflow waits for security
on:
  workflow_run:
    workflows: ["Security Scan"]
    types: [completed]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        # Only runs if security passed!
```

**Also works**: Environment protection rules, required status checks, deployment protection rules

**Conclusion**: Configuration challenge, not architectural limitation

---

## Repository Contents

```
├── services/                    # 3 production microservices
│   ├── user-service/           # Node.js
│   ├── payment-service/        # Go
│   └── notification-service/   # Python
│
├── .github/workflows/          # 6 real workflows (RUNS LIVE)
│   ├── ci-user-service.yml
│   ├── cd-user-service.yml
│   ├── ci-payment-service.yml
│   ├── cd-payment-service.yml
│   ├── ci-notification-service.yml
│   └── cd-notification-service.yml
│
├── platform/                    # GitHub Enterprise configs
│   ├── .github/workflows/      # Required Workflows
│   ├── policies/               # OPA policies
│   └── rulesets/               # Organization Rulesets
│
└── docs/
    ├── DEMO.md                 # Step-by-step walkthrough
    └── EXECUTIVE_SUMMARY.md    # Business case
```

---

## What This Repository Actually Proves

### ✅ What Works (Better Than Expected)
- Complete CI/CD with environments, SBOM, signing, deployment
- Reusable workflows eliminate duplication (210 lines, not 210,000)
- Parallel execution IS solvable (workflow_run, status checks)
- OIDC eliminates most secrets
- Proper governance prevents bypasses (CODEOWNERS + Required Workflows)

### ⚠️ What's Challenging (But Solvable)
- Environment configuration at scale (use Terraform/Pulumi IaC)
- SBOM attestation complexity (reusable workflow solves it)
- Advanced deployment strategies (use Argo Rollouts or Flagger - free)
- One-click rollback (need to redeploy, not instant)

### 💰 What It Really Costs
- **With naive approach**: $5.7M (duplicated code, manual config)
- **With reusable workflows**: $2.1M (proper GitHub usage)
- **With GitHub + Argo CD**: $1.8M (open source CD layer)
- **With GitHub + Harness**: $5.5M (vendor platform)

### 🎯 The Honest Conclusion

**The gap is NOT operational efficiency.**

**The gap is configuration expertise and vendor marketing.**

✅ GitHub-native: $2.1M (with proper configuration)
✅ GitHub + Argo CD: $1.8M (best value, no vendor lock-in)
❌ GitHub + Harness: $5.5M (3× more expensive, vendor lock-in)

**For most companies (< 500 services)**: GitHub + open source is optimal

**For enterprises (500+ services)**: Evaluate GitHub+Argo vs custom platform vs Harness based on your specific needs, not vendor claims

---

## Try It

**Fork this repo** and watch the workflows run:

```bash
# 1. Fork on GitHub (click Fork button)

# 2. Clone your fork
git clone https://github.com/YOUR-USERNAME/githubexperiment

# 3. Make a change
echo "// test" >> services/user-service/src/index.js

# 4. Push and watch
git add . && git commit -m "test" && git push origin main

# 5. Watch at: https://github.com/YOUR-USERNAME/githubexperiment/actions
```

**Then**: [Follow the Demo](docs/DEMO.md) to see what breaks at scale.

---

## The Honest Truth

**GitHub Actions is excellent for enterprise CI/CD.**

**But you need to use it properly:**
- ✅ Reusable workflows (not duplicated code)
- ✅ OIDC (not manual secrets)
- ✅ Infrastructure as Code (not manual UI)
- ✅ Proper governance (CODEOWNERS + Required Workflows)

**Open source CD tools (Argo, Flux) are battle-tested and free.**

**Enterprise platforms (Harness) provide convenience at 3× the cost.**

The hardest thing to admit: **GitHub + proper configuration is often the best answer.**

Don't let vendor marketing convince you that you need expensive platforms when open source solutions exist.

---

## Quick Links

- **[Try the Demo](docs/DEMO.md)** - 35-minute hands-on walkthrough showing what works and what breaks
- **[Read Executive Summary](docs/EXECUTIVE_SUMMARY.md)** - 10-minute business case with cost analysis
- **[Watch Workflows Run](https://github.com/gregkroon/githubexample/actions)** - See it live

---

**Use the right tool for the job.**
