# GitHub Actions vs Harness CD: The Frankenstein Architecture Tax

**The brutal truth about scaling GitHub Actions for enterprise Continuous Delivery**

---

## The Verdict

GitHub Actions is excellent for CI. Using it for enterprise CD creates an expensive, fragmented Frankenstein architecture.

| Metric | GitHub Actions CD | Harness CD |
|--------|-------------------|------------|
| **Architecture** | GHA + Terraform + ArgoCD + Bash + Glue Code | Single Control Plane |
| **Deployment State** | None (stateless runners) | Persistent, queryable |
| **Rollback** | Manual (revert → redeploy → wait 15 min) | Automatic (< 1 minute) |
| **Verification** | Deploy and pray | Automated health checks + ML anomaly detection |
| **Multi-Service Orchestration** | Custom coordination scripts | Native pipeline dependencies |
| **Governance** | 3,000 workflow files to audit | Centralized policies + RBAC |
| **Platform Team Burden** | 40% time on deployment glue code | 10% time on configuration |
| **5-Year TCO** | $8.2M | $5.5M |

**Result**: Harness saves $2.7M (33%) and eliminates architectural sprawl.

---

## The Core Problem: The Frankenstein Architecture

### What Enterprises Actually Build

When you choose GitHub Actions for CD at scale, you don't just use GHA. You build a Frankenstein:

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions (CI only)                               │
│  ├─ Build, test, scan ✅                                │
│  └─ Deploy? ❌ Stateless, no rollback, no verification │
└─────────────────────────────────────────────────────────┘
                          ↓
           "We need deployment capabilities"
                          ↓
┌─────────────────────────────────────────────────────────┐
│  The Frankenstein Stack                                 │
│  ├─ GitHub Actions (build + test)                       │
│  ├─ Terraform (infrastructure)                          │
│  ├─ ArgoCD (Kubernetes deployments)                     │
│  ├─ Custom Bash scripts (VM deployments)                │
│  ├─ AWS CLI scripts (Lambda/ECS deployments)            │
│  ├─ Liquibase/Flyway (database migrations)              │
│  ├─ Custom state tracker (what's deployed where?)       │
│  ├─ Custom rollback scripts (emergency recovery)        │
│  ├─ Custom health check orchestrator                    │
│  └─ Custom deployment coordinator (service dependencies)│
└─────────────────────────────────────────────────────────┘
```

**This is what "GitHub Actions CD" actually means at enterprise scale.**

### The Hidden Cost: Glue Code Maintenance

Your platform engineering team becomes a full-time **glue code maintenance team**:

| Activity | Time Spent | Annual Cost (per engineer) |
|----------|------------|----------------------------|
| Upgrading GHA runners | 5% | $10k |
| Fixing ArgoCD sync failures | 8% | $16k |
| Debugging Terraform state drift | 10% | $20k |
| Maintaining custom deployment scripts | 12% | $24k |
| Coordinating multi-service releases | 15% | $30k |
| Investigating "what's deployed where?" | 10% | $20k |
| Manual rollback coordination | 8% | $16k |
| Standardizing across 1,000 repos | 12% | $24k |
| **TOTAL** | **80%** | **$160k per engineer** |

**For a 6-person platform team**: $960k/year maintaining deployment glue code instead of building features.

---

## The Day-2 Nightmare: Stateless Runners

### The Fundamental Problem

GitHub Actions runners are **stateless ephemeral VMs**. They:
- ✅ Build code
- ✅ Run tests
- ✅ Push artifacts
- ❌ **Have no memory of what they deployed**
- ❌ **Can't track deployment history**
- ❌ **Can't automatically verify deployments**
- ❌ **Can't orchestrate rollbacks**

**This is why you need ArgoCD + custom scripts + state trackers.**

### Real-World Scenario: Production Breaks at 5:30pm Friday

**With GitHub Actions + ArgoCD + Terraform**:

```bash
# 1. Discover the problem (5-10 min)
# - Which service is broken?
# - What version is deployed?
# - Check GHA logs (deleted after 90 days)
# - Check ArgoCD UI (only shows current state)
# - SSH into prod and inspect manually

# 2. Identify the bad deployment (5-10 min)
# - Was it the API? Database? Lambda?
# - Find the corresponding GitHub workflow run
# - Correlate with ArgoCD sync time
# - Check Terraform state

# 3. Coordinate rollback (15-20 min)
# - Revert database migration (Flyway undo)
# - Revert API deployment (ArgoCD rollback OR git revert + redeploy)
# - Revert Lambda (AWS CLI commands)
# - Revert frontend (S3 sync previous version)
# - Hope you didn't miss a dependency

# TOTAL: 25-40 minutes
```

**With Harness**:

```yaml
# 1. Platform detects anomaly automatically (< 1 min)
# - Error rate spike detected
# - Deployment marked as failed

# 2. One-click rollback (< 1 min)
# - Rolls back entire pipeline: DB → API → Lambda → Frontend
# - Atomic, coordinated, automatic

# TOTAL: < 2 minutes
```

**Impact**:
- GitHub stack: 30 minutes × $5M/hour = **$2.5M revenue loss**
- Harness: 2 minutes × $5M/hour = **$167k revenue loss**
- **Savings per incident: $2.3M**

---

## The Governance Nightmare

### The Problem: Thousands of Disparate Workflow Files

**Enterprise reality**:
- 1,000 microservices
- 3 workflows per service (dev, staging, prod)
- **3,000 workflow files to govern**

### What This Means

**Configuration Drift**:
- Team A uses `actions/checkout@v3`
- Team B uses `actions/checkout@v4`
- Team C uses `actions/checkout@2541b1294d2704b0964813337f33b291d3f8596b` (pinned SHA)
- **No way to enforce standardization across 3,000 files**

**Security Policy Enforcement**:
```yaml
# You WANT this enforced everywhere:
- Deploy to prod requires manual approval
- Cannot deploy during blackout windows (Fri 4pm - Mon 8am)
- Must wait 1 hour in staging before prod
- Cannot deploy if incidents are active

# Reality with GHA:
- Must implement in 3,000 separate workflow files
- Teams copy-paste different versions
- Policies drift over time
- Compliance audits become nightmares
```

**Audit Requirements**:
- "Show me all deployments to production last quarter"
- With GHA: Query 3,000 repos, parse workflow logs, correlate with git commits
- With Harness: One API query

### The Harness Approach

```yaml
# Centralized deployment policy (applies to ALL 1,000 services)
policies:
  - name: Production Protection
    enforcement: HARD
    rules:
      - require_manual_approval: true
      - blackout_windows: ["Fri 16:00 - Mon 08:00"]
      - min_soak_time_staging: 1h
      - block_if_incidents: true

# Services just reference the policy
pipeline:
  stages:
    - environment: production
      policy: Production Protection  # ← Automatic enforcement
```

**Result**: One policy file instead of 3,000 workflow files to maintain.

---

## The Real TCO Calculation

### GitHub Actions "CD" Stack (5 Years)

```
Platform Engineering Team (6 engineers × $200k × 5 years)
  └─ 80% time on deployment glue maintenance        = $4.8M
  └─ 20% time on feature work                       = $1.2M

Custom Tooling Development
  ├─ State tracker service (8 weeks)                = $120k
  ├─ Rollback coordinator (8 weeks)                 = $120k
  ├─ Multi-service orchestrator (12 weeks)          = $180k
  ├─ Health check automation (6 weeks)              = $90k
  └─ Deployment policy enforcer (10 weeks)          = $150k
                                          Subtotal  = $660k

Infrastructure
  ├─ GitHub Enterprise                              = $250k
  ├─ ArgoCD (self-hosted)                           = $150k
  ├─ Terraform Cloud                                = $120k
  └─ Additional monitoring/observability            = $200k
                                          Subtotal  = $720k

Incident Impact (2 major incidents/year × 5 years)
  └─ 10 incidents × 30 min recovery × $5M/hr        = $2.5M

────────────────────────────────────────────────────────
TOTAL (5 years)                                     = $8.9M
```

### Harness CD (5 Years)

```
Platform Engineering Team (2 engineers × $200k × 5 years)
  └─ 10% time on Harness configuration              = $200k
  └─ 90% time on feature work                       = $1.8M

Harness Licenses
  └─ Enterprise plan: 1,000 services                = $3.0M

Infrastructure
  ├─ GitHub (CI only)                               = $150k
  └─ Reduced observability needs                    = $100k
                                          Subtotal  = $250k

Incident Impact (2 major incidents/year × 5 years)
  └─ 10 incidents × 2 min recovery × $5M/hr         = $167k

────────────────────────────────────────────────────────
TOTAL (5 years)                                     = $5.6M
```

**Savings: $3.3M (37%)**

**More importantly**: 4 engineers freed to build features instead of maintaining glue code.

---

## When to Use What

### ✅ Use GitHub Actions for CI + CD If:

- **< 50 services** (Frankenstein architecture hasn't metastasized yet)
- **100% Kubernetes on a single cluster** (ArgoCD works well)
- **Deployment rollback < 5/year** (manual recovery is tolerable)
- **Platform team has unlimited capacity** (maintaining glue code is free)
- **No compliance requirements** (audits are optional)

**Risk**: First multi-cloud mandate, database migration, or compliance requirement = rebuild everything.

---

### ✅ Use Harness CD If:

- **200+ services** (Frankenstein architecture becomes unmaintainable)
- **Heterogeneous infrastructure** (Kubernetes + VMs + Lambda + databases + on-prem)
- **Need < 1 minute rollback** (revenue impact of downtime is high)
- **Limited platform engineering capacity** (can't afford 6 people on glue code)
- **Compliance requirements** (SOC2, PCI-DSS, HIPAA need audit trails)
- **Multi-team organization** (need centralized governance)

**Benefit**: $3.3M cheaper + eliminate architectural sprawl + free 4 engineers for feature work.

---

## The Honest Conclusion

**GitHub Actions is the best CI platform.** Use it for build, test, and scan.

**GitHub Actions is not a CD platform.** Using it for enterprise CD forces you to build a Frankenstein architecture of GHA + Terraform + ArgoCD + custom glue code.

**The real cost isn't the tools.** It's the 6-person platform team spending 80% of their time maintaining deployment glue instead of building features.

**Harness isn't "better than GitHub Actions."** It's purpose-built for a completely different problem: enterprise deployment orchestration, verification, and governance.

### The Strategic Question

Do you want your platform team:
- **Maintaining deployment glue code** (GitHub Actions CD)
- **Building developer productivity features** (Harness CD)

One production outage pays for 1.5 years of Harness.

---

## Live Proof

This repository demonstrates real GitHub Actions CI/CD pipelines:

```bash
# Fork and watch the workflows run
gh repo fork gregkroon/githubexperiment
cd githubexperiment
echo "test" >> README.md && git commit -am "trigger" && git push
gh run watch
```

**Then experience the pain**:
1. ❌ Deploy something broken and try to rollback (you'll manually revert + redeploy)
2. ❌ Try to see deployment history (you'll grep through logs)
3. ❌ Try to coordinate a multi-service deploy (you'll write custom scripts)

**[See detailed technical walkthrough →](docs/DEMO.md)**

---

## Essential Reading

| Document | What It Proves | Time |
|----------|----------------|------|
| **README.md** | Why the Frankenstein architecture is expensive | 8 min |
| **[DEMO.md](docs/DEMO.md)** | Hands-on proof of GitHub Actions CD gaps | 15 min |
| **[GITHUB_WORKAROUNDS.md](docs/GITHUB_WORKAROUNDS.md)** | Exact code to build missing capabilities | 20 min |

---

## License

MIT - Use this to make informed platform decisions
