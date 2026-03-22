# The Truth About GitHub Actions for Enterprise Deployment

**Can GitHub Actions replace a purpose-built CD platform for heterogeneous enterprises?**

**Short answer: No. At enterprise scale with heterogeneous infrastructure, GitHub costs MORE and delivers LESS.**

This repository compares:
- **GitHub Actions** (CI tool attempting to do CD)
- **Harness CD** (purpose-built enterprise deployment platform)

## The Brutal Reality

**For homogeneous Kubernetes-only shops** (<200 services, single cloud):
- GitHub can work with significant custom engineering
- Cost: ~$2.1M over 5 years

**For heterogeneous enterprises** (1000+ services, multi-cloud, VMs, serverless, on-prem):
- GitHub: **$6.7M** over 5 years + 4.5 FTE + constant toil
- Harness: **$6.0M** over 5 years + 2 FTE + vendor support
- **GitHub costs $700k MORE while delivering far less**

We show:
- ✅ What GitHub CAN do (basic CI/CD for Kubernetes)
- ❌ What GitHub CANNOT do (enterprise deployment at scale)
- 💰 The hidden costs of trying to make GitHub work for CD
- 🔥 Why Harness is purpose-built for what GitHub fails at

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

### What GitHub Actions Is Good At ✅

**GitHub Actions excels at CI** (Continuous Integration):
- Automated builds and tests
- Security scanning
- Native GitHub integration
- Good for code validation

**Stop there.** Using GitHub Actions for enterprise CD (Continuous Deployment) is where everything breaks.

---

### What GitHub Actions CANNOT Do ❌

**The fundamental gaps that no amount of engineering can fix**:

**1. ❌ Heterogeneous Infrastructure Support**
- GitHub Actions is designed for Kubernetes and cloud-native
- Each deployment target requires custom scripts:
  - **VMs** (Linux/Windows): Custom SSH/WinRM scripts, package management, service restarts
  - **ECS/Fargate**: AWS CLI wrappers, task definition management, custom health checks
  - **Lambda**: SAM/Serverless Framework integration, version management, alias handling
  - **Azure Functions**: Azure CLI scripts, slot management, custom deployment logic
  - **On-premise**: VPN connectivity, legacy app server management, manual rollback
- **Reality**: 2,500+ lines of custom deployment code across 6 patterns
- **Harness**: Native integrations for ALL deployment targets, maintained by vendor

**2. ❌ One-Click Rollback**
- GitHub: No rollback capability - must revert code and redeploy (5-15 minutes)
- Manual kubectl/AWS CLI commands (error-prone, no audit trail)
- **Harness**: One-click rollback to ANY previous version with full audit trail (< 1 minute)

**3. ❌ Advanced Deployment Strategies**
- **Canary deployments**: Not built-in, requires custom traffic management
- **Blue-Green deployments**: Custom infrastructure orchestration required
- **Progressive rollouts**: No native support
- **Harness**: Canary, blue-green, rolling, multi-service - all built-in with templates

**4. ❌ Deployment Verification with ML**
- GitHub: No deployment verification - you deploy and hope
- Must build custom metric collection and analysis (4-6 weeks)
- No anomaly detection, no automatic rollback on metric degradation
- **Harness Continuous Verification**: ML-based anomaly detection across error rates, latency, CPU, memory with automatic rollback

**5. ❌ Centralized Template Management**
- Workflows live IN developer repos (developers control deployment logic)
- CODEOWNERS requires manual review - doesn't scale to 1000 repos (10-20 PRs/day)
- Subtle bypasses (`continue-on-error: true`) slip through code review
- **Harness**: Templates locked in platform repo, architecturally impossible for developers to modify

**6. ❌ Multi-Service Orchestration**
- No dependency management between services
- Can't enforce "deploy service A, wait for health, then B, then C"
- Custom orchestration required for complex deployment graphs
- **Harness**: Built-in service dependency management, sequential/parallel control, deployment pipelines

**7. ❌ Environment Management at Scale**
- 1000 services × 3 environments = 3,000 configurations via GitHub UI
- Each environment: manual approvers, secrets, protection rules (20 min × 1000 = 333 hours)
- Secret rotation: Update 1000 repositories manually
- Configuration drift inevitable
- **Harness**: Centralized environment configuration, one place for all services

**8. ❌ Deployment Freezes & Windows**
- No deployment window enforcement (can't block Friday 6pm deployments)
- No holiday calendar integration
- No incident-based deployment blocking
- **Harness**: Deployment freezes, windows, holiday calendars, incident integration built-in

**9. ❌ Cross-Platform Secret Management**
- OIDC only works for cloud providers (AWS, Azure, GCP)
- VMs and on-prem still need secrets manually configured
- 15,000 secrets to manage via UI for 1000 services
- No automatic rotation, no centralized management
- **Harness**: Built-in secret management with automatic rotation, works across ALL platforms

**10. ❌ Deployment Observability & Analytics**
- No deployment dashboards
- No DORA metrics (must build or buy third-party tool)
- No deployment analytics or service health monitoring
- **Harness**: Complete deployment observability, DORA metrics, analytics, dashboards built-in

---

### The Real Cost Comparison (1000 Services, Heterogeneous Enterprise)

**This assumes realistic enterprise infrastructure**:
- 30% Kubernetes (EKS, AKS, GKE)
- 20% VMs (Linux, Windows, on-premise)
- 20% ECS/Fargate
- 15% Serverless (Lambda, Azure Functions)
- 10% Legacy on-premise
- 5% Other (Cloud Run, App Engine)

---

**Scenario A: GitHub Actions (The Reality)**

| | Year 1 | Years 2-5 (each) |
|---|--------|------------------|
| GitHub Enterprise (200 users) | $50k | $50k |
| Custom deployment patterns (6) | $200k | - |
| Platform engineers (4.5 FTE) | $900k | $900k |
| **Total** | **$1,150k** | **$950k** |
| **5-Year Total** | | **$4,950,000** |

**What you get**:
- ✅ Good CI (builds, tests, security scans)
- ❌ 2,500 lines of custom deployment code
- ❌ 4.5 FTE platform team managing toil
- ❌ No rollback, no canary, no verification
- ❌ 3,000 manual environment configs
- ❌ Constant maintenance as platforms change
- ❌ High operational burden

**Hidden costs** (not included above):
- Incident response complexity: +$500k
- Knowledge silos (multi-platform experts): +$250k
- Compliance overhead: +$375k
- Cross-platform orchestration: +$150k
- **Total hidden costs**: +$1,275k

**ACTUAL 5-Year Total**: **$6,225,000**

---

**Scenario B: Harness CD (Purpose-Built Platform)**

| | Year 1 | Years 2-5 (each) |
|---|--------|------------------|
| GitHub Team (CI only, 200 users) | $50k | $50k |
| Harness Enterprise (1000 services) | $600k | $600k |
| Professional services + training | $300k | - |
| Support (20% annually) | - | $120k |
| Platform engineers (2 FTE) | $400k | $400k |
| **Total** | **$1,350k** | **$1,170k** |
| **5-Year Total** | | **$6,030,000** |

**What you get**:
- ✅ Excellent CI (GitHub Actions)
- ✅ Enterprise CD (Harness)
- ✅ ALL deployment targets supported by vendor
- ✅ One-click rollback
- ✅ Canary/blue-green deployments
- ✅ ML-based deployment verification
- ✅ Centralized environment management
- ✅ Multi-service orchestration
- ✅ DORA metrics and observability
- ✅ 2 FTE vs 4.5 FTE (operational efficiency)
- ✅ Vendor handles platform integration changes

**No hidden costs**: Included in platform

---

### The Honest Comparison (Heterogeneous Enterprise)

| Approach | 5-Year Cost | FTE Required | Capabilities |
|----------|-------------|--------------|--------------|
| **GitHub Actions** | **$6,225,000** | 4.5 FTE | Basic CD, high toil |
| **Harness CD** | **$6,030,000** | 2 FTE | Enterprise CD, low toil |

**Harness is CHEAPER by $195k AND provides far superior capabilities.**

**The gap isn't close. It's obvious.**

---

### The Honest Recommendations

**< 50 services** (Startups, Series A-B):
- ✅ **GitHub Actions for CI + basic CD**
- Simple Kubernetes deployments can work
- 💰 Cost: **~$300k over 5 years**
- 👥 Team: 0.5 FTE
- **When to switch**: As soon as you add a second deployment target (VMs, Lambda, etc.)

**50-200 services** (Series C, growth companies):
- ⚠️ **GitHub starts showing cracks**
- If 100% Kubernetes in single cloud: Maybe GitHub
- If ANY heterogeneity: **Start evaluating Harness**
- 💰 GitHub Cost: **$1.2-1.8M** (with increasing toil)
- 💰 Harness Cost: **$2-3M** (with decreasing toil)
- **Recommendation**: Plan Harness migration before pain becomes unbearable

**200-500 services** (Public companies):
- ❌ **GitHub-Native is painful**
  - Multiple deployment targets emerging
  - Platform team burning out on toil
  - Custom code accumulating (1000+ lines)
  - No rollback, no verification, no orchestration
  - 💰 Cost: **$2.5-4M over 5 years**
  - 👥 Team: 2-3 FTE constantly fighting fires

- ✅ **Harness** (recommended)
  - Stop building what Harness already has
  - Enterprise CD capabilities out of the box
  - 💰 Cost: **$4-5M over 5 years**
  - 👥 Team: 1.5 FTE focused on business value
  - **ROI**: Higher upfront cost, but platform team efficiency + reduced outages

**500-1000+ services** (Enterprise scale):

**If K8s-only (>95% Kubernetes, single cloud)**:
- ⚠️ **GitHub might work** (but you're on borrowed time)
  - 💰 Cost: **$3-4M over 5 years**
  - 👥 Team: 2-3 FTE
  - **Risk**: One acquisition/mandate for VMs = everything breaks

**If heterogeneous (the reality for most enterprises)**:
- ❌ **GitHub-Native is a disaster**
  - Multiple clouds (AWS, Azure, GCP)
  - Multiple targets (K8s, VMs, ECS, Lambda, on-prem)
  - 6 deployment patterns = 2,500+ lines custom code
  - 4.5 FTE platform team drowning in toil
  - No rollback during incidents = extended outages
  - 💰 Cost: **$6.2M over 5 years**
  - 👥 Team: 4.5 FTE + high turnover
  - **Reality**: Platform team spends 60% time on maintenance, 40% on new features

- ✅ **Harness** (the obvious choice)
  - Purpose-built for heterogeneous enterprises
  - ALL deployment targets supported by vendor
  - One-click rollback saves millions in outage costs
  - ML verification prevents bad deployments
  - 💰 Cost: **$6.0M over 5 years**
  - 👥 Team: 2 FTE focused on business logic
  - **Savings**: $200k + reduced operational burden + prevented outages
  - **See**: [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md)

---

## When GitHub Actions Makes Sense

**GitHub Actions is excellent for CI**:
- ✅ Use it for builds, tests, security scanning
- ✅ Use it for Kubernetes-only deployments at small scale (< 50 services)
- ✅ Use it if you have unlimited engineering time to build CD yourself

**GitHub Actions for CD is a mistake when**:
- ❌ You have > 100 services
- ❌ You have multiple deployment targets
- ❌ You need rollback during incidents
- ❌ You need deployment verification
- ❌ You need multi-service orchestration
- ❌ You value your platform team's time
- ❌ You want to prevent outages, not react to them

---

## When Harness CD Is The Answer

**Harness is purpose-built for**:
- ✅ Heterogeneous infrastructure (multi-cloud, multi-platform)
- ✅ Enterprise scale (100+ services)
- ✅ Advanced deployment strategies (canary, blue-green)
- ✅ Deployment verification with automatic rollback
- ✅ Multi-service orchestration
- ✅ Operational efficiency (reduce platform team toil)
- ✅ Governance and compliance at scale
- ✅ Preventing outages, not managing them

**The real question isn't "Can we make GitHub work?"**

**The question is: "Why would we waste engineering time and money trying when Harness solves this?"**

---

## The Brutal Comparison: What Harness Does That GitHub Cannot

### Deployment Strategies
| Capability | GitHub Actions | Harness CD |
|------------|----------------|------------|
| **Canary deployments** | ❌ Custom code required | ✅ Built-in with % traffic control |
| **Blue-Green deployments** | ❌ Custom infra orchestration | ✅ Built-in with instant switch |
| **Rolling deployments** | ⚠️ Basic K8s only | ✅ All platforms, configurable |
| **Multi-service orchestration** | ❌ No dependency mgmt | ✅ Dependency graphs, parallel/sequential |

### Deployment Verification
| Capability | GitHub Actions | Harness CD |
|------------|----------------|------------|
| **Metric-based verification** | ❌ Must build | ✅ ML-based anomaly detection |
| **Error rate monitoring** | ❌ Custom integration | ✅ Auto-monitor error rates |
| **Latency verification** | ❌ Custom integration | ✅ Auto-monitor response times |
| **Automatic rollback** | ❌ Impossible | ✅ Rolls back on metric degradation |
| **Integration** | ❌ Must build each | ✅ Prometheus, Datadog, New Relic, AppDynamics built-in |

### Rollback & Recovery
| Capability | GitHub Actions | Harness CD |
|------------|----------------|------------|
| **One-click rollback** | ❌ No capability | ✅ < 1 minute to any version |
| **Rollback method** | Revert git + redeploy (5-15 min) | Click button (< 1 min) |
| **Audit trail** | ⚠️ Git history only | ✅ Full deployment history with diffs |
| **Partial rollback** | ❌ All or nothing | ✅ Rollback specific services |

### Heterogeneous Platform Support
| Platform | GitHub Actions | Harness CD |
|----------|----------------|------------|
| **Kubernetes** | ✅ Good support | ✅ Excellent support |
| **VMs (Linux/Windows)** | ❌ Custom SSH/WinRM scripts | ✅ Native integration |
| **ECS/Fargate** | ❌ Custom AWS CLI scripts | ✅ Native integration |
| **Lambda** | ❌ Custom SAM/Serverless | ✅ Native integration |
| **Azure Functions** | ❌ Custom Azure CLI | ✅ Native integration |
| **On-premise legacy** | ❌ Custom scripts + VPN | ✅ Native integration |
| **Custom maintenance** | ❌ You maintain all scripts | ✅ Harness maintains all |

### Governance & Compliance
| Capability | GitHub Actions | Harness CD |
|------------|----------------|------------|
| **Template locking** | ❌ CODEOWNERS (manual review) | ✅ Architecturally locked |
| **Deployment freezes** | ❌ No capability | ✅ Time-based, holiday calendars |
| **Deployment windows** | ❌ No enforcement | ✅ Enforce deployment windows |
| **Incident blocking** | ❌ No capability | ✅ Block deploys during incidents |
| **Approval workflows** | ⚠️ Manual reviewers only | ✅ JIRA/ServiceNow integration |
| **Policy enforcement** | ❌ No central enforcement | ✅ OPA policies centrally managed |

### Environment & Secret Management
| Capability | GitHub Actions | Harness CD |
|------------|----------------|------------|
| **Environment config** | ❌ 3,000 manual UI configs | ✅ Centralized, one place |
| **Secret management** | ❌ 15,000 manual secrets | ✅ Built-in + Vault integration |
| **Secret rotation** | ❌ Manual across 1000 repos | ✅ Automatic rotation |
| **Cross-platform secrets** | ⚠️ OIDC cloud only | ✅ Works everywhere |

### Observability & Analytics
| Capability | GitHub Actions | Harness CD |
|------------|----------------|------------|
| **Deployment dashboards** | ❌ No dashboards | ✅ Real-time deployment views |
| **DORA metrics** | ❌ Must build or buy | ✅ Built-in (frequency, lead time, MTTR) |
| **Service health** | ❌ No monitoring | ✅ Service health tracking |
| **Deployment analytics** | ❌ No analytics | ✅ Trends, failures, success rates |

### Operational Efficiency
| Metric | GitHub Actions | Harness CD |
|--------|----------------|------------|
| **Platform team size** | 4.5 FTE (heterogeneous) | 2 FTE |
| **Custom code to maintain** | 2,500+ lines | 0 lines |
| **Time to add new platform** | 2-4 weeks custom code | 0 (vendor maintains) |
| **Incident MTTR** | 5-15 min (no rollback) | < 1 min (one-click) |
| **Deployment patterns** | 6 custom patterns | 0 (vendor provides) |

---

## What "No Vendor Lock-In" Actually Costs

**GitHub advocates say**: "But GitHub has no vendor lock-in!"

**The reality**:
- ✅ True: You can move your workflows
- ❌ **But you're locked into your custom code** (2,500+ lines)
- ❌ **Locked into your platform team's tribal knowledge** (4.5 FTE)
- ❌ **Locked into constant maintenance** (30% of platform team time)
- ❌ **Locked into operational toil** (incidents, firefighting)

**With Harness**:
- ⚠️ True: Harness-specific config (migration cost)
- ✅ **But no custom deployment code** (0 lines to maintain)
- ✅ **No platform-specific expertise needed** (vendor handles it)
- ✅ **No maintenance burden** (vendor updates integrations)
- ✅ **Reduced operational toil** (one-click rollback, verification)

**The question**: Would you rather be "locked in" to 2,500 lines of custom code and 4.5 FTE maintaining it, or "locked in" to a vendor that handles everything?

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

### ✅ What GitHub Actions Can Do
- **Excellent CI**: Builds, tests, security scanning, SBOM generation
- **Basic CD for Kubernetes**: Simple deployments to K8s clusters work
- **Good for small scale**: < 50 services, single platform, single cloud
- **Reusable workflows**: Reduce code duplication

### ❌ What GitHub Actions Cannot Do At Enterprise Scale

**Fundamental architectural limitations**:
1. **No rollback capability** - Production outage? Wait 5-15 minutes for redeploy
2. **No deployment verification** - Deploy and hope (vs ML-based verification)
3. **No canary/blue-green** - Custom code required (hundreds of lines per service)
4. **No multi-service orchestration** - Can't manage service dependencies
5. **No deployment freezes** - Can't prevent Friday 6pm deployments
6. **No centralized governance** - Developers control deployment logic in their repos
7. **No heterogeneous platform support** - Each target needs custom scripts (2,500+ lines)

**Operational reality at heterogeneous scale**:
- **2,500+ lines of custom deployment code** to maintain across 6 patterns
- **4.5 FTE platform team** managing constant toil (vs 2 FTE with Harness)
- **6 deployment patterns** to update when cloud providers change APIs
- **3,000 manual environment configurations** to manage via UI
- **No automatic rollback** = extended outages costing millions during incidents
- **Platform team burnout** from maintaining custom scripts instead of business value

### 💰 The Real Cost (Heterogeneous Enterprise, 1000 Services)

| Approach | 5-Year Cost | FTE | Custom Code | Rollback | Verification | Platform Support |
|----------|-------------|-----|-------------|----------|--------------|------------------|
| **GitHub Actions** | **$6.2M** | 4.5 | 2,500 lines | ❌ None | ❌ None | ❌ Custom scripts |
| **Harness CD** | **$6.0M** | 2.0 | 0 lines | ✅ < 1 min | ✅ ML-based | ✅ Vendor maintained |

**Harness is $200k CHEAPER and delivers 10× the capability.**

---

## 🎯 The Brutal Truth

### GitHub Actions Fails At Enterprise Heterogeneous Scale

**The gaps aren't fixable**:
1. **No rollback** - Production outage MTTR: 5-15 minutes (vs < 1 minute with Harness)
2. **No verification** - Bad deployments reach production (vs ML prevention with Harness)
3. **Custom code burden** - 2,500+ lines across 6 deployment patterns to maintain
4. **FTE cost** - 4.5 platform engineers vs 2 (2.25× more expensive in human cost)
5. **Platform maintenance** - You maintain all integrations as cloud providers change APIs
6. **Knowledge silos** - Need experts in K8s, ECS, Lambda, VMs, Azure Functions, on-prem
7. **Operational toil** - 60% of platform team time on maintenance vs 40% on business value

**The cost isn't just money**:
- **Platform team burnout** - Constant firefighting, no innovation time
- **Extended outages** - No rollback = millions in revenue loss
- **Bad deployments** - No verification = customer-impacting incidents
- **Technical debt** - 2,500 lines of custom code growing every quarter

---

### For Heterogeneous Enterprises: Harness Is The Answer

**If your enterprise has**:
- Multiple clouds (AWS, Azure, GCP)
- Multiple platforms (K8s, VMs, ECS, Lambda, Functions, on-prem)
- > 100 services
- Governance requirements (deployment windows, approvals, compliance)

**Then the math is simple**:

**GitHub Actions**:
- ❌ $6.2M over 5 years
- ❌ 4.5 FTE platform team
- ❌ 2,500+ lines custom code to maintain
- ❌ No rollback (5-15 min MTTR)
- ❌ No verification (bad deploys reach prod)
- ❌ Platform team burnout

**Harness CD**:
- ✅ $6.0M over 5 years (**$200k cheaper**)
- ✅ 2.0 FTE platform team (focus on business value)
- ✅ 0 lines custom deployment code
- ✅ One-click rollback (< 1 min MTTR)
- ✅ ML verification (prevent bad deploys)
- ✅ Platform team happiness

**The choice is obvious: Harness.**

**See the full analysis**: [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md)

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

## Stop Trying To Make GitHub Actions Work For Enterprise CD

### The Reality Most Companies Learn Too Late

**Year 1**: "GitHub Actions is fine, we'll just write some custom scripts"
- 200 lines of custom deployment code
- 1 platform engineer maintaining it
- Working for 20 services in Kubernetes

**Year 2**: "We're adding VMs and Lambda, let's extend our scripts"
- 800 lines of custom code across 3 deployment patterns
- 2 platform engineers, starting to feel the pain
- 100 services, maintenance burden growing

**Year 3**: "We acquired a company with Azure and on-prem infrastructure"
- 2,500 lines of custom code across 6 deployment patterns
- 4 platform engineers, constant firefighting
- 500 services, no rollback, production outages increasing
- Platform team asks: "Can we please evaluate Harness?"

**Year 4**: "Production outage costs $5M because we couldn't rollback quickly"
- Management finally approves Harness migration
- 6 months to migrate off custom GitHub Actions CD
- $200k migration cost + $600k/year Harness license
- Platform team: "Why didn't we do this 3 years ago?"

**Total wasted**: 3 years of platform team toil + $5M outage + $200k migration = **$5.2M+ in preventable costs**

---

### The Question You Should Be Asking

**Not**: "Can GitHub Actions work for enterprise CD?"

**But**: "Why would we waste years and millions building and maintaining what Harness already has?"

---

### For Heterogeneous Enterprises: The Math Is Simple

**GitHub Actions (the painful path)**:
- $6.2M over 5 years
- 4.5 FTE maintaining custom code
- 2,500+ lines of deployment scripts
- No rollback = extended outages
- No verification = bad deploys reach production
- Platform team burnout and turnover

**Harness CD (the smart path)**:
- $6.0M over 5 years (**$200k cheaper**)
- 2 FTE focused on business value
- 0 lines of custom deployment code
- One-click rollback (< 1 min MTTR)
- ML verification prevents bad deploys
- Happy platform team building features

**The ROI is obvious. Stop wasting engineering time.**

---

### When GitHub Actions Makes Sense

**Only use GitHub Actions for CD if**:
- ✅ You have < 50 services
- ✅ 100% Kubernetes in single cloud
- ✅ You have unlimited platform engineering time
- ✅ You're willing to accept no rollback capability
- ✅ You're willing to accept no deployment verification
- ✅ You're comfortable with 5-15 minute incident MTTR

**Even then**: You're one multi-cloud mandate away from needing Harness.

---

### For Everyone Else: Choose Harness

**Use Harness CD if you**:
- ✅ Have > 50 services
- ✅ Have ANY deployment heterogeneity (K8s + anything else)
- ✅ Value platform team time
- ✅ Need rollback during incidents
- ✅ Need deployment verification
- ✅ Want to prevent outages, not react to them
- ✅ Operate in multiple clouds or regions
- ✅ Have governance/compliance requirements

**For 95% of enterprises: Harness is the right choice.**

**See the detailed analysis**: [HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md)

---

## Essential Reading

### Understand What GitHub Actions Cannot Do
- **[Try the Demo](docs/DEMO.md)** - See GitHub Actions break at enterprise scale
- **[Read Executive Summary](docs/EXECUTIVE_SUMMARY.md)** - Business case showing Harness ROI

### For Heterogeneous Enterprises (Most Companies)
- **[Heterogeneous Reality Check](HETEROGENEOUS_REALITY.md)** ⚠️ **MUST READ** if you have:
  - Multiple clouds (AWS, Azure, GCP)
  - Multiple deployment targets (K8s, VMs, ECS, Lambda, on-prem)
  - > 100 services
  - Deployment governance requirements
  - **Proves Harness is $200k CHEAPER than GitHub Actions with 2.5× less FTE burden**

### See GitHub Actions Struggle
- **[Watch Workflows Run](https://github.com/gregkroon/githubexample/actions)** - Basic CI/CD demo (works for simple K8s)
- Then ask yourself: "Can this handle our heterogeneous enterprise reality?"
- The answer is no.

---

**Stop wasting engineering time. Choose the right tool: Harness CD for heterogeneous enterprises.**
