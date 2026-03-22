# Executive Summary: GitHub Actions vs Harness CD

**For**: Engineering leadership, CFOs, decision-makers
**Read Time**: 3 minutes

---

## The Verdict

**For heterogeneous enterprises (95% of companies): GitHub Actions costs MORE and delivers FAR LESS than Harness.**

| | GitHub Actions | Harness CD |
|---|---|---|
| **5-Year Cost** | $6.0M | $5.5M |
| **Platform Team** | 4.5 FTE (firefighting) | 2 FTE (building features) |
| **Custom Code** | 2,500+ lines | 0 lines |
| **Rollback** | Redeploy (5-15 min) | One-click (< 1 min) |
| **Verification** | None | ML-based auto-rollback |
| **Security Bypass** | One architectural gap | None |

**Harness is $420k cheaper with 10× the capability**

**[See detailed cost workings →](COST_ANALYSIS.md)**

---

## The 5 Critical Gaps

1. **No Rollback**: Redeploy takes 5-15 min vs Harness < 1 min. One outage costs millions.

2. **No Verification**: GitHub deploys blind. Harness has ML-based anomaly detection with auto-rollback.

3. **Heterogeneous = Custom Code**: Must maintain 2,500+ lines across K8s, VMs, ECS, Lambda, on-prem. Harness: 0 lines, vendor-maintained.

4. **No Orchestration**: Can't enforce multi-service deployment order. Must build custom orchestrator (12 weeks). Harness: built-in.

5. **Parallel Execution Gap**: GitHub Enterprise Required Workflows prevent MOST security bypasses (skip scan, continue-on-error, bypass branch protection) BUT workflows run in parallel—deployment can complete before security scan finishes. Harness: sequential stages architecturally block deployment until security passes.

**[See security analysis →](SECURITY_ENFORCEMENT.md)**

---

## Cost Summary (5 Years)

| | GitHub Actions | Harness CD |
|---|---|---|
| Licenses | $250k | $3,230k |
| Custom development | $800k | $300k (Year 1) |
| Platform team (FTE) | $4,500k (4.5) | $2,000k (2) |
| Hidden costs | $400k | $0 |
| **TOTAL** | **$5,950k** | **$5,530k** |

**Harness saves $420k (7%)**

**[See detailed breakdown with 16 cited sources →](COST_ANALYSIS.md)**

---

## Decision Framework

### Use GitHub Actions (CI + CD) ONLY If:
- ✅ < 50 services
- ✅ 100% Kubernetes in single cloud
- ✅ Can accept no rollback/verification
- ✅ Unlimited platform engineering time
- ⚠️ One multi-cloud mandate = complete rebuild

**Cost**: ~$1-2M over 5 years

---

### Use Harness CD If:
- ✅ 200+ services
- ✅ ANY heterogeneity (K8s + VMs/ECS/Lambda/on-prem)
- ✅ Need rollback capability
- ✅ Need deployment verification
- ✅ Limited platform capacity
- ✅ Governance requirements

**Cost**: ~$5.5-6M over 5 years
**Benefit**: $420k cheaper than GitHub + 10× capability

---

## By Company Scale

**< 50 Services, K8s-only**:
GitHub might work
**But**: Missing rollback, verification, orchestration

**50-200 Services, Mixed Platforms**:
Harness—GitHub pain growing exponentially

**200+ Services, Multi-Platform**:
Harness only—GitHub unmanageable

**[See multi-platform analysis →](../HETEROGENEOUS_REALITY.md)**

---

## What Works, What Doesn't

**✅ GitHub Actions excels at CI**:
Build, test, security scanning—keep using it

**❌ GitHub Actions fails at CD**:
Deployment, rollback, verification, orchestration

**✅ Solution**:
GitHub for CI + Harness for CD (standard enterprise pattern)

---

## The Bottom Line

**Stop wasting engineering time building what Harness already has.**

For 95% of enterprises with heterogeneous infrastructure:
- Harness is **$420k cheaper**
- Harness is **36 weeks faster** to production
- Harness is **10× more capable** (rollback, verification, orchestration)
- Harness requires **2.5 fewer FTE**

**The choice is obvious.**

---

## Next Steps

### 1. Measure Your Pain
- How many FTE on deployment infrastructure?
- Current incident MTTR (rollback time)?
- Cost of 1 hour outage?

### 2. Schedule Harness POC
- YOUR deployment targets (K8s, VMs, Lambda, on-prem)
- See one-click rollback
- Watch ML verification prevent bad deploys

### 3. Read Supporting Docs
- **[COST_ANALYSIS.md](COST_ANALYSIS.md)** - Full cost breakdown, 16 sources
- **[DEMO.md](DEMO.md)** - Hands-on walkthrough of 5 gaps
- **[SECURITY_ENFORCEMENT.md](SECURITY_ENFORCEMENT.md)** - What GitHub Enterprise can/cannot prevent
- **[HETEROGENEOUS_REALITY.md](../HETEROGENEOUS_REALITY.md)** - Why heterogeneity changes everything

### 4. See Live Evidence
https://github.com/gregkroon/githubexperiment/actions

---

**[← Back to README](../README.md)** | **[See the proof →](DEMO.md)** | **[Audit the math →](COST_ANALYSIS.md)**
