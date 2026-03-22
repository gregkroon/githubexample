# Executive Summary: Why GitHub Actions Fails At Enterprise CD

**For**: Engineering leadership, CFOs, decision-makers
**Time**: 3 minutes

---

## The Verdict

**For heterogeneous enterprises (95% of companies): GitHub Actions costs MORE and delivers FAR LESS than Harness.**

**The reality**:
- GitHub Actions: $6.2M over 5 years, 4.5 FTE, 2,500+ lines custom code, NO rollback
- Harness CD: $6.0M over 5 years, 2 FTE, 0 custom code, one-click rollback
- **Harness is $200k CHEAPER with 10× the capability**

---

## The 5 Critical Gaps

1. **Configuration Sprawl**: 1000 repos × 3 environments = 3,000 manual configurations vs Harness's 1 centralized config
2. **No Security Enforcement**: Developers can bypass security gates in workflows. GitHub Enterprise can't prevent this architecturally
3. **Parallel Execution Trap**: Required workflows run SIMULTANEOUSLY with deploy workflows—vulnerable code already in production before security scan completes
4. **No Rollback**: GitHub redeploys (5-15 min MTTR). Harness: one-click (< 1 min). One outage costs millions
5. **Custom Code Everywhere**: Must build 7 services (SBOM enforcement, deployment gates, orchestration, verification, DORA metrics, etc). 32 weeks build time, 30-48 hrs/week ongoing

---

## Cost Summary (5 Years)

**See detailed breakdown in [COST_ANALYSIS.md](COST_ANALYSIS.md)**

| Metric | GitHub Actions | Harness CD |
|--------|---|---|
| **Total cost** | $6.2M | $6.0M |
| **Platform team** | 4.5 FTE | 2 FTE |
| **Custom code** | 2,500+ lines | 0 lines |
| **Setup time** | 52 weeks | 16 weeks |
| **Rollback** | 5-15 min (redeploy) | <1 min (instant) |
| **Deployment verification** | None | ML-based auto-rollback |

---

## Decision Framework

### GitHub Actions Works ONLY If:
- < 50 services
- 100% Kubernetes, single cloud
- No rollback requirement
- Unlimited platform engineering time
- Prepared for complete rebuild when adding ANY other platform

### Use Harness If:
- 50+ services
- ANY platform heterogeneity (K8s + VMs, ECS, Lambda, on-prem, etc)
- Need rollback during incidents
- Value platform team productivity
- Multiple clouds or governance requirements

---

## By Scale

**< 50 Services, 100% K8s**: GitHub might work (with caveats—missing rollback/verification)

**50-200 Services, Mixed Platforms**: Harness—GitHub pain is growing exponentially

**200-500 Services, Enterprise**: Harness is mandatory—GitHub burnout inevitable

**500-1000+ Services, Multi-cloud**: Harness only—GitHub is unmanageable for heterogeneous infrastructure

---

## What Works, What Doesn't

**GitHub excels at CI**: Build, test, security scanning. Keep using it.

**GitHub fails at CD**: Deployment, rollback, verification, orchestration, multi-platform support.

**Solution**: GitHub for CI + Harness for CD (standard enterprise pattern)

---

## Key Takeaway

Stop wasting engineering resources on unmaintainable custom deployment code.

For 95% of enterprises with heterogeneous infrastructure:
- Harness is CHEAPER ($200k over 5 years)
- Harness is FASTER to production (36 weeks faster)
- Harness is 10× more capable (rollback, verification, orchestration)

**The choice is obvious.**

---

## Next Steps

1. **Quick win**: Measure your current deployment pain
   - How many FTE on deployment infrastructure today?
   - What's your incident MTTR (rollback time)?
   - Estimate cost of 1 hour outage

2. **Schedule Harness POC** for YOUR deployment targets (K8s, VMs, Lambda, on-prem)
   - See one-click rollback in action
   - Watch ML verification prevent bad deployments

3. **Reference documents**:
   - [COST_ANALYSIS.md](COST_ANALYSIS.md)—Full cost breakdown
   - [HETEROGENEOUS_REALITY.md](../HETEROGENEOUS_REALITY.md)—Why heterogeneity breaks GitHub
   - [DEMO.md](DEMO.md)—See failures in real workflows

4. **Live evidence**: https://github.com/gregkroon/githubexperiment/actions

---

**[← Back to README](../README.md)** | **[Full Analysis](HETEROGENEOUS_REALITY.md)**
