# Quick Start Demo: GitHub vs Harness at Enterprise Scale

**30-Minute Demonstration** showing why GitHub-native CI/CD struggles at 1000+ repos vs purpose-built platforms like Harness.

> 🚀 **This is REAL** - All workflows actually run. Fork this repo and watch them execute.

---

## The Setup (2 min)

**Scenario**: Your company has 1000 microservices. You need enterprise-grade CI/CD with:
- Automated security scanning
- Approval gates for production
- One-click rollbacks
- Centralized governance

**Question**: Can you build this with GitHub-native tooling?

**Answer**: Yes, but at what cost?

---

## Part 1: The Working Example (10 min)

### What You're Looking At

This repository contains **3 real microservices** with **complete CI/CD pipelines**:

| Service | Language | CI Workflow | CD Workflow | Status |
|---------|----------|-------------|-------------|--------|
| **user-service** | Node.js | ✅ Builds, scans, signs | ✅ Deploys to Kind | **RUNS ON EVERY PUSH** |
| **payment-service** | Go | ✅ Builds, scans, signs | ✅ Deploys to Kind | **RUNS ON EVERY PUSH** |
| **notification-service** | Python | ✅ Builds, scans, signs | ✅ Deploys to Kind | **RUNS ON EVERY PUSH** |

### See It Run

1. **Fork this repository**
2. **Make a change** to `services/user-service/src/index.js`
3. **Push to main**
4. **Watch**: `.github/workflows/ci-user-service.yml` runs automatically

**What happens**:
```
t=0:   Push detected → CI workflow starts
t=1m:  Tests pass → Build Docker image
t=2m:  Security scan (Trivy + Grype)
t=3m:  SBOM generation (Syft)
t=4m:  Image signing (Cosign)
t=5m:  Policy validation (Conftest)
t=6m:  CD workflow starts
t=7m:  Deploy to Kind cluster
t=8m:  Smoke tests run
t=9m:  ✅ Deployment complete
```

### What's Impressive

✅ **17 security gates** enforced
✅ **Image signing** with Cosign
✅ **SBOM generation** for compliance
✅ **Policy validation** with OPA
✅ **Real Kubernetes deployment** to Kind
✅ **Smoke tests** verify health

**This proves GitHub CAN do enterprise CI/CD.**

---

## Part 2: The Problem at Scale (8 min)

### Now Scale to 1000 Repos

With 3 services, it's manageable. With 1000 services:

| What You Need | GitHub-Native | Operational Burden |
|---------------|---------------|-------------------|
| **Workflows** | 1000 files (one per repo) | Update 1000 files for any change |
| **Environments** | 3000 configs (3 per repo) | No centralized management |
| **Security scanning** | In each workflow | Developers can bypass |
| **Deployment gates** | Custom service to build | 4 weeks engineering |
| **DORA metrics** | Custom service to build | 3 weeks engineering |
| **Rollback** | Manual kubectl commands | No one-click rollback |

### The Governance Gap

**Problem**: Even with GitHub Enterprise, developers control workflow files.

**Demonstration**: `.github/CODEOWNERS`

```bash
# Platform team MUST approve workflow changes
/.github/workflows/ @platform-team @security-team
```

**What this provides**:
- ✅ Requires platform team approval for workflow changes
- ✅ Blocks obvious bypasses (commented out jobs)

**What this DOESN'T prevent**:
```yaml
# ❌ Subtle bypass that passes code review
jobs:
  security-scan:
    continue-on-error: true  # ← Reviewer might miss this
    steps:
      - uses: trivy-action@master
        with:
          exit-code: 0  # ← Security never fails
```

**At 1000 repos**: Platform team reviews 10-20 PRs/day × 1000 repos = unsustainable.

### The Architectural Gap

**Even with GitHub Enterprise ($400k/year) and ALL features enabled:**

**Organization Rulesets** (centralized policies):
- ✅ Requires status checks from Required Workflows
- ✅ Enforces code owner approval
- ✅ Applies to all 1000 repos

**Required Workflows** (org-wide security scanning):
- ✅ Runs automatically on ALL repos
- ✅ Developers cannot disable
- ✅ Scans for vulnerabilities

**The Problem**: Parallel Execution

```
t=0:   Developer pushes code
t=0:   Required workflow starts (scans filesystem)
t=0:   Developer's workflow starts (builds image, deploys)
t=3m:  Developer's workflow DEPLOYS ✅
t=5m:  Required workflow finds CVE ❌

Result: Vulnerable code ALREADY IN PRODUCTION
```

**Why**: GitHub Actions has no cross-workflow dependency mechanism. Both workflows run independently and in parallel.

**See it yourself**:
- `platform/.github/workflows/required-security-scan.yml` - Required workflow (scans filesystem)
- `.github/workflows/ci-user-service.yml` - Developer's workflow (builds image, deploys)

Both triggered by same push event → run in parallel → no way to enforce order.

---

## Part 3: GitHub Enterprise Features (5 min)

### We've Configured Everything GitHub Offers

**See the actual configurations**:

| Feature | Configuration File | What It Does | Limitation |
|---------|-------------------|--------------|-----------|
| **CODEOWNERS** | `.github/CODEOWNERS` | Requires platform team approval | Manual review, subtle bypasses |
| **Organization Rulesets** | `platform/rulesets/organization-production-ruleset.json` | Centralized policies | Can't prevent parallel execution |
| **Required Workflows** | `platform/.github/workflows/required-security-scan.yml` | Org-wide security scanning | Scans filesystem, not images |
| **Branch Protection** | Configured via Terraform | Per-repo enforcement | Distributed configuration |

**Full setup guide**: `docs/GITHUB_ENTERPRISE_SETUP.md` (500+ lines showing EXACTLY how to configure everything)

**Time to deploy**: 20-30 hours
**Ongoing maintenance**: 8-12 hours/week
**Annual cost**: ~$400,000 (GitHub Enterprise Cloud for 1000 users)

**What's STILL missing**:
- ❌ Cannot scan Docker images before deployment
- ❌ Cannot enforce deployment order (sequential stages)
- ❌ Cannot block deployment if security fails
- ❌ Developers still control deployment logic
- ❌ 3,000 environment configs (distributed, no centralization)

---

## Part 4: Compare to Harness (5 min)

### The Harness Approach

**One template, applies to ALL 1000 services**:

```yaml
# Lives OUTSIDE developer repos
# Developers reference it, cannot modify
template:
  name: Production Deployment
  stages:
    - stage:
        name: Build
        spec:
          buildAndPush: docker build ...

    - stage:
        name: Security
        dependsOn: [Build]  # ← Runs AFTER build
        locked: true        # ← Developers CANNOT modify
        spec:
          imageScan:
            tool: Trivy
            scanImage: true  # ← Scans actual Docker image
            failOnCVE: true
            waitForResults: true  # ← Blocks next stage

    - stage:
        name: Production
        dependsOn: [Security]  # ← Cannot run until security passes
        locked: true
        spec:
          approval:
            required: true
            approvers: [platform-team]
          deployment:
            strategy: canary
            steps: [25%, 50%, 100%]
          verification:
            ml: true  # ← ML-based anomaly detection
          rollback:
            automatic: true
```

### Key Differences

| Capability | GitHub-Native | Harness |
|------------|---------------|---------|
| **Template location** | In each repo (1000 files) | Centralized (1 template) |
| **Developer modification** | Can edit workflow | Cannot modify locked stages |
| **Execution model** | Parallel (workflows race) | Sequential (stages wait) |
| **Image scanning** | Filesystem only | Actual Docker image |
| **Deployment blocking** | Cannot enforce | Architecturally enforced |
| **Configuration** | 3000 environment configs | Centralized template |
| **Rollback** | Manual kubectl | One-click automated |
| **Verification** | Custom service (build yourself) | Built-in ML verification |
| **Setup time** | 17 weeks custom engineering | 2-4 weeks configuration |
| **Operational burden** | 2-4 FTE | 0.5-1 FTE |

### Cost Comparison (5 years)

**GitHub-Native with Enterprise**:
```
GitHub Enterprise: $400k/year × 5 = $2,000k
Custom services: $200k build + $400k maintenance = $600k
Platform engineers: $600k/year × 5 = $3,000k
──────────────────────────────────────────────
Total: $5,600,000
```

**Hybrid (GitHub CI + Harness CD)**:
```
GitHub Team (CI only): $92k/year × 5 = $460k
Harness CD: $400k/year × 5 = $2,000k
Platform engineers: $250k/year × 5 = $1,250k
──────────────────────────────────────────────
Total: $3,710,000

Savings: $1,890,000 (34%)
```

---

## The Bottom Line

### GitHub-Native CAN Work

✅ This repo proves it's technically possible
✅ All 3 services have real CI/CD
✅ Security scanning works
✅ Image signing works
✅ Deployment works

### But At What Cost?

At 1000+ repos:
- ❌ **24 tools** to integrate and maintain
- ❌ **6 custom services** to build (17 weeks)
- ❌ **3,000 configurations** (no centralization)
- ❌ **2-4 FTE** just to operate
- ❌ **$5.6M** over 5 years
- ❌ **Parallel execution gap** (cannot enforce sequential stages)
- ❌ **Developer bypass risk** (workflow files in repos)

### The Harness Alternative

✅ **8 tools** (integrated out-of-box)
✅ **0 custom services** (all built-in)
✅ **Centralized templates** (one config for all)
✅ **0.5-1 FTE** to operate
✅ **$3.7M** over 5 years
✅ **Sequential enforcement** (architectural, not policy-based)
✅ **Locked templates** (developers cannot bypass)

---

## Recommendation

### For < 50 Repositories
✅ **GitHub-native is viable** - Operational burden is manageable

### For 50-500 Repositories
⚠️ **Evaluate based on resources** - Consider custom engineering vs platform cost

### For 1000+ Repositories
✅ **Hybrid approach strongly recommended**:
- ✅ **CI**: GitHub Actions (excellent, keep using it)
- ✅ **CD**: Harness or similar (purpose-built for scale)

**Why?**
- Lower total cost ($1.9M savings)
- Less operational burden (0.5-1 FTE vs 2-4 FTE)
- Faster time-to-value (2-4 weeks vs 17 weeks)
- Architectural enforcement (not policy-based)
- No developer bypass risk

---

## Try It Yourself

### 1. See the Real Workflows Run (5 min)
```bash
# Fork this repo
gh repo fork yourusername/githubexperiment

# Make a change
echo "// Update" >> services/user-service/src/index.js
git add . && git commit -m "Test workflow" && git push

# Watch the workflow run
gh run watch
```

### 2. Explore GitHub Enterprise Configs (10 min)
- `.github/CODEOWNERS` - See platform team approval requirements
- `platform/rulesets/organization-production-ruleset.json` - See centralized policies
- `platform/.github/workflows/required-security-scan.yml` - See org-wide security scanning
- `docs/GITHUB_ENTERPRISE_SETUP.md` - See complete setup guide

### 3. Understand the Gaps (15 min)
- `docs/DEVELOPER_VS_PLATFORM.md` - See how developers can bypass security
- `docs/GITHUB_GAPS_REAL.md` - See 7 obvious shortcomings vs Harness
- `docs/WHY_GITHUB_TEMPLATES_FAIL.md` - See why GitHub "templates" ≠ Harness templates

### 4. See the Full Analysis (30 min)
- `docs/EXECUTIVE_SUMMARY.md` - Complete analysis and recommendations

---

## The Brutal Truth

**You're not paying Harness for features.**

**You're paying them to NOT build and maintain 6 custom services.**

At 1000+ repos, the custom engineering costs exceed the platform cost.

**Use the right tool for the job.**

---

**[← Back to README](../README.md)** | **[Executive Summary](EXECUTIVE_SUMMARY.md)** | **[GitHub Enterprise Setup](GITHUB_ENTERPRISE_SETUP.md)**
