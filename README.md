# GitHub Actions vs Harness CD: The Enterprise Reality

**Can GitHub Actions replace a purpose-built CD platform for heterogeneous enterprises?**

**No. GitHub costs MORE and delivers LESS.**

---

## The Verdict

**For heterogeneous enterprises** (1000+ services, multi-cloud, VMs, serverless, on-prem):

| | GitHub Actions | Harness CD |
|---|---|---|
| **5-Year Cost** | $6.5M | $6.0M |
| **Platform Team** | 4.5 FTE (firefighting) | 2 FTE (building features) |
| **Custom Code** | 2,500+ lines | 0 lines |
| **Rollback** | ❌ Redeploy (5-15 min) | ✅ One-click (< 1 min) |
| **Verification** | ❌ None | ✅ ML-based auto-rollback |
| **Multi-Platform** | ❌ Custom scripts | ✅ Native support |

**Harness is $500k cheaper with 10× the capability.**

👉 **[See detailed cost workings](docs/COST_ANALYSIS.md)** (auditable to the line-item)

---

## The Proof

**Live CI/CD pipelines** running on every push:

- **user-service** (Node.js)
- **payment-service** (Go)
- **notification-service** (Python)

Each with: Build → Test → Scan → SBOM → Sign → Deploy

**Watch them run**: https://github.com/gregkroon/githubexperiment/actions

---

## Three Ways to Dig Deeper

### 1. 👨‍💻 For Engineers: Try the Demo (35 min)

**[→ Step-by-Step Demo](docs/DEMO.md)**

Walk through actual GitHub Actions implementation and see where it breaks:
- Configuration sprawl (3,000 environments)
- Custom code burden (2,500+ lines)
- Missing rollback
- No verification
- Heterogeneous complexity

**You'll experience the pain firsthand.**

---

### 2. 💼 For Leadership: Read the Business Case (15 min)

**[→ Executive Summary](docs/EXECUTIVE_SUMMARY.md)**

Understand the strategic implications:
- What GitHub does well (CI)
- What GitHub cannot do (enterprise CD)
- When to choose each approach
- Team sizing and operational burden
- Risk analysis

**Make informed budget decisions.**

---

### 3. 💰 For Finance: See the Math (20 min)

**[→ Cost Analysis](docs/COST_ANALYSIS.md)**

Granular breakdown of all costs with citations:
- FTE calculations (fully-loaded: $200k)
- GitHub Enterprise licensing
- Harness Enterprise pricing
- Custom development costs
- Hidden operational costs
- Sensitivity analysis

**Auditable to the line-item level.**

---

## What GitHub Actions CANNOT Do

**Five fundamental gaps that no amount of engineering can fix:**

### 1. ❌ No Rollback
- **GitHub**: Redeploy previous version (5-15 min MTTR)
- **Harness**: One-click rollback (< 1 min MTTR)
- **Impact**: One major outage = $5M+ in lost revenue

### 2. ❌ No Deployment Verification
- **GitHub**: Deploy and hope it works
- **Harness**: ML-based analysis, automatic rollback on anomalies
- **Impact**: Bad deploys reach production, customers affected

### 3. ❌ Heterogeneous Infrastructure is Custom Code
- **GitHub**: 2,500+ lines across K8s, VMs, ECS, Lambda, on-prem
- **Harness**: Native support for all platforms, vendor-maintained
- **Impact**: 4.5 FTE maintaining scripts vs 2 FTE managing platform

### 4. ❌ No Multi-Service Orchestration
- **GitHub**: Can't enforce service deployment order
- **Harness**: Dependency graphs, sequential/parallel control
- **Impact**: Complex deployments fail silently

### 5. ❌ No Deployment Governance
- **GitHub**: Can't enforce deployment windows, freezes, approvals at scale
- **Harness**: Built-in windows, holiday calendars, incident blocking
- **Impact**: Friday 6pm deploys happen, incidents during on-call gaps

**[See all 10 gaps](docs/DEMO.md#what-github-cannot-do)**

---

## The Hidden Cost: Platform Team Burden

### GitHub Actions Reality

**What you'll build and maintain:**
- 6 deployment patterns (K8s, VMs, ECS, Lambda, Azure, on-prem)
- 2,500+ lines of custom deployment code
- 3,000 environment configurations
- Custom orchestration, verification, metrics services
- Constant firefighting when platform APIs change

**Team required**: 4.5 FTE
- Need multi-cloud, multi-platform expertise
- On-call rotation for custom services
- Constant maintenance, no time for features

---

### Harness CD Reality

**What vendor provides:**
- All deployment targets supported natively
- Zero custom deployment code
- Centralized environment management
- Built-in orchestration, verification, metrics
- Vendor maintains integrations

**Team required**: 2 FTE
- Focus on business logic, not platform plumbing
- Vendor handles platform complexity
- Time to build features that matter

---

## Who This Repository Is For

### ✅ Use This If You're:
- Evaluating GitHub Actions vs dedicated CD platforms
- Experiencing pain at scale with GitHub Actions
- Need honest cost analysis (not vendor marketing)
- Building business case for platform investment
- Want to see actual working implementation

### ❌ This Is NOT:
- A "GitHub is terrible" hit piece (it's excellent for CI)
- Vendor-sponsored content (independent analysis)
- Theoretical comparison (everything runs live)
- Homogeneous K8s-only analysis (see [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md))

---

## The Right Architecture

### ✅ Recommended Approach

**GitHub Actions for CI** (what it's designed for):
- Build and test orchestration
- Security scanning (CodeQL, Dependabot, Trivy)
- SBOM generation
- Artifact publishing

**Harness CD for deployments** (what it's designed for):
- Multi-platform deployments
- Rollback and verification
- Deployment strategies (canary, blue-green)
- Orchestration and governance

**Best of both worlds**: Use each tool for its strengths

---

### ❌ What NOT To Do

**Don't use GitHub Actions for enterprise CD if you have:**
- Multiple deployment targets (K8s + anything else)
- Need for rollback capability
- Governance requirements (windows, approvals, freezes)
- Limited platform engineering capacity
- More than 200 services

**You'll waste $500k+ and countless engineering hours building what Harness already has.**

---

## Quick Start

### Fork and Run
```bash
# 1. Fork this repository
gh repo fork gregkroon/githubexperiment

# 2. Enable Actions
# GitHub → Settings → Actions → Allow all actions

# 3. Push a change
echo "test" >> README.md
git commit -am "trigger pipeline"
git push

# 4. Watch workflows run
gh run watch
```

### See the Gaps
1. Try to rollback a deployment (you can't)
2. Try to verify deployment health (no built-in way)
3. Try to orchestrate multi-service deploy (custom code required)
4. Try to manage 1000 environments centrally (impossible via UI)

**Then compare to Harness demo.**

---

## Key Documents

| Document | Purpose | Read Time | Audience |
|----------|---------|-----------|----------|
| [DEMO.md](docs/DEMO.md) | Step-by-step walkthrough | 35 min | Engineers |
| [EXECUTIVE_SUMMARY.md](docs/EXECUTIVE_SUMMARY.md) | Business case | 15 min | Leadership |
| [COST_ANALYSIS.md](docs/COST_ANALYSIS.md) | Detailed workings | 20 min | Finance |
| [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md) | Multi-platform analysis | 10 min | Enterprise architects |

---

## The Bottom Line

**For homogeneous K8s shops** (< 200 services, single cloud):
- GitHub might work with custom engineering
- Cost: ~$2M over 5 years
- **But you're still missing rollback and verification**

**For heterogeneous enterprises** (1000+ services, multi-platform):
- GitHub costs MORE ($6.5M vs $6.0M)
- Requires MORE people (4.5 FTE vs 2 FTE)
- Delivers LESS capability (no rollback, no verification)
- Creates MORE toil (2,500+ lines to maintain)

**Stop trying to make GitHub Actions work for enterprise CD.**

**Use the right tool for the job:**
- ✅ GitHub Actions for CI
- ✅ Harness CD for deployments

---

## Next Steps

### 1. Understand the Gaps
**[→ Read the Demo](docs/DEMO.md)** to see exactly where GitHub Actions breaks

### 2. See the Math
**[→ Read Cost Analysis](docs/COST_ANALYSIS.md)** for granular cost breakdown

### 3. Evaluate Harness
- Schedule demo focused on YOUR deployment targets
- Request POC for 10-20 services
- Measure actual rollback time
- Calculate prevented outage costs

### 4. Calculate YOUR Cost
**Questions to answer:**
- How many FTE maintain deployment scripts today?
- How many lines of custom deployment code?
- What's your incident MTTR without rollback?
- What does 1 hour of downtime cost?
- How much time spent on "deployment infrastructure"?

**[Use our cost model](docs/COST_ANALYSIS.md) with your numbers.**

---

## Essential Reading

**Start here** based on your role:

- **👨‍💻 Engineer**: [DEMO.md](docs/DEMO.md) - See the technical gaps
- **👔 Executive**: [EXECUTIVE_SUMMARY.md](docs/EXECUTIVE_SUMMARY.md) - Understand the business case
- **💰 Finance**: [COST_ANALYSIS.md](docs/COST_ANALYSIS.md) - Audit the math
- **🏢 Enterprise**: [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md) - Multi-platform reality check

**Then watch the pipelines run live**: https://github.com/gregkroon/githubexperiment/actions

---

## FAQ

**Q: Is this GitHub Actions bashing?**
No. GitHub Actions is excellent for CI. This shows it's not suitable for enterprise CD at heterogeneous scale.

**Q: Can't you just add Terraform/Vault/Argo?**
Adding tools doesn't fix fundamental gaps (no rollback, no verification). And now you're maintaining 3+ tools instead of 1.

**Q: What about vendor lock-in to Harness?**
You're choosing between:
- Lock-in to 2,500+ lines of custom code + 4.5 FTE tribal knowledge (GitHub)
- Lock-in to working platform with vendor support (Harness)

Migrating FROM Harness is easier than rewriting unmaintainable custom code.

**Q: Is the cost analysis realistic?**
Conservative. Real FTE cost is $250k (we used $200k). Hidden costs likely higher. See [COST_ANALYSIS.md](docs/COST_ANALYSIS.md) for all assumptions.

**Q: Can GitHub Actions work for my use case?**
Maybe. If you have:
- < 50 services
- 100% Kubernetes in single cloud
- Unlimited platform engineering time
- Can accept no rollback/verification

**Then GitHub might work. But you're one multi-cloud mandate away from complete rebuild.**

---

## Contributing

This is an independent analysis. Contributions welcome:
- Cost model improvements
- Additional deployment scenarios
- Enterprise case studies
- GitHub Actions workarounds we missed

**Open an issue or PR.**

---

## License

MIT License - Use this analysis however helps your organization make informed decisions.

---

## The Honest Conclusion

**GitHub Actions is a CI tool pretending to be a CD platform.**

**For 95% of enterprises with heterogeneous infrastructure:**
- Harness is cheaper ($500k over 5 years)
- Harness requires fewer people (2.5 fewer FTE)
- Harness delivers more capability (rollback, verification, orchestration)
- Harness reduces operational burden (zero custom code vs 2,500+ lines)

**Stop wasting engineering time building what Harness already has.**

**[See the detailed proof →](docs/DEMO.md)**

**[See the auditable math →](docs/COST_ANALYSIS.md)**
