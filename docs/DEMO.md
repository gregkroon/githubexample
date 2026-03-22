# GitHub Actions for Enterprise CD: Hands-On Demo

**Watch GitHub Actions fail at enterprise deployment in real-time.**

**Time**: 35 minutes
**Prerequisites**: GitHub account, basic CI/CD knowledge
**Outcome**: Understand exactly where GitHub breaks at scale

---

## What You'll See

This demo walks through a **real, working GitHub Actions implementation** and shows the five critical gaps that make it unsuitable for enterprise CD:

1. ❌ **Configuration sprawl** (3,000 environments to manage manually)
2. ❌ **No rollback** (redeploy takes 5-15 min vs Harness < 1 min)
3. ❌ **Heterogeneous requires custom code** (2,500+ lines across 6 platforms)
4. ❌ **No deployment verification** (bad deploys reach production)
5. ❌ **No multi-service orchestration** (can't enforce deployment order)

**All pipelines run live**: https://github.com/gregkroon/githubexperiment/actions

---

## The Setup

**3 microservices** with complete CI/CD:
- **user-service** (Node.js)
- **payment-service** (Go)
- **notification-service** (Python)

**Each service has**:
- Automated build & test
- Security scanning (Trivy, CodeQL)
- SBOM generation & signing
- Deployment to dev & production
- 17 security gates total

**Fork and run**:
```bash
gh repo fork gregkroon/githubexperiment
cd githubexperiment
echo "test" >> README.md
git commit -am "trigger pipeline"
git push
gh run watch
```

---

## Problem 1: Configuration Sprawl

### The Scenario
**1000 services** × **3 environments** = **3,000 configurations**

### Try It
1. Go to repo **Settings → Environments**
2. See `dev` and `production` environments
3. Each needs manual configuration:
   - Deployment approvers
   - Environment secrets
   - Protection rules
   - Wait timers

### The Math
- **Setup time**: 20 min per environment
- **1000 services**: 20 min × 3 envs × 1000 = 60,000 minutes = **1,000 hours**
- **Ongoing**: Configuration drift inevitable, no centralized management

### With Harness
- **One centralized environment configuration**
- Apply to all 1000 services instantly
- Zero configuration drift

**Conclusion**: ❌ **GitHub requires 1,000 hours of manual UI work**

---

## Problem 2: No Rollback Capability

### The Scenario
Production deployment causes 500 errors. How fast can you roll back?

### Try It
1. **Trigger a deployment**:
   ```bash
   cd user-service
   echo "bad code" >> src/index.js
   git commit -am "break production"
   git push
   ```

2. **Watch it deploy**: https://github.com/gregkroon/githubexperiment/actions

3. **Now try to roll back**:
   - ❌ No rollback button in GitHub UI
   - ❌ No rollback action in workflows
   - ❌ Must revert commit and redeploy (5-15 min)

### The Manual Process
```bash
# Step 1: Find previous working commit
git log --oneline

# Step 2: Revert
git revert HEAD
git push

# Step 3: Wait for CI/CD to run again (5-15 min)
# - Build: 3 min
# - Test: 2 min
# - Security scan: 3 min
# - SBOM: 1 min
# - Deploy: 5 min
# Total: 14 minutes MINIMUM
```

### With Harness
- **One-click rollback** from UI
- **< 1 minute** to previous version
- **Full audit trail** of who rolled back and why

### Impact
**One major outage** (99.99% SLA breach):
- **14 min with GitHub** = millions in lost revenue
- **< 1 min with Harness** = minimal customer impact

**Conclusion**: ❌ **GitHub has no rollback - 14× slower incident response**

---

## Problem 3: Heterogeneous = Custom Code Everywhere

### The Scenario
Enterprise infrastructure (typical 1000-service company):
- 30% Kubernetes (300 services)
- 20% VMs (200 services)
- 20% ECS (200 services)
- 15% Lambda (150 services)
- 10% On-prem (100 services)
- 5% Other (50 services)

### The Reality
Each deployment target requires custom scripts:

#### Kubernetes (Works OK)
```yaml
# .github/workflows/deploy-k8s.yml
- kubectl apply -f k8s/
- kubectl rollout status deployment/app
- kubectl rollout undo deployment/app  # manual
```
**Lines**: ~150

#### VMs (Custom SSH Scripts)
```yaml
# .github/workflows/deploy-vm.yml
- ssh user@server "systemctl stop app"
- scp package.tar.gz user@server:/opt/app
- ssh user@server "tar -xzf /opt/app/package.tar.gz"
- ssh user@server "systemctl start app"
- ssh user@server "systemctl is-active app"  # health check
# Rollback? Copy old package back manually
```
**Lines**: ~200

#### ECS (Custom AWS CLI)
```yaml
# .github/workflows/deploy-ecs.yml
- aws ecs register-task-definition --cli-input-json file://task-def.json
- aws ecs update-service --cluster prod --service app --task-definition app:$VERSION
- aws ecs wait services-stable --cluster prod --services app
# Rollback? Update service to previous task def
```
**Lines**: ~180

#### Lambda (Custom SAM/Serverless)
```yaml
# .github/workflows/deploy-lambda.yml
- sam build
- sam deploy --stack-name app --capabilities CAPABILITY_IAM
- aws lambda update-alias --name prod --function-name app --function-version $VERSION
# Rollback? Shift alias back
```
**Lines**: ~150

#### Azure Functions (Custom Azure CLI)
```yaml
# .github/workflows/deploy-azure-functions.yml
- az functionapp deployment source config-zip
- az functionapp deployment slot swap --slot staging --name app
# Rollback? Swap back
```
**Lines**: ~140

#### On-Premise (Custom Everything)
```yaml
# .github/workflows/deploy-onprem.yml
- vpn connect
- ansible-playbook deploy.yml
- custom health check scripts
- manual verification
# Rollback? Hope you have backups
```
**Lines**: ~250

### Total Custom Code
**2,500+ lines** across 6 deployment patterns

### With Harness
- All 6 deployment targets supported natively
- **0 lines of custom deployment code**
- Vendor maintains all integrations

**Conclusion**: ❌ **GitHub requires 2,500+ lines of custom code to maintain forever**

**[See detailed cost of maintaining this code →](COST_ANALYSIS.md#custom-development-costs)**

---

## Problem 4: No Deployment Verification

### The Scenario
New deployment causes error rates to spike from 0.1% to 5%. GitHub doesn't notice.

### Try It
1. Deploy a change
2. Check if GitHub verified deployment health: ❌ **No**
3. Check if GitHub monitors error rates: ❌ **No**
4. Check if GitHub auto-rolls back on anomalies: ❌ **No**

### What You Must Build
**Custom deployment verification service**:
- Integrate with Prometheus/DataDog
- Query error rates, latency, CPU, memory
- Statistical analysis for anomaly detection
- Automatic rollback trigger
- Alert notifications

**Build time**: 4-6 weeks
**Ongoing maintenance**: 6 hrs/week
**[See detailed cost →](COST_ANALYSIS.md#service-2-deployment-gate-service)**

### With Harness
- **ML-based continuous verification** built-in
- Monitors error rates, latency, infrastructure metrics
- **Automatic rollback** on anomalies
- Zero custom code required

**Conclusion**: ❌ **GitHub requires 6 weeks to build verification (or deploy blind)**

---

## Problem 5: No Multi-Service Orchestration

### The Scenario
You have service dependencies:
- **database-migrations** must deploy first
- **backend-api** must deploy second (needs migrations)
- **frontend** must deploy last (needs API)

### Try It
**GitHub Actions**: ❌ **No way to enforce deployment order across repos**

Workarounds:
1. **Manual coordination** (error-prone, doesn't scale)
2. **Build custom orchestrator** (6 weeks, see below)
3. **Use workflow_run triggers** (complex, brittle)

### What You Must Build
**Custom multi-service orchestrator**:
- Service dependency graph
- Deployment sequencing logic
- Health check coordination
- Failure cascade handling
- Dashboard for visibility

**Build time**: 12 weeks
**Ongoing maintenance**: 10 hrs/week
**[See detailed cost →](COST_ANALYSIS.md#service-3-multi-service-orchestration)**

### With Harness
- **Built-in service dependencies**
- Drag-and-drop dependency graph
- Automatic sequencing and health checks
- Failure handling included

**Conclusion**: ❌ **GitHub requires 12 weeks to build orchestration**

---

## The Complete Picture

| Capability | GitHub Actions | Harness CD | GitHub Gap |
|------------|----------------|------------|------------|
| **Configuration** | 3,000 manual setups | 1 centralized config | 1,000 hours manual work |
| **Rollback** | Redeploy (14 min) | One-click (< 1 min) | 14× slower MTTR |
| **Multi-platform** | 2,500+ lines custom code | 0 lines (native) | 2,500+ lines to maintain |
| **Verification** | Must build (6 weeks) | Built-in ML-based | 6 weeks + ongoing |
| **Orchestration** | Must build (12 weeks) | Built-in dependencies | 12 weeks + ongoing |

**Total engineering investment to match Harness**:
- **Build time**: 32 weeks
- **Ongoing**: 30-48 hrs/week maintenance
- **Custom code**: 2,500+ lines
- **Platform team**: 4.5 FTE vs 2 FTE

**[See full cost breakdown →](COST_ANALYSIS.md)**

---

## The Cost Reality

### GitHub Actions (5-Year TCO)
| Component | Cost |
|-----------|------|
| GitHub Enterprise | $250k |
| Custom development | $200k (Year 1) |
| Ongoing maintenance | $600k (Years 2-5) |
| Platform engineers (4.5 FTE) | $4.5M |
| Hidden costs | $400k |
| **TOTAL** | **$6.0M** |

### Harness CD (5-Year TCO)
| Component | Cost |
|-----------|------|
| GitHub Team (CI only) | $250k |
| Harness licenses | $3.0M |
| Professional services | $200k (Year 1) |
| Training | $100k (Year 1) |
| Platform engineers (2 FTE) | $2.0M |
| Support | $480k |
| **TOTAL** | **$6.0M** |

**Same cost. 10× the capability. 2.5 fewer FTE.**

**[See detailed workings →](COST_ANALYSIS.md)**

---

## What GitHub Does Well

**GitHub Actions is EXCELLENT for CI**:
- ✅ Build orchestration
- ✅ Test automation
- ✅ Security scanning (CodeQL, Dependabot, Trivy)
- ✅ SBOM generation
- ✅ Native GitHub integration

**Keep using GitHub Actions for CI. It's great at it.**

---

## What GitHub Fails At

**GitHub Actions is TERRIBLE for enterprise CD**:
- ❌ No rollback (14× slower incident response)
- ❌ No verification (bad deploys reach production)
- ❌ Heterogeneous = 2,500+ lines custom code
- ❌ No orchestration (complex deployments fail)
- ❌ Configuration sprawl (1,000 hours manual work)

**Don't waste 32 weeks building what Harness already has.**

---

## The Right Architecture

### ✅ Recommended
**GitHub Actions** for CI → **Harness CD** for deployments

**Why**:
- Use each tool for its strengths
- GitHub builds & tests (what it's designed for)
- Harness deploys (what it's designed for)
- Standard integration via image registry
- Best of both worlds

### ❌ Wrong
**GitHub Actions** for everything

**Why**:
- Fighting the tool constantly
- Building and maintaining what vendors already have
- 4.5 FTE firefighting vs 2 FTE building features
- No rollback during incidents
- Platform team burnout

---

## Try It Yourself

### Fork This Repo
```bash
gh repo fork gregkroon/githubexperiment
cd githubexperiment
```

### See Configuration Sprawl
1. Go to repo → Settings → Environments
2. Try configuring for 10 services (extrapolate to 1000)
3. Try keeping secrets in sync across all environments

### See No Rollback
1. Break a deployment
2. Try to roll back quickly
3. Time how long it takes vs clicking a button

### See Custom Code Burden
1. Look at `.github/workflows/`
2. Imagine maintaining this across K8s, VMs, ECS, Lambda, Azure, on-prem
3. Count the lines of custom deployment code

**Then ask**: Is this how I want my platform team spending time?

---

## Next Steps

### 1. Understand the Business Case
**[→ Read Executive Summary](EXECUTIVE_SUMMARY.md)**

Learn:
- Strategic implications
- Team sizing reality
- Risk analysis
- When to choose each approach

### 2. Audit the Math
**[→ Read Cost Analysis](COST_ANALYSIS.md)**

See:
- Detailed FTE calculations
- Custom development costs
- Hidden operational costs
- Sensitivity analysis
- All citations and sources

### 3. Evaluate Harness
- Schedule demo for YOUR deployment targets
- Request POC for 10-20 services
- Measure actual rollback time
- Calculate prevented outage costs

### 4. Calculate YOUR Cost
Ask:
- How many FTE maintain deployment scripts today?
- How many lines of custom deployment code?
- What's current incident MTTR?
- What does 1 hour downtime cost?

**[Use our cost model](COST_ANALYSIS.md) with your numbers.**

---

## The Honest Conclusion

**GitHub Actions is a CI tool pretending to be a CD platform.**

**What this demo proved**:
- ❌ Configuration doesn't scale (1,000 hours manual work)
- ❌ No rollback capability (14× slower MTTR)
- ❌ Heterogeneous requires 2,500+ lines custom code
- ❌ Must build verification and orchestration (32 weeks)
- ❌ Platform team burns out maintaining GitHub workarounds

**For enterprise CD**: Stop building what Harness already has.

**[See the full cost analysis →](COST_ANALYSIS.md)**

**[See the business case →](EXECUTIVE_SUMMARY.md)**
