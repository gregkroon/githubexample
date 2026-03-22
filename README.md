# Can You Build Enterprise CI/CD with GitHub?

**Yes. But whether it costs less than Harness depends on your environment.**

This repository compares:
- **GitHub-native** (using built-in features properly)
- **Harness** (purpose-built enterprise platform)

We show:
- ✅ What works (complete CI/CD with approval gates, SBOM attestation, security scanning)
- ⚠️ What's genuinely hard (one-click rollback, advanced deployment strategies)
- 💡 How to use GitHub properly (reusable workflows, OIDC, IaC)
- 💰 Honest cost comparison that depends on your deployment reality:
  - **Homogeneous (K8s-heavy)**: GitHub $2.1M vs Harness $5.5M → **GitHub saves $3.4M**
  - **Heterogeneous (multi-cloud, VMs, serverless, on-prem)**: GitHub $6.7M vs Harness $6M → **Harness saves $700k**

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
- When GitHub is cheaper (homogeneous environments)
- When platforms make sense (heterogeneous at scale)
- Recommendations by actual company size

**Best for**: Leadership making budget decisions

---

### 3. Understand Heterogeneous Reality (10 min) ⚠️

**[→ Read the Heterogeneous Enterprise Reality Check](HETEROGENEOUS_REALITY.md)**

**CRITICAL**: If your enterprise has:
- Multiple clouds (AWS, Azure, GCP)
- Multiple deployment targets (K8s, VMs, ECS, Lambda, on-prem)
- < 60% Kubernetes workloads
- 1000+ services

**Then the cost equation REVERSES**:
- GitHub-native: $6.7M (4.5 FTE platform team, high operational burden)
- Harness: $6M (2 FTE, vendor managed)

**You'll see**:
- Why heterogeneous adds 2,500 lines of custom deployment code
- Why you need 4.5 FTE (not 1.5) for multi-cloud/multi-platform
- Hidden costs: incident response, knowledge silos, cross-platform orchestration
- When Harness actually provides better TCO value

**Best for**: Enterprises with truly heterogeneous environments

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
- ⚠️ Deployment verification (can build custom or use third-party tools)
- ✅ Template locking (use Required Workflows + CODEOWNERS)
- ✅ Centralized config (use reusable workflows)

**6. What You Actually Need to Build** (Much less than claimed)
- SBOM enforcement: ✅ Reusable workflow (2 weeks, not 9)
- DORA metrics: ✅ Use third-party tool ($10-50k/year, not custom build)
- Multi-service orchestration: ⚠️ May need custom code for complex dependencies
- Deployment verification: ⚠️ Custom code or third-party tools (4 weeks)
- **Total: 4-6 weeks + third-party tools (not 32 weeks custom engineering)**

---

### The Honest Cost Comparison (1000 Services, 200 Engineers)

⚠️ **IMPORTANT**: These costs assume a **homogeneous Kubernetes-heavy environment (>80% K8s)**. For heterogeneous environments (multiple clouds, VMs, serverless, on-prem), see [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md).

---

**Scenario A: GitHub-Native (Naive Implementation)**
| | Year 1 | Years 2-5 (each) |
|---|--------|------------------|
| GitHub Enterprise (1000 users ❌) | $400k | $400k |
| Duplicate workflows (no reusable ❌) | $280k | $120k |
| Platform engineers (2-4 FTE ❌) | $600k | $600k |
| **Total** | **$1,280k** | **$1,120k** |
| **5-Year Total** | | **$5,760,000** ❌ |

**What's wrong**: Assumes 1:1 licenses with services, no reusable workflows, duplicate code

---

**Scenario B: GitHub-Native (Proper Configuration)**
| | Year 1 | Years 2-5 (each) |
|---|--------|------------------|
| GitHub Enterprise (200 users ✅) | $50k | $50k |
| Reusable workflows setup | $40k | - |
| IaC for environments (Terraform) | $40k | - |
| Third-party tools (DORA, secrets) | $50k | $50k |
| Platform engineers (1.5 FTE ✅) | $300k | $300k |
| **Total** | **$480k** | **$400k** |
| **5-Year Total** | | **$2,080,000** ✅ |

**What's different**: Correct licensing, reusable workflows, automation, proper staffing

---

**Scenario C: Harness (Hybrid Approach)**
| | Year 1 | Years 2-5 (each) |
|---|--------|------------------|
| GitHub Team (CI, 200 users) | $50k | $50k |
| Harness (realistic enterprise pricing) | $600k | $600k |
| Professional services + training | $300k | - |
| Support (20% annually) | - | $120k |
| Platform engineers (1.5 FTE) | $300k | $300k |
| **Total** | **$1,250k** | **$1,070k** |
| **5-Year Total** | | **$5,530,000** ❌ |

**What this includes**: Vendor platform, still need platform team

---

### Honest Comparison (Homogeneous K8s-Heavy Environments)

| Approach | 5-Year Cost | vs GitHub-Proper |
|----------|-------------|------------------|
| **GitHub-Native (naive)** | **$5,760,000** | +$3,680k ❌ |
| **GitHub-Native (proper)** | **$2,080,000** | Baseline ✅ |
| **Harness (hybrid)** | **$5,530,000** | +$3,450k ❌ |

**Key insight (K8s-heavy)**: With proper configuration, GitHub is **$3.45M cheaper** than Harness over 5 years.

**⚠️ BUT** for heterogeneous environments (<60% K8s), the equation reverses. See [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md).

---

### The Honest Recommendations

**< 50 services** (Startups, Series A-B):
- ✅ **GitHub Actions** (CI + CD)
- ✅ Use reusable workflows from day one
- ✅ Works for: Kubernetes, VMs, serverless, containers
- 💰 Cost: **~$300k over 5 years**
- 👥 Team: 0.5 FTE platform engineer
- **vs Harness**: Not worth the cost at this scale

**50-200 services** (Series C, growth companies):
- ✅ **GitHub Actions** (CI + CD)
- ✅ Reusable workflows + OIDC + Terraform
- ✅ Required Workflows for governance
- 💰 Cost: **$800k-1.2M over 5 years**
- 👥 Team: 1 FTE platform engineer
- **vs Harness**: Save $2-3M, no vendor lock-in

**200-500 services** (Public companies):
- ✅ **GitHub-Native** (recommended for most)
  - Reusable workflows
  - Proper governance (Required Workflows, CODEOWNERS)
  - Terraform for automation
  - 💰 Cost: **$1.5-2M over 5 years**

- ⚠️ **Harness** (only if specific needs)
  - Need ML-based verification?
  - Need vendor support?
  - Budget isn't a constraint?
  - 💰 Cost: **$4-5M over 5 years**
  - **Tradeoff**: +$2.5M for convenience

**500-1000+ services** (Enterprise scale - K8s-heavy):
- ✅ **GitHub-Native** (recommended for K8s-heavy >80%)
  - Use all GitHub Enterprise features
  - Reusable workflows are critical
  - Terraform/Pulumi for everything
  - 💰 Cost: **$2-3M over 5 years**
  - 👥 Team: 1.5-2 FTE platform engineers

- ⚠️ **Harness** (only if budget isn't a constraint)
  - 💰 Cost: **$5-6M over 5 years**
  - **Question**: Is vendor convenience worth $3M premium?

**1000+ services** (Heterogeneous enterprise - <60% K8s):
- ⚠️ **GitHub-Native becomes expensive**
  - Multiple deployment targets (K8s, VMs, ECS, Lambda, on-prem)
  - Need 4.5 FTE platform team (not 1.5)
  - 2,500+ lines custom deployment code across 6 patterns
  - Hidden costs: incidents, silos, cross-platform orchestration
  - 💰 Cost: **$6.7M over 5 years**
  - 👥 Team: 4.5 FTE platform engineers

- ✅ **Harness provides better value**
  - Vendor handles all deployment target integrations
  - Unified interface reduces complexity
  - 💰 Cost: **$6M over 5 years**
  - 👥 Team: 2 FTE
  - **Saves**: $700k + reduces operational burden
  - **See**: [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md)

**Key factors for GitHub-native success**:
- **Environment homogeneity** (>80% K8s is ideal, <60% K8s gets expensive)
- **User count matters** (200 engineers ≠ 1000 licenses)
- **Reusable workflows** (write once, not 1000 times)
- **OIDC** (eliminate AWS/Azure/GCP secrets)
- **Terraform** (automate environment setup)
- **Required Workflows** (enforce governance)

**When to choose Harness**:
- **Truly heterogeneous** (multi-cloud, VMs, serverless, on-prem) AND 1000+ services
- OR budget isn't a constraint AND
- You value vendor support AND
- You need ML-based verification AND
- You accept vendor lock-in

---

## The Key Differences (Honest Assessment)

### What GitHub Does Better
- ✅ **Native integration** - no sync issues, single source of truth
- ✅ **No vendor lock-in** - workflows are portable YAML, not proprietary
- ✅ **Massive ecosystem** - 20,000+ actions, active community
- ✅ **OIDC built-in** - eliminate secrets for AWS, Azure, GCP
- ✅ **Lower cost** - $2M vs $5.5M (with proper configuration)
- ✅ **Developer familiarity** - GitHub Actions is industry standard
- ✅ **Deployment flexibility** - works with K8s, VMs, serverless, anything
- ✅ **Reusable workflows** - write once, use everywhere (GitHub feature)

### What Harness Does Better
- ✅ **One-click rollback** - instant revert to previous version
- ✅ **Advanced deployment strategies** - canary, blue-green built-in
- ✅ **ML-based verification** - automatic anomaly detection (requires tuning)
- ✅ **Better UI/UX** - purpose-built for CD workflows
- ✅ **Template management** - locked outside developer repos
- ⚠️ **Support** - dedicated CD platform support
- ❌ **Cost** - 2.7× more expensive than GitHub-native
- ❌ **Vendor lock-in** - proprietary YAML, hard to migrate away

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
- Complete CI/CD with environments, SBOM, signing, deployment to any target
- Reusable workflows eliminate duplication (210 lines, not 210,000)
- Parallel execution IS solvable (workflow_run, status checks)
- OIDC eliminates most secrets
- Proper governance prevents bypasses (CODEOWNERS + Required Workflows)
- Works with Kubernetes, VMs, serverless, containers - anything

### ⚠️ What's Genuinely Hard (Harness Advantage)
- One-click rollback (GitHub requires redeploy previous version)
- Advanced deployment strategies (canary/blue-green need custom code or third-party tools)
- ML-based deployment verification (not built-in to GitHub)
- Centralized template locking (achievable with Required Workflows but less elegant)

### ⚠️ What's Hard But Solvable (Configuration, Not Capability)
- Environment configuration at scale (use Terraform/Pulumi IaC)
- SBOM attestation complexity (reusable workflow solves it)
- Secret management at scale (use OIDC + Vault)

### 💰 What It Really Costs

| Approach | 5-Year Cost | Configuration |
|----------|-------------|---------------|
| **GitHub (naive)** | **$5.7M** | ❌ Duplicate workflows, wrong licensing |
| **GitHub (proper)** | **$2.1M** | ✅ Reusable workflows, OIDC, Terraform |
| **Harness** | **$5.5M** | ✅ But vendor lock-in |

### 🎯 The Honest Conclusion

**The gap is NOT that GitHub can't do enterprise CI/CD.**

**The gap is:**
1. **Configuration expertise** - must use reusable workflows properly
2. **Feature gaps** - one-click rollback, canary deployments not built-in
3. **Environment complexity** - heterogeneous adds significant cost/burden
4. **Vendor marketing** - Harness claims you need them (usually you don't)

**The honest answer depends on YOUR environment**:

**Homogeneous (K8s-heavy >80%)**:
- ✅ **GitHub-native** is optimal for ALL sizes
- 💰 **$2.1M vs $5.5M Harness** → save $3.4M
- 👥 1.5-2 FTE platform team
- **Recommendation**: Use GitHub, avoid vendor lock-in

**Moderately heterogeneous (60-80% K8s)**:
- ✅ **GitHub-native** still cheaper but harder
- 💰 **$3.5M vs $6M Harness** → save $2.5M
- 👥 3 FTE platform team
- **Tradeoff**: Save money but higher operational burden
- **Recommendation**: Evaluate your team's capacity

**Truly heterogeneous (<60% K8s, multi-cloud, VMs, serverless, on-prem)**:
- ⚠️ **Harness provides better value**
- 💰 **$6M Harness vs $6.7M GitHub** → save $700k
- 👥 2 FTE (Harness) vs 4.5 FTE (GitHub)
- **Tradeoff**: Vendor lock-in vs operational complexity
- **Recommendation**: Harness makes sense at this scale
- **See**: [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md)

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

**But the cost equation depends on your environment:**

**For homogeneous K8s-heavy environments (>80% K8s)**:
- ✅ GitHub-native with proper configuration: **$2.1M**
- ❌ Harness: **$5.5M**
- **Savings: $3.4M with GitHub**
- You need to use it properly:
  - ✅ Reusable workflows (not duplicated code)
  - ✅ OIDC (not manual secrets)
  - ✅ Infrastructure as Code (not manual UI)
  - ✅ Proper governance (CODEOWNERS + Required Workflows)

**For heterogeneous environments (<60% K8s, multi-cloud, VMs, serverless, on-prem)**:
- ⚠️ GitHub-native: **$6.7M** (4.5 FTE, high operational burden)
- ✅ Harness: **$6M** (2 FTE, vendor managed)
- **Savings: $700k with Harness + reduced operational burden**
- See [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md) for details

**The question isn't "Can GitHub do it?" (yes, it can)**

**The question is: "What's your deployment environment mix?"**

- **>80% K8s**: GitHub saves $3.4M
- **60-80% K8s**: GitHub saves $2.5M (but harder)
- **<60% K8s**: Harness saves $700k + operational burden

---

## Essential Reading

### Start Here
- **[Try the Demo](docs/DEMO.md)** - 35-minute hands-on walkthrough showing what works and what breaks
- **[Read Executive Summary](docs/EXECUTIVE_SUMMARY.md)** - 10-minute business case with cost analysis

### If You Have a Heterogeneous Enterprise
- **[Heterogeneous Reality Check](HETEROGENEOUS_REALITY.md)** ⚠️ - CRITICAL if you have:
  - Multiple clouds (AWS, Azure, GCP)
  - Multiple deployment targets (K8s, VMs, ECS, Lambda, on-prem)
  - <60% Kubernetes workloads
  - 1000+ services
  - **Shows when Harness actually provides better TCO**

### See It Live
- **[Watch Workflows Run](https://github.com/gregkroon/githubexample/actions)** - See it live

---

**Use the right tool for YOUR environment.**
