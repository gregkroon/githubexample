# GitHub Actions for Enterprise CD: Hands-On Demo

**Watch GitHub Actions fail at enterprise deployment in real-time.**

**Time**: 20 minutes
**Outcome**: See the 8 critical gaps firsthand

---

## What You'll See

Walk through a **real, working GitHub Actions implementation** and experience the eight gaps that make it unsuitable for enterprise CD:

1. ❌ **Configuration sprawl** (3,000 environments manually configured)
2. ❌ **No rollback** (redeploy takes 5-15 min vs Harness < 1 min)
3. ❌ **Heterogeneous = custom code** (2,500+ lines across 6 platforms)
4. ❌ **No deployment verification** (bad deploys reach production)
5. ❌ **No multi-service orchestration** (can't enforce order)
6. ❌ **No database DevOps** (custom Liquibase/Flyway, no safe rollback)
7. ❌ **No release management** (no calendaring, blackout windows, manual gates)
8. ❌ **Supply chain vulnerability** (15,000 mutable marketplace dependencies)

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

**[See cost details →](EXECUTIVE_SUMMARY.md#appendix-cost-calculations)**

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

**[See cost details →](EXECUTIVE_SUMMARY.md#appendix-cost-calculations)**

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

**[See cost details →](EXECUTIVE_SUMMARY.md#appendix-cost-calculations)**

### With Harness
- Built-in service dependencies
- Drag-and-drop dependency graph
- Automatic sequencing
- Failure handling included

**Conclusion**: ❌ **12 weeks to build orchestration**

---

## Problem 6: No Database DevOps

### The Scenario
Deploy backend API with new database schema. How do you:
- Version database changes?
- Deploy schema migrations safely?
- Roll back database changes if deployment fails?
- Coordinate app + database deployment order?

### Try It
**GitHub Actions**: ❌ **No native database DevOps**

### What You Must Build
**Custom database deployment pipeline**:
```yaml
# Each service needs custom Liquibase/Flyway workflow
- name: Database Migration
  run: |
    # Install Liquibase/Flyway
    # Configure connection strings
    # Run migrations
    # Hope nothing breaks
    liquibase update --changeLogFile=db/changelog.xml

# Problems:
# ❌ No rollback capability (DB changes often irreversible)
# ❌ No verification (did migration succeed?)
# ❌ No coordination with app deployment
# ❌ No approval gates for schema changes
# ❌ Manual sequencing (DB first, then app)
```

**Custom scripts required** (~200 lines per service):
- Connection management
- Migration orchestration
- Error handling
- Rollback procedures (manual)
- Health checks

**Build**: 3-4 weeks
**Maintenance**: 4-6 hrs/week
**Risk**: Database changes with no safe rollback path

### With Harness Database DevOps
- ✅ Native Liquibase/Flyway integration
- ✅ Automated rollback for schema changes
- ✅ Database deployment verification
- ✅ Coordinated app + DB deployments
- ✅ Approval workflows for schema changes
- ✅ Multi-environment promotion (dev → staging → prod)
- ✅ Drift detection (schema vs actual DB state)

**Example**: Deploy backend API with database migration
```
1. Harness runs DB migration (dev environment)
2. Verifies migration success
3. Waits for approval
4. Deploys application
5. If app fails → automatically rolls back DB + app
6. Full audit trail of all schema changes
```

### The Database Deployment Reality

**GitHub Actions approach**:
```yaml
# Service 1: payment-service
- Manually write Liquibase workflow
- Custom rollback scripts
- No verification

# Service 2: user-service
- Duplicate Liquibase workflow
- Different connection config
- Configuration drift

# Service 3: order-service
- Uses Flyway instead
- Completely different workflow
- No consistency
```

**Result**: 1000 services × 200 lines = **200,000 lines of DB deployment code**

### With Harness
- One centralized DB deployment template
- Apply to all 1000 services
- Automatic rollback
- Consistent everywhere

**Conclusion**: ❌ **3-4 weeks to build + 200,000 lines custom code**

---

## Problem 7: No Release Management

### The Scenario
Enterprise deployment governance requirements:
- **Blackout windows**: No deployments on Friday after 5pm, holidays, tax season
- **Change board approval**: Manual approval from CAB for production deployments
- **Multi-service release coordination**: Deploy 10 microservices together with manual gates
- **Deployment calendar**: Visibility into what's deploying when across 1000 services
- **Manual activities**: Integrate manual steps (database backups, vendor notifications)

### Try It
**GitHub Actions**: ❌ **No native release management**

### What You Must Build

**Custom release management system**:

#### 1. Deployment Calendar/Blackout Windows
```yaml
# Each workflow needs custom calendar logic
- name: Check Deployment Window
  run: |
    # Check if Friday after 5pm
    if [[ $(date +%u) -eq 5 ]] && [[ $(date +%H) -ge 17 ]]; then
      echo "Friday evening - deployment blocked"
      exit 1
    fi

    # Check holidays (must maintain holiday calendar)
    if grep -q "$(date +%Y-%m-%d)" holidays.txt; then
      echo "Holiday - deployment blocked"
      exit 1
    fi

    # Check blackout periods (tax season, etc)
    # Custom logic for each business requirement
```

**Problems**:
- ❌ Must duplicate across 1000 workflows
- ❌ Holiday calendar maintenance burden
- ❌ Configuration drift (some repos forget to add check)
- ❌ No centralized visibility

#### 2. Manual Approval Gates
```yaml
# GitHub Environments provide basic approvals
# BUT: No integration with external systems
environment: production  # Requires manual click in GitHub UI

# Problems:
# ❌ No integration with ServiceNow/Jira change boards
# ❌ No approval delegation
# ❌ No approval workflows (multi-level approvals)
# ❌ Approvals buried in GitHub UI
```

#### 3. Cross-Service Release Orchestration
```yaml
# Want to deploy 10 services together with manual gates between?
# ❌ IMPOSSIBLE in GitHub Actions

# Workaround: Manual coordination
# 1. Deploy service-1, wait for manual verification
# 2. Deploy service-2, wait for manual verification
# 3. Repeat 8 more times
# 4. Pray nothing goes wrong

# OR build custom orchestrator (12+ weeks)
```

#### 4. Manual Activity Integration
```yaml
# Want to integrate manual steps?
# - Take database backup before schema migration
# - Notify vendor of upcoming deployment
# - Confirm load balancer health after deploy

# GitHub Actions:
# ❌ No manual step support
# ❌ Can't pause workflow for human action
# ❌ Can't integrate with external ticketing systems
# ❌ Can't track manual activity completion
```

### What You Must Build
**Custom release orchestration platform**:
- Deployment calendar service
- Holiday/blackout window management
- Multi-service release coordinator
- Manual approval workflow engine
- External system integrations (ServiceNow, Jira, PagerDuty)
- Release visibility dashboard

**Build**: 8-12 weeks
**Maintenance**: 8-12 hrs/week
**Risk**: Friday 5pm production disasters

### With Harness Release Management

#### ✅ Deployment Calendaring
- Define blackout windows centrally (Friday 5pm, holidays, tax season)
- Apply to all services instantly
- Auto-block deployments during blackout periods
- Maintain holiday calendar once

#### ✅ Manual Approval Gates
- Native ServiceNow/Jira integration
- Change board approval workflows
- Multi-level approval chains
- Approval delegation
- External approver notifications

#### ✅ Cross-Service Release Orchestration
```
Release: "Q1 Commerce Update"
├─ Stage 1: Database migrations
│  └─ Manual gate: DBA approval
├─ Stage 2: Backend services (parallel)
│  ├─ payment-service
│  ├─ user-service
│  └─ order-service
│  └─ Manual gate: Smoke test verification
├─ Stage 3: Frontend services
│  ├─ web-app
│  └─ mobile-api
│  └─ Manual gate: QA sign-off
└─ Stage 4: Cache invalidation
   └─ Manual activity: Notify support team
```

#### ✅ Manual Activity Integration
- Pause deployment for manual steps
- Integrate with ticketing systems
- Track manual activity completion
- Timeout handling
- Audit trail of all manual actions

#### ✅ Release Visibility
- Centralized deployment calendar
- See all scheduled deployments across 1000 services
- Filter by environment, team, time window
- Identify deployment conflicts
- Release impact analysis

### The Enterprise Reality

**Common scenarios GitHub Actions CANNOT handle**:

1. **Holiday Freeze**: "No deployments December 15 - January 5"
   - GitHub: Update 1000 workflows manually
   - Harness: Set blackout window once

2. **Multi-Service Release**: Deploy 10 microservices with manual gates
   - GitHub: Manual coordination, error-prone
   - Harness: Drag-and-drop release pipeline

3. **Change Board Approval**: Production deploy needs CAB approval
   - GitHub: Click approve in GitHub UI (not integrated)
   - Harness: ServiceNow integration, automated workflow

4. **Manual Database Backup**: Before schema migration
   - GitHub: Can't pause workflow for manual action
   - Harness: Manual activity step with timeout

5. **Friday 5pm Block**: Prevent weekend incidents
   - GitHub: Custom calendar logic in each workflow
   - Harness: Centralized deployment window policy

### Real-World Incident

**What happens without release management**:

```
Friday 5:30pm: Developer pushes payment-service update
GitHub Actions: ✅ All checks pass, deploying to production
5:45pm: Deployment completes
6:00pm: Error rates spike to 15%
6:15pm: On-call paged, team scrambling
6:30pm: Realize payment processor integration broken
7:00pm: Trying to rollback (14 min redeploy process)
7:15pm: Rollback fails (dependency on database migration)
8:00pm: All hands on deck, weekend ruined
```

**With Harness**:
```
Friday 5:30pm: Developer pushes payment-service update
Harness: ❌ Deployment blocked (Friday evening blackout window)
Message: "Deployments blocked after 5pm Friday. Schedule for Monday 9am."
Weekend: Safe
```

**Conclusion**: ❌ **8-12 weeks to build release management + ongoing operational risk**

---

## Problem 8: Supply Chain Vulnerability (Marketplace Attack Surface)

### The Scenario
**Aqua Security Trivy Breach (2024)**: Attacker force-pushes credential stealer to trusted GitHub Action tag.

**Your infrastructure**:
- 1000 services × 15 marketplace actions = **15,000 mutable dependencies**
- Each action runs with production AWS keys, K8s tokens, GitHub PATs
- **One compromised action = full infrastructure breach**

### Try It
**Look at any workflow in this repo**:
```yaml
# .github/workflows/user-service.yml
- uses: aquasecurity/trivy-action@v0.24.0  # ⚠️ MUTABLE TAG
```

**The attack**:
1. Attacker compromises Trivy maintainer account
2. Force-pushes malicious code to `v0.24.0` tag
3. Next workflow run executes credential harvester
4. Attacker gets: AWS keys, K8s tokens, GitHub tokens
5. Lateral movement to production databases

### The "Pin to SHA" Defense

**Security team says**: "Pin to SHA256 digest"
```yaml
- uses: aquasecurity/trivy-action@d9cd5b1c8ee3c92e2b2c7b1c3e4f5a6b7c8d9e0f
```

**The operational reality**:
- 1000 services × 15 actions = **15,000 SHA pins**
- Actions update monthly = **15,000 digest updates/month**
- Dependabot creates **15,000 PRs/month**
- Security review: 10 min/PR = **2,500 hours/month**
- **Requires 1.4 FTE just reviewing Dependabot PRs**

**Result**:
- ❌ Reviews become rubber-stamp
- ❌ Updates lag by months
- ❌ Vulnerabilities persist
- ❌ Attack surface grows

### What You Must Build
**Custom marketplace governance system**:
- SHA pin enforcement
- Automated Dependabot PR review
- Vulnerability scanning
- Update tracking
- Compliance reporting

**Build**: 6-8 weeks
**Maintenance**: 1.4 FTE ongoing
**Risk**: Still exposed to marketplace attacks

### With Harness: Governed Template Library

**No marketplace exposure**:
```yaml
# Pipeline references internal vetted template
pipeline:
  stages:
    - stage:
        steps:
          - step:
              type: SecurityScan
              spec:
                template: trivy-enterprise-v2  # Internal template
```

**Security Architecture**:
```
┌─────────────────────────────────────┐
│  Harness Control Plane              │
│  ┌───────────────────────────────┐  │
│  │  Internal Template Library    │  │
│  │  - Platform team vets         │  │
│  │  - Immutable versions         │  │
│  │  - Zero marketplace exposure  │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  Policy-as-Code (OPA)         │  │
│  │  - Block non-approved         │  │
│  │  - Enforce governance         │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Advantages**:
- ✅ **50 templates** vs 15,000 marketplace actions
- ✅ **50 updates/month** vs 15,000
- ✅ **8 hrs/month** security review vs 2,500 hrs
- ✅ **0.05 FTE** vs 1.4 FTE
- ✅ **Zero marketplace exposure**
- ✅ **OPA policy enforcement** (blocks non-approved templates)
- ✅ **Centralized updates** (update once, propagates to 1000 services)

### Real-World Impact

**Breach cost if Trivy attack succeeded**:
- AWS credentials harvested from 1000 CI runners
- Lateral movement to production K8s clusters
- Database exfiltration
- Ransomware deployment
- **Cost: $50M - $500M** (IBM 2024 Cost of Data Breach)

**GitHub Actions**: One force-push away from SolarWinds-scale breach

**Harness**: Architecturally immune (no marketplace dependencies)

**Conclusion**: ❌ **15,000 attack vectors + 1.4 FTE ongoing + $50M+ breach risk**

**[See ADR-001 for complete security analysis →](ADR-001-rejecting-pure-gitops-for-composite-releases.md#security-rationale-rejecting-the-open-marketplace-model)**

---

## The Complete Picture

| Capability | GitHub | Harness | Gap |
|------------|--------|---------|-----|
| **Configuration** | 3,000 manual | 1 centralized | 1,000 hours work |
| **Rollback** | Redeploy (14 min) | One-click (< 1 min) | 14× slower MTTR |
| **Multi-platform** | 2,500+ lines | 0 lines (native) | 2,500+ lines maintenance |
| **Verification** | Build it (6 weeks) | Built-in ML | 6 weeks + ongoing |
| **Orchestration** | Build it (12 weeks) | Built-in | 12 weeks + ongoing |
| **Database DevOps** | Custom Liquibase (4 weeks) | Native with rollback | 200,000 lines DB code |
| **Release Management** | Build it (10 weeks) | Native calendaring/gates | Friday 5pm disasters |
| **Supply Chain** | 15,000 mutable deps | Governed templates | 1.4 FTE + $50M breach risk |

**Total investment to match Harness**:
- **52 weeks build**
- **51-74 hrs/week** ongoing maintenance
- **202,500+ lines** custom code
- **6.4 FTE** vs 2 FTE

**[See full cost breakdown →](EXECUTIVE_SUMMARY.md#appendix-cost-calculations)**

---

## The Cost Reality

| | GitHub Actions | Harness CD |
|---|---|---|
| **Licenses** | $250k (5yr) | $3,230k (5yr) |
| **Custom dev** | $1,100k | $300k (Year 1 only) |
| **Platform team** | $6,400k (6.4 FTE) | $2,000k (2 FTE) |
| **Hidden costs** | $1,000k | $0 |
| **Security review** | $280k (1.4 FTE × 1yr) | $0 |
| **TOTAL (5yr)** | **$9,030k** | **$5,530k** |

**Harness: $3,500k cheaper + 10× capability**

**[See detailed workings →](EXECUTIVE_SUMMARY.md#appendix-cost-calculations)**

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
- ❌ Heterogeneous = 202,500+ lines custom code
- ❌ No orchestration (complex deployments fail)
- ❌ No database DevOps (200,000 lines DB deployment code)
- ❌ No release management (Friday 5pm disasters, no blackout windows)
- ❌ Supply chain vulnerability (15,000 mutable marketplace actions, $50M+ breach risk)
- ❌ Configuration sprawl (1,000 hours manual work)

**Don't waste 52 weeks building what Harness has**

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

**[See detailed security analysis →](EXECUTIVE_SUMMARY.md#appendix-security-bypass-analysis)**

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

### 2. See All Details
**[→ EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)** - Includes appendices with:
- Detailed cost calculations and FTE breakdowns
- Security bypass analysis (what GitHub Enterprise can/cannot prevent)
- Heterogeneous reality analysis

### 3. Evaluate Harness
- Schedule demo for YOUR deployment targets
- Request POC for 10-20 services
- Measure actual rollback time
- Calculate prevented outage costs

### 4. Calculate YOUR Cost
- How many FTE maintain deployment scripts?
- How many lines of custom deployment code?
- Current incident MTTR?
- What does 1 hour downtime cost?

**[Use our cost model](EXECUTIVE_SUMMARY.md#appendix-cost-calculations) with your numbers**

---

## The Honest Conclusion

**GitHub Actions is a CI tool pretending to be a CD platform.**

**What this demo proved**:
- ❌ Configuration doesn't scale (1,000 hours manual)
- ❌ No rollback (14× slower MTTR)
- ❌ Heterogeneous = 202,500+ lines custom code
- ❌ Must build verification, orchestration, DB DevOps, release mgmt & supply chain governance (52 weeks)
- ❌ No deployment governance (Friday 5pm production disasters)
- ❌ Supply chain vulnerability (15,000 mutable dependencies, $50M+ breach risk)
- ❌ Platform team burns out maintaining workarounds

**For enterprise CD**: Stop building what Harness already has.

**[See business case →](EXECUTIVE_SUMMARY.md)** | **[See detailed appendices →](EXECUTIVE_SUMMARY.md#appendix-cost-calculations)**
