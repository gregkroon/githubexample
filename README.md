# Can You Build Enterprise CI/CD with GitHub?

**Yes. But it costs $2.05M more over 5 years than using Harness.**

This repository **proves it** with a complete working implementation that runs on every push.

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

### 1. Try It Yourself (30 min)

**[→ Follow the Step-by-Step Demo](docs/DEMO.md)**

**You'll**:
- Watch real workflows execute
- Fork and run your own
- See what breaks at 1000 repos
- Try to bypass security (it's easy)
- Understand the parallel execution gap
- Compare to Harness

**Best for**: Anyone who wants hands-on proof

---

### 2. Read the Business Case (10 min)

**[→ Read the Executive Summary](docs/EXECUTIVE_SUMMARY.md)**

**You'll learn**:
- What we built and what it proves
- The 6 critical gaps at scale
- Cost analysis ($5.6M vs $3.7M over 5 years)
- Recommendations by repository count
- Risk analysis and decision framework

**Best for**: Leadership making the decision

---

## The Bottom Line

### What Works ✅

**GitHub Actions for CI is excellent**:
- Automated builds and tests
- Comprehensive security scanning
- Good developer experience
- **Keep using it**

---

### What Breaks at 1000+ Repos ❌

**1. Configuration Sprawl**
- 1,000 workflow files to maintain
- 3,000 environment configurations
- No centralized management

**2. Developers Control Workflows**
- Workflow files live in developer repos
- Can bypass security with `continue-on-error: true`
- Manual code review doesn't scale

**3. Parallel Execution (THE CRITICAL GAP)**
```
t=0:   Platform security scan starts
t=0:   Developer workflow starts
t=3m:  Developer deploys to production ✅
t=5m:  Security scan finds critical CVE ❌

Result: Already deployed
```
**No way to enforce "deploy ONLY IF security passes"**

**4. SBOM Attestation Complexity**
- Generate SBOM: 1 line (easy)
- Validate SBOM: 90 lines (custom code)
- Sign attestation: 40 lines (Cosign expertise)
- Verify at deployment: 80 lines (2 environments)
- **Total: 210 lines per service**
- **× 1000 services = 210,000 lines**

**5. Must Build 6 Custom Services**
- Deployment gates (4 weeks)
- DORA metrics (3 weeks)
- Policy validation (3 weeks)
- Multi-service orchestrator (6 weeks)
- Deployment verifier (4 weeks)
- Configuration service (3 weeks)
- **Total: 23 weeks + 2 FTE ongoing**

**6. Missing Capabilities**
- ❌ One-click rollback
- ❌ Deployment verification
- ❌ Centralized configuration
- ❌ Template locking
- ❌ Automated SBOM policy enforcement

**7. Operational Burden**
- 2-4 platform engineers full-time
- 16-24 hrs/week handling failures
- SBOM policy updates across 1000 repos

---

### The Cost

| | GitHub-Native | GitHub CI + Harness CD |
|---|---------------|------------------------|
| **Year 1** | $1,280,000 | $892,000 |
| **Years 2-5 (each)** | $1,120,000 | $742,000 |
| **5-Year Total** | **$5,760,000** | **$3,710,000** |
| **Savings** | | **$2,050,000 (36%)** |

---

### The Recommendation

**< 50 repos**: ✅ GitHub-native works

**50-500 repos**: ⚠️ Depends on your resources

**1000+ repos**: ✅ Hybrid approach
- **CI**: GitHub Actions (excellent, keep it)
- **CD**: Harness (purpose-built for scale)

**Why**:
- $2.05M less expensive
- 75% less operational burden
- Better governance (locked templates)
- Sequential enforcement (security before deploy)
- SBOM attestation built-in (vs 210k lines of code)

---

## The Key Difference

### GitHub: Parallel Execution
```
Workflows run independently
↓
Cannot enforce dependencies
↓
Deploy happens before security scan completes
↓
Vulnerable code reaches production
```

### Harness: Sequential Stages
```
Security stage must pass
↓
THEN deploy stage runs
↓
Architecturally impossible to deploy without security passing
```

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

## What This Repository Proves

✅ **GitHub CAN do enterprise CI/CD**
- All 3 services have working pipelines
- Security scanning works
- Image signing works
- Deployment works

❌ **But at 1000+ repos, it's more expensive**
- Must write custom enforcement (210k+ lines, 32 weeks)
- Requires 2-4 FTE to operate
- Costs $2.05M more over 5 years
- Parallel execution gap cannot be solved

**The gap is operational efficiency, not functionality.**

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

## The Brutal Truth

**GitHub is not bad.**

**We're exposing what it truly costs to make it work at enterprise scale.**

Sometimes the hardest thing to admit is: **someone else solved this problem better.**

---

## Quick Links

- **[Try the Demo](docs/DEMO.md)** - 35-minute hands-on walkthrough showing what works and what breaks
- **[Read Executive Summary](docs/EXECUTIVE_SUMMARY.md)** - 10-minute business case with cost analysis
- **[Watch Workflows Run](https://github.com/gregkroon/githubexample/actions)** - See it live

---

**Use the right tool for the job.**
