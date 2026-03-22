# Executive Summary: The Honest Cost of Enterprise CI/CD

**For**: Engineering leadership, platform teams, decision-makers
**Read time**: 15 minutes

---

## The Question

**Can you build enterprise-grade CI/CD for 1000+ microservices using GitHub-native tooling?**

We built a complete working implementation to find out.

---

## The Honest Answer

**Yes, and it's likely CHEAPER than enterprise platforms - if you configure it properly.**

| Metric | GitHub (Naive) | GitHub (Proper) | GitHub + Argo CD | Harness |
|--------|----------------|-----------------|------------------|---------|
| Reusable workflows | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| User licenses | 1000 | **200** | **200** | **200** |
| Custom code | 210k lines | **1,250 lines** | **0 lines** | **0 lines** |
| Setup time | 32 weeks | **4 weeks** | **4 weeks** | 4 weeks |
| Platform engineers | 2-4 FTE | **1.5 FTE** | **1.5 FTE** | 1.5 FTE |
| **5-year cost** | **$5.9M** | **$2.1M** | **$1.8M** | **$5.7M** |
| Vendor lock-in | None | None | None | **Yes** |

**Comparison vs Best Value (Argo CD)**:
- GitHub-Proper: +$270k (13% more, but no new tools)
- **Argo CD: Best value** ($1.8M, proven at Netflix scale, free)
- Harness: +$3.9M (3.2× more expensive, vendor lock-in)

---

## What We Built

**3 production microservices** with **real CI/CD pipelines that run on every push**:

- **user-service** (Node.js)
- **payment-service** (Go)
- **notification-service** (Python)

**Each has**:
- Automated builds and tests
- Security scanning (Trivy, Grype, CodeQL)
- SBOM generation (Syft)
- Image signing (Cosign)
- Policy validation (OPA/Conftest)
- Kubernetes deployment
- 17 security gates total

**All workflows run live** - fork the repo and watch: https://github.com/gregkroon/githubexample/actions

**This proves**: ✅ **GitHub CAN do enterprise CI/CD**

---

## What Works Well

**GitHub Actions for CI**:
- ✅ Excellent build and test orchestration
- ✅ Comprehensive security scanning (CodeQL, Dependabot, Trivy)
- ✅ Native GitHub integration
- ✅ Good developer experience
- ✅ OIDC for secure cloud authentication
- ✅ Reusable workflows reduce duplication

**Recommendation**: **Keep using GitHub Actions for CI**

---

## What Breaks at 1000+ Repos

### 1. Configuration Sprawl

**Problem**: 1000 repos × 3 environments = **3,000 separate configurations**

**Impact**:
- 1,000 workflow files to maintain (one per repo)
- 3,000 environment configurations (staging, production, dev)
- Each environment needs manual setup: secrets, approvals, protection rules
- No centralized management
- Configuration drift inevitable

**Time cost**: 250 hours initial setup + 2-3 hrs/week managing drift

**Harness**: 1 centralized configuration for all services

---

### 2. Developers Control Workflows

**Problem**: Workflow files live IN developer repositories

**Impact**:
Developers can bypass security:
```yaml
# Easy bypass:
jobs:
  security-scan:
    continue-on-error: true  # ← Security never blocks
```

**Even with GitHub Enterprise**:
- ✅ CODEOWNERS requires platform team approval
  - ❌ But manual review doesn't scale to 1000 repos
  - ❌ Subtle bypasses slip through code review
- ✅ Required Workflows run org-wide
  - ❌ But runs in PARALLEL (see #3)

**Harness**: Templates locked outside developer repos (architecturally impossible to bypass)

---

### 3. Parallel Execution (THE CRITICAL GAP)

**Problem**: No cross-workflow dependencies in GitHub Actions

**What happens**:
```
t=0:   Developer pushes code
t=0:   Required Workflow starts (platform team's security scan)
t=0:   Developer Workflow starts (build, deploy)
t=3m:  Developer workflow DEPLOYS to production ✅
t=5m:  Required workflow finds CRITICAL CVE ❌

Result: Vulnerable code ALREADY IN PRODUCTION
```

**Why**: Both workflows triggered by same event run independently and simultaneously

**Even with GitHub Enterprise ($400k/year)**:
- ✅ Required Workflows scan all repos
- ✅ Organization Rulesets enforce policies
- ❌ **Cannot make developer workflow wait for required workflow**
- ❌ **No way to enforce "deploy ONLY IF security passes"**

**This is architectural, not a missing feature.**

**Harness**: Sequential stages (Deploy stage waits for Security stage to pass)

---

### 4. SBOM Attestation Complexity

**The requirement**: Cryptographically verify SBOM before deployment (SLSA, SSDF compliance)

**What's required per service**:
- Generate SBOM: 1 line (easy - Syft action)
- Validate SBOM: 90 lines (check banned packages, licenses)
- Sign attestation: 40 lines (Cosign keyless signing)
- Verify at deployment: 80 lines (2 environments × 40 lines each)
- **Total: 210 lines per service**

**At scale (1000 services)**:
- Total code: 210,000 lines of SBOM enforcement
- Update policy: Edit 1000 CI workflows + 2000 CD workflows
- Skills required: Cosign, OIDC, Sigstore, base64, jq, regex
- Build time: 9 weeks
- Ongoing: 8-12 hrs/week (policy updates, Cosign upgrades, debugging)

**Harness**: 10 lines of config, centralized policy, zero custom code

---

### 5. Custom Engineering Required

**To match dedicated CD platforms, you must build**:

| Service | Purpose | Build Time | Ongoing |
|---------|---------|------------|---------|
| SBOM Enforcement | Validation + attestation + verification | 9 weeks | 8-12 hrs/week |
| Deployment Gate | Metrics-based verification (error rate, latency) | 4 weeks | 4-8 hrs/week |
| DORA Metrics | Track deployment frequency, lead time, MTTR | 3 weeks | 2-4 hrs/week |
| Policy Validation | Centralized policy enforcement | 3 weeks | 2-4 hrs/week |
| Multi-Service Orchestrator | Deploy services in correct order | 6 weeks | 8-12 hrs/week |
| Deployment Verifier | Canary analysis, automatic rollback | 4 weeks | 4-8 hrs/week |
| Configuration Service | Centralize environment configs | 3 weeks | 2-4 hrs/week |

**Total**: **32 weeks initial** + **30-48 hrs/week ongoing**

**Harness**: All built-in

---

### 6. Missing Capabilities

| Capability | GitHub | Must Build | Harness |
|------------|--------|-----------|---------|
| SBOM attestation | ⚠️ 210 lines/service | 9 weeks | ✅ Config-driven |
| One-click rollback | ❌ | N/A | ✅ Built-in |
| Deployment verification (ML) | ❌ | 4 weeks | ✅ Built-in |
| Canary deployments | ❌ | 3 weeks | ✅ Built-in |
| Multi-service orchestration | ❌ | 6 weeks | ✅ Built-in |
| Centralized configuration | ❌ | 3 weeks | ✅ Built-in |
| Template locking | ❌ | Impossible | ✅ Built-in |
| Sequential enforcement | ❌ | Impossible | ✅ Built-in |
| DORA metrics | ❌ | 3 weeks | ✅ Built-in |
| Deployment observability | ❌ | 2 weeks | ✅ Built-in |

---

## Operational Burden

### Daily Operations at 1000 Repos

**What breaks and how often**:

| Issue | Frequency | Time to Fix |
|-------|-----------|-------------|
| Security scan failures | 5-10/week | 30-60 min |
| Workflow syntax errors | 3-5/week | 15-30 min |
| Secret rotation | Monthly | 4-8 hours |
| Environment config drift | Weekly | 2-3 hours |
| Tool version updates | Monthly | 8-16 hours |
| Custom service downtime | 2-3/month | 1-4 hours |
| Integration failures | Weekly | 1-2 hours |

**Total toil**: **16-24 hours/week** = **0.4-0.6 FTE just handling failures**

**Team required**: **2-4 platform engineers**

---

## Cost Analysis (5 Years) - The Honest Version

### Scenario A: GitHub-Native (Naive Implementation)

**What this assumes**:
- ❌ Duplicate workflows (no reusable workflows)
- ❌ 1000 GitHub licenses (1:1 with services)
- ❌ Manual environment configuration
- ❌ No OIDC (manual secrets)

**Year 1**:
```
GitHub Enterprise (1000 users): $400,000
  └─ Wrong assumption: 1:1 licenses with services
Custom Services: $280,000
  └─ Building what reusable workflows solve
Platform Engineers (2-4 FTE): $600,000
────────────────────────────────────────
Year 1 Total: $1,280,000
```

**Years 2-5**: $1,120,000/year

**5-Year Total**: **$5,760,000** ❌ (poor configuration)

---

### Scenario B: GitHub-Native (Proper Implementation)

**What this assumes**:
- ✅ Reusable workflows (write once, not 1000 times)
- ✅ 200 GitHub licenses (actual engineers, not services)
- ✅ Terraform for environment automation
- ✅ OIDC for cloud providers (eliminate AWS keys)
- ✅ Vault integration for remaining secrets

**Year 1**:
```
GitHub Enterprise (200 users): $50,000
  └─ 200 engineers × $21/month × 12
Reusable Workflow Setup: $40,000
  └─ 2 weeks, one-time
Terraform Automation: $40,000
  └─ 2 weeks, one-time
Third-Party Tools (DORA, etc.): $50,000
Platform Engineers (1.5 FTE): $300,000
────────────────────────────────────────
Year 1 Total: $480,000
```

**Years 2-5**: $400,000/year

**5-Year Total**: **$2,080,000** ✅ (proper configuration)

**Savings vs naive**: $3,680,000 (64% less)

---

### Scenario C: GitHub + Argo CD (Best Value)

**What you get**:
- ✅ GitHub Actions (CI)
- ✅ Argo CD (CD) - FREE, open source
- ✅ Argo Rollouts - canary, automatic rollback - FREE
- ✅ GitOps - declarative, auditable
- ✅ Battle-tested: Netflix, Adobe, Intuit, IBM, Red Hat

**Year 1**:
```
GitHub Team (200 users, CI only): $50,000
  └─ $4/user/month sufficient for CI
Argo CD + Rollouts: $0
  └─ Open source, CNCF graduated
Setup and Integration: $60,000
  └─ 3 weeks, one-time
Platform Engineers (1.5 FTE): $300,000
────────────────────────────────────────
Year 1 Total: $410,000
```

**Years 2-5**: $350,000/year

**5-Year Total**: **$1,810,000** ✅ (best value)

**Savings vs Harness**: $3,900,000 (68% less)

---

### Scenario D: GitHub + Harness (Most Expensive)

**What you get**:
- ✅ GitHub Team (CI only)
- ⚠️ Harness (CD) - proprietary, vendor lock-in
- ⚠️ ML-based verification (still needs tuning)
- ❌ 3× more expensive than Argo CD

**Year 1** (Implement):
```
GitHub Team (200 users, CI only): $50,000
  └─ Realistic user count

Harness Enterprise (1000 services): $600,000
  └─ Realistic per-service pricing ($600/service/year)

Professional Services: $200,000
  └─ Realistic implementation cost

Training: $100,000
  └─ Team training, certifications

Platform Engineers (1.5 FTE): $300,000
  └─ Still need platform team

────────────────────────────────────────
Year 1 Total: $1,250,000
```

**Years 2-5** (Operate):
```
GitHub Team: $50,000/year
Harness Licenses: $600,000/year
Support (20% annually): $120,000/year
Platform Engineers (1.5 FTE): $300,000/year

────────────────────────────────────────
Per Year: $1,070,000
```

**5-Year Total**: **$5,530,000** ❌ (vendor platform)

**Cost vs Argo CD**: +$3,720,000 (3.1× more expensive)

---

### Honest Cost Comparison

| Approach | Year 1 | Years 2-5 (each) | 5-Year Total | vs Best Value |
|----------|--------|------------------|--------------|---------------|
| **GitHub (naive)** | $1,280k | $1,120k | **$5,760,000** | +$3,950k ❌ |
| **GitHub (proper)** | $480k | $400k | **$2,080,000** | +$270k |
| **GitHub + Argo CD** | $410k | $350k | **$1,810,000** | Baseline ✅ |
| **Harness** | $1,250k | $1,070k | **$5,530,000** | +$3,720k ❌ |

### Key Insights

**1. User Count Matters More Than Service Count**
- ❌ Naive: 1000 licenses ($400k/year)
- ✅ Realistic: 200 engineers ($50k/year)
- **Savings**: $350k/year = $1.75M over 5 years

**2. Reusable Workflows Eliminate Duplication**
- ❌ Naive: 250 lines × 1000 = 250,000 lines
- ✅ Proper: 250 lines + (1 × 1000) = 1,250 lines
- **Savings**: 99.5% less code to maintain

**3. Open Source CD Tools Are Battle-Tested and Free**
- Argo CD: Used by Netflix, Adobe, Intuit, IBM
- CNCF Graduated Project (proven governance)
- Free forever (no vendor pricing changes)
- **Savings**: $3.7M vs Harness over 5 years

**4. Vendor Platforms Are 3× More Expensive**
- Harness: $5.5M
- Argo CD: $1.8M
- **Difference**: $3.7M (206% premium for vendor convenience)

---

## Risk Analysis

### GitHub-Native Risks

**Technical Risks**:
- ❌ Parallel execution gap (cannot architecturally enforce security before deploy)
- ❌ Custom services become critical path (failure blocks all deployments)
- ❌ Developer bypass risk (workflow files in repos)
- ❌ Configuration drift (3,000 distributed configs)

**Operational Risks**:
- ❌ Platform team burnout (2-4 FTE managing toil)
- ❌ Incident response (no one-click rollback)
- ❌ Scaling challenges (manual review doesn't scale to 1000 repos)

**Business Risks**:
- ❌ Higher TCO ($1.9M more over 5 years)
- ❌ Longer time-to-value (23 weeks custom development)
- ❌ Vendor lock-in (custom services tightly coupled to GitHub)

---

### Hybrid Approach Risks

**Technical Risks**:
- ⚠️ Two platforms to manage (GitHub + Harness)
- ⚠️ Integration complexity (CI to CD handoff)

**Mitigation**:
- ✅ Standard integration (push image to registry, trigger Harness)
- ✅ Harness has native GitHub integration
- ✅ Widely used pattern in industry

**Operational Risks**:
- ⚠️ Learning curve for Harness
- ⚠️ Dependency on Harness platform

**Mitigation**:
- ✅ Professional services and training included
- ✅ Harness has 99.9% SLA
- ✅ Large community and support

**Business Risks**:
- ⚠️ Platform cost ($400k/year)

**Mitigation**:
- ✅ Offset by reduced headcount (1.5-3 FTE savings)
- ✅ Lower TCO overall
- ✅ Standard for enterprises at this scale

---

## Honest Recommendations by Company Size

### For < 50 Services (Startups, Series A-B)
✅ **GitHub Actions (CI + CD)**

**Why**:
- Operational burden is minimal
- No need for complex orchestration
- Team is small, can manage manually

**Cost**: ~$300k over 5 years
**Team**: 0.5 FTE platform engineer

---

### For 50-200 Services (Series C, Growth Stage)
✅ **GitHub Actions (CI + CD) with Reusable Workflows**

**Why**:
- Start using reusable workflows NOW
- Terraform for environment automation
- OIDC for cloud providers
- No need for additional tools yet

**Cost**: $800k-1.2M over 5 years
**Team**: 1 FTE platform engineer

**Optional**: Add Argo CD for advanced deployment strategies

---

### For 200-500 Services (Public Companies)
✅ **GitHub + Argo CD (Recommended)**

**Why**:
- GitHub Actions (CI) - excellent, native integration
- Argo CD (CD) - FREE, battle-tested, GitOps
- No vendor lock-in, proven at scale
- **Save $3-4M vs Harness**

**Cost**: $1.5-2M over 5 years
**Team**: 1-2 FTE platform engineers

**Alternative**: GitHub-native if team prefers fewer tools (+$300k)

**Don't choose Harness unless**: Budget isn't a constraint and you value vendor support over cost

---

### For 500-1000+ Services (Enterprise, Netflix Scale)
⚠️ **Evaluate All Options**

**Option A: GitHub + Argo CD** (Recommended for most)
- Cost: $2-3M over 5 years
- Proven: Netflix, Adobe, Intuit
- No vendor lock-in
- **Best value**

**Option B: Build Custom Platform**
- Cost: $3-5M over 5 years
- Full control, tailored to needs
- Requires significant engineering resources
- Only if you have the team

**Option C: GitHub + Harness**
- Cost: $5-6M over 5 years
- Vendor support, ML features
- **3× more expensive than Argo**
- Only if cost isn't a factor

**Decision factors**:
- Budget constraints? → Argo CD
- Want full control? → Custom platform
- Want vendor support at any cost? → Harness

**Most companies choose**: GitHub + Argo CD (best value, proven, no lock-in)

---

## Decision Framework

### Choose GitHub-Native If:
- ✅ You have < 50 repositories
- ✅ You have 2-4 available platform engineers
- ✅ You can build and maintain custom services
- ✅ Manual code review is acceptable
- ✅ Parallel execution gap is acceptable risk

### Choose Hybrid (GitHub CI + Harness CD) If:
- ✅ You have 1000+ repositories
- ✅ You want lower total cost of ownership
- ✅ You need locked templates (governance)
- ✅ You need sequential enforcement (security before deploy)
- ✅ You want one-click rollback
- ✅ You want to avoid custom engineering

---

## Implementation Timeline

### GitHub-Native
**Weeks 1-4**: Set up GitHub Enterprise, CODEOWNERS, Rulesets
**Weeks 5-12**: Build deployment gate service
**Weeks 13-16**: Build DORA metrics collector
**Weeks 17-19**: Build policy validation service
**Weeks 20-29**: Build multi-service orchestrator
**Weeks 30-33**: Build deployment verifier
**Weeks 34-37**: Build configuration service
**Weeks 38-40**: Integration testing and rollout

**Total**: **40 weeks** (10 months)

---

### Hybrid Approach
**Weeks 1-2**: GitHub Team setup (CI workloads)
**Weeks 3-4**: Harness installation and configuration
**Weeks 5-6**: Template development (production deployment)
**Weeks 7-8**: Integration (GitHub CI → Harness CD)
**Weeks 9-10**: Training and documentation
**Weeks 11-12**: Pilot with 10 services
**Weeks 13-16**: Rollout to all 1000 services

**Total**: **16 weeks** (4 months)

**Time saved**: **24 weeks** (6 months faster)

---

## The Honest Bottom Line

**GitHub can do enterprise CI/CD at 1000+ service scale.**

**When configured properly**:
- ✅ Reusable workflows (not duplicated code)
- ✅ OIDC (not manual secrets)
- ✅ Terraform (not manual UI)
- ✅ Proper governance (Required Workflows + CODEOWNERS)

**The numbers**:
- GitHub-Proper: $2.1M over 5 years
- **GitHub + Argo CD: $1.8M** (best value)
- Harness: $5.5M over 5 years (3× more expensive)

**The gap is NOT operational efficiency.**

**The gap is:**
1. **Configuration expertise** (reusable workflows vs duplication)
2. **License understanding** (200 users vs 1000 licenses)
3. **Open source awareness** (Argo CD exists and is free)
4. **Vendor marketing** (Harness claims you need them)

**For most companies**: GitHub + Argo CD is the optimal choice

**Vendor platforms are expensive convenience**, not technical necessity

---

## Next Steps

### To Evaluate Further:

1. **See the demo**: [Follow step-by-step walkthrough](DEMO.md)
   - Fork the repo
   - Watch workflows run
   - Experience the gaps firsthand

2. **Review this implementation**:
   - All workflows are live and running
   - All GitHub Enterprise features configured
   - Complete working example at https://github.com/gregkroon/githubexample

3. **Pilot comparison**:
   - Pick 10 services
   - Implement both approaches
   - Measure actual TCO and developer experience

4. **Run cost analysis**:
   - Calculate your actual headcount costs
   - Factor in custom engineering time
   - Compare to platform licensing

---

## Questions?

**All claims in this summary are verified with citations**: See [DEMO.md](DEMO.md) for hands-on evidence.

**See it running live**: https://github.com/gregkroon/githubexample/actions

---

**[← Back to README](../README.md)** | **[Try the Demo](DEMO.md)**
