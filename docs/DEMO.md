# GitHub Actions for Enterprise CD: Hands-On Demo

**Watch GitHub Actions fail at enterprise deployment in real-time.**

**Time**: 20 minutes
**Outcome**: See the 5 critical gaps firsthand

---

## What You'll See

Walk through a **real, working GitHub Actions implementation** and experience the five gaps that make it unsuitable for enterprise CD:

1. ❌ **Configuration sprawl** (3,000 environments manually configured)
2. ❌ **No rollback** (redeploy takes 5-15 min vs Harness < 1 min)
3. ❌ **Heterogeneous = custom code** (2,500+ lines across 6 platforms)
4. ❌ **No deployment verification** (bad deploys reach production)
5. ❌ **No multi-service orchestration** (can't enforce order)

**All pipelines run live**: https://github.com/gregkroon/githubexperiment/actions

---

## The Setup

**3 microservices** with complete CI/CD:
- **user-service** (Node.js)
- **payment-service** (Go)
- **notification-service** (Python)

**Each has**: Build → Test → Scan → SBOM → Sign → Deploy

**Fork and run**:
```bash
gh repo fork gregkroon/githubexperiment
cd githubexperiment
echo "test" >> README.md && git commit -am "trigger" && git push
gh run watch
```

---

## Problem 1: Configuration Sprawl

### The Scenario
**1000 services** × **3 environments** = **3,000 manual configurations**

### Try It
1. Go to **Settings → Environments**
2. See `dev` and `production` environments
3. Each needs: approvers, secrets, protection rules, wait timers

### The Math
- **20 min** to configure one environment
- **3,000 environments** = **1,000 hours** of manual UI work
- **Ongoing**: Configuration drift, no centralized management

### With Harness
- One centralized environment config
- Apply to all 1000 services instantly
- Zero drift

**Conclusion**: ❌ **GitHub = 1,000 hours manual work**

---

## Problem 2: No Rollback Capability

### The Scenario
Production has 500 errors. How fast can you roll back?

### Try It
```bash
# 1. Break production
cd user-service
echo "bad code" >> src/index.js
git commit -am "break production" && git push

# 2. Watch it deploy
open https://github.com/gregkroon/githubexperiment/actions

# 3. Try to roll back
# ❌ No rollback button
# ❌ No rollback action
# ❌ Must revert + redeploy
```

### The Manual Process
```bash
git log --oneline          # Find previous commit
git revert HEAD            # Revert
git push                   # Trigger CI/CD again

# Wait 5-15 minutes:
# - Build: 3 min
# - Test: 2 min
# - Security: 3 min
# - SBOM: 1 min
# - Deploy: 5 min
# TOTAL: 14 minutes MINIMUM
```

### With Harness
- Click rollback button
- < 1 minute to previous version
- Full audit trail

### Impact
**One outage** (99.99% SLA breach):
- **14 min with GitHub** = millions lost
- **< 1 min with Harness** = minimal impact

**Conclusion**: ❌ **14× slower incident response**

---

## Problem 3: Heterogeneous = Custom Code Everywhere

### The Reality
Typical 1000-service enterprise infrastructure:
- 30% Kubernetes
- 20% VMs
- 20% ECS
- 15% Lambda
- 10% On-prem
- 5% Other

Each deployment target requires **custom scripts**:

#### Kubernetes (~150 lines)
```yaml
- kubectl apply -f k8s/
- kubectl rollout status deployment/app
- kubectl rollout undo deployment/app  # manual rollback
```

#### VMs (~200 lines)
```yaml
- ssh user@server "systemctl stop app"
- scp package.tar.gz user@server:/opt/app
- ssh user@server "tar -xzf /opt/app/package.tar.gz"
- ssh user@server "systemctl start app"
# Rollback? Copy old package back manually
```

#### ECS (~180 lines)
```yaml
- aws ecs register-task-definition --cli-input-json file://task-def.json
- aws ecs update-service --cluster prod --task-definition app:$VERSION
# Rollback? Update service to previous task def
```

#### Lambda (~150 lines)
```yaml
- sam build && sam deploy --stack-name app
- aws lambda update-alias --name prod --function-version $VERSION
# Rollback? Shift alias back
```

#### Azure Functions (~140 lines)
```yaml
- az functionapp deployment source config-zip
- az functionapp deployment slot swap --slot staging
# Rollback? Swap back
```

#### On-Premise (~250 lines)
```yaml
- vpn connect
- ansible-playbook deploy.yml
- custom health checks
# Rollback? Hope you have backups
```

### Total: 2,500+ Lines of Custom Deployment Code

### With Harness
- All 6 targets supported natively
- **0 lines** of custom deployment code
- Vendor maintains all integrations

**Conclusion**: ❌ **Maintain 2,500+ lines forever**

**[See maintenance costs →](COST_ANALYSIS.md#custom-development-costs)**

---

## Problem 4: No Deployment Verification

### The Scenario
Deploy causes error rates to spike from 0.1% to 5%. GitHub doesn't notice.

### Try It
1. Deploy a change
2. Check if GitHub verified health: ❌ No
3. Check if GitHub monitors errors: ❌ No
4. Check if GitHub auto-rolls back: ❌ No

### What You Must Build
**Custom deployment verification service**:
- Integrate Prometheus/DataDog
- Query error rates, latency, CPU, memory
- Statistical anomaly detection
- Automatic rollback trigger

**Build**: 4-6 weeks
**Maintenance**: 6 hrs/week

**[See detailed cost →](COST_ANALYSIS.md#service-2-deployment-gate-service)**

### With Harness
- ML-based continuous verification built-in
- Monitors errors, latency, infrastructure
- Automatic rollback on anomalies
- Zero custom code

**Conclusion**: ❌ **6 weeks to build (or deploy blind)**

---

## Problem 5: No Multi-Service Orchestration

### The Scenario
Service dependencies:
- **database-migrations** must deploy first
- **backend-api** must deploy second (needs migrations)
- **frontend** must deploy last (needs API)

### Try It
**GitHub Actions**: ❌ **No way to enforce order across repos**

**Workarounds**:
1. Manual coordination (error-prone)
2. Build custom orchestrator (12 weeks)
3. Use workflow_run triggers (complex, doesn't scale)

### What You Must Build
**Custom multi-service orchestrator**:
- Service dependency graph
- Deployment sequencing
- Health check coordination
- Failure cascades

**Build**: 12 weeks
**Maintenance**: 10 hrs/week

**[See detailed cost →](COST_ANALYSIS.md#service-3-multi-service-orchestration)**

### With Harness
- Built-in service dependencies
- Drag-and-drop dependency graph
- Automatic sequencing
- Failure handling included

**Conclusion**: ❌ **12 weeks to build orchestration**

---

## The Complete Picture

| Capability | GitHub | Harness | Gap |
|------------|--------|---------|-----|
| **Configuration** | 3,000 manual | 1 centralized | 1,000 hours work |
| **Rollback** | Redeploy (14 min) | One-click (< 1 min) | 14× slower MTTR |
| **Multi-platform** | 2,500+ lines | 0 lines (native) | 2,500+ lines maintenance |
| **Verification** | Build it (6 weeks) | Built-in ML | 6 weeks + ongoing |
| **Orchestration** | Build it (12 weeks) | Built-in | 12 weeks + ongoing |

**Total investment to match Harness**:
- **32 weeks build**
- **30-48 hrs/week** ongoing maintenance
- **2,500+ lines** custom code
- **4.5 FTE** vs 2 FTE

**[See full cost breakdown →](COST_ANALYSIS.md)**

---

## The Cost Reality

| | GitHub Actions | Harness CD |
|---|---|---|
| **Licenses** | $250k (5yr) | $3,230k (5yr) |
| **Custom dev** | $800k | $300k (Year 1 only) |
| **Platform team** | $4,500k (4.5 FTE) | $2,000k (2 FTE) |
| **Hidden costs** | $400k | $0 |
| **TOTAL (5yr)** | **$5,950k** | **$5,530k** |

**Harness: $420k cheaper + 10× capability**

**[See detailed workings →](COST_ANALYSIS.md)**

---

## What GitHub Does Well

**GitHub Actions is EXCELLENT for CI**:
- ✅ Build & test orchestration
- ✅ Security scanning (CodeQL, Trivy, Dependabot)
- ✅ SBOM generation
- ✅ Native GitHub integration

**Keep using GitHub Actions for CI**

---

## What GitHub Fails At

**GitHub Actions is TERRIBLE for enterprise CD**:
- ❌ No rollback (14× slower incident response)
- ❌ No verification (bad deploys reach production)
- ❌ Heterogeneous = 2,500+ lines custom code
- ❌ No orchestration (complex deployments fail)
- ❌ Configuration sprawl (1,000 hours manual work)

**Don't waste 32 weeks building what Harness has**

---

## Security Note

**Can developers bypass security gates?**

**GitHub Enterprise Required Workflows prevent MOST bypasses**:
- ✅ Can't skip security scan
- ✅ Can't use continue-on-error
- ✅ Can't bypass branch protection
- ✅ Workflow changes need approval (CODEOWNERS)

**BUT one architectural gap remains**:
- ⚠️ Workflows run in **parallel**
- ⚠️ Deployment can complete **before** Required Workflow security scan finishes
- ⚠️ Vulnerable code can reach production before scan detects issues

**Harness**: Sequential pipeline stages architecturally block deployment until security passes.

**[See detailed security analysis →](SECURITY_ENFORCEMENT.md)**

---

## The Right Architecture

### ✅ Recommended
**GitHub Actions for CI** → **Harness CD for deployments**

**Why**:
- Use each tool for its strengths
- GitHub builds & tests
- Harness deploys
- Standard integration via image registry

### ❌ Wrong
**GitHub Actions for everything**

**Why**:
- Fighting the tool constantly
- 4.5 FTE firefighting vs 2 FTE building features
- No rollback during incidents
- Platform team burnout

---

## Try It Yourself

```bash
# Fork and run
gh repo fork gregkroon/githubexperiment
cd githubexperiment
```

### Exercises

1. **See configuration sprawl**
   - Settings → Environments
   - Try configuring 10 services
   - Extrapolate to 1000

2. **See no rollback**
   - Break a deployment
   - Try to roll back quickly
   - Time how long it takes

3. **See custom code burden**
   - Look at `.github/workflows/`
   - Imagine maintaining for K8s, VMs, ECS, Lambda, Azure, on-prem
   - Count the lines

**Then ask**: Is this how I want my platform team spending time?

---

## Next Steps

### 1. Understand the Business Case
**[→ EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)** - Strategic decision framework

### 2. Audit the Math
**[→ COST_ANALYSIS.md](COST_ANALYSIS.md)** - Detailed FTE calculations, 16 cited sources

### 3. See Security Analysis
**[→ SECURITY_ENFORCEMENT.md](SECURITY_ENFORCEMENT.md)** - What GitHub Enterprise can/cannot prevent

### 4. Evaluate Harness
- Schedule demo for YOUR deployment targets
- Request POC for 10-20 services
- Measure actual rollback time
- Calculate prevented outage costs

### 5. Calculate YOUR Cost
- How many FTE maintain deployment scripts?
- How many lines of custom deployment code?
- Current incident MTTR?
- What does 1 hour downtime cost?

**[Use our cost model](COST_ANALYSIS.md) with your numbers**

---

## The Honest Conclusion

**GitHub Actions is a CI tool pretending to be a CD platform.**

**What this demo proved**:
- ❌ Configuration doesn't scale (1,000 hours manual)
- ❌ No rollback (14× slower MTTR)
- ❌ Heterogeneous = 2,500+ lines custom code
- ❌ Must build verification & orchestration (32 weeks)
- ❌ Platform team burns out maintaining workarounds

**For enterprise CD**: Stop building what Harness already has.

**[See business case →](EXECUTIVE_SUMMARY.md)** | **[See the math →](COST_ANALYSIS.md)** | **[See security analysis →](SECURITY_ENFORCEMENT.md)**
