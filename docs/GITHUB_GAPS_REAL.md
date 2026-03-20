# GitHub Shortcomings - REAL Examples from Running Pipeline

**This document shows ACTUAL gaps in the running CI/CD pipeline.**

After watching the workflows run at https://github.com/gregkroon/githubexample/actions, here are the **obvious shortcomings** compared to Harness.

> 💡 **[Why GitHub "Templates" Aren't Like Harness →](WHY_GITHUB_TEMPLATES_FAIL.md)** - Using the actual workflows that ran as proof

---

## Gap 1: Deployment Succeeds But Service Has High Error Rate ❌

### What Just Happened (GitHub)

The CD workflow:
1. ✅ Deployed the service
2. ✅ Pod started successfully
3. ✅ Health check passed (`GET /health` returned 200)
4. ✅ Smoke tests passed
5. ✅ **Deployment marked as SUCCESS**

**But what if the service has a bug that causes 50% of requests to fail?**

### The Problem

The smoke tests only check:
```yaml
# From .github/workflows/cd-user-service.yml
- curl -f http://localhost:3000/health     # ✅ Passed
- curl -f http://localhost:3000/api/users  # ✅ Passed
- curl -f http://localhost:3000/metrics    # ✅ Passed
```

**These are basic connectivity tests, NOT production metrics analysis.**

If you deployed code that:
- Crashes on 50% of requests
- Has 10x higher latency
- Leaks memory
- Has race conditions

**GitHub's workflow would still show SUCCESS ✅**

Because the smoke tests only verify the service responds, not that it's healthy under real load.

### What Harness Does Differently

```yaml
# Harness Continuous Verification
verification:
  type: Auto  # ML-based anomaly detection
  sensitivity: MEDIUM
  duration: 10m

  metrics:
    - query: error_rate
      threshold: < 1%
      comparison: baseline  # Compare to previous version

    - query: latency_p99
      threshold: < 500ms
      comparison: baseline

    - query: memory_usage
      threshold: < 80%

  failureStrategy:
    action: ROLLBACK
    notification: ["#incidents"]
```

**Harness would:**
1. Deploy to 25% of traffic (canary)
2. Monitor error rate, latency, memory for 10 minutes
3. Compare to the previous version's baseline
4. **Detect the 50% error rate**
5. **Automatically rollback**
6. Notify the team

**Total time to detect and rollback: < 5 minutes**

### In GitHub

**You'd find out when:**
- Users report errors
- Monitoring alerts fire (if you set them up)
- Someone checks the logs

**Time to detect: 30 minutes to hours**

**Time to rollback: 10-15 minutes (manual process)**

---

## Gap 2: No Approval Gates for Production ❌

### What Just Happened (GitHub)

Look at the CD workflow that just ran:

```yaml
# .github/workflows/cd-user-service.yml
on:
  workflow_run:
    workflows: ["CI - User Service"]
    types: [completed]
    branches: [main]
```

**The deployment to "production" (Kind cluster) happened AUTOMATICALLY** as soon as CI passed.

**No approval required. No human verification. Just auto-deploys.**

### Why This Is a Problem

In a real enterprise:
- Production deployments need platform engineer approval
- Security team must sign off on changes
- Business stakeholders verify timing (not during peak hours)

**GitHub's approach:**
```
Code merged → CI passes → IMMEDIATELY deploys to production
```

**No stopping it. No approval. No verification.**

### Adding GitHub Environments Helps... But

You can add GitHub Environments:

```yaml
jobs:
  deploy:
    environment: production  # Requires approval
```

**But then:**
- ❌ Must configure in EVERY repository (1000 repos)
- ❌ Approvers configured per-repo
- ❌ No conditional approval (can't say "if high risk, need 3 approvers")
- ❌ No integration with external approval systems (ServiceNow, JIRA)

### What Harness Does

```yaml
# Configured ONCE for ALL services
approval:
  type: HarnessApproval
  spec:
    approvers:
      userGroups: ["platform-engineers", "security-team"]
    minimumCount: 2

    # Conditional logic
    approvalCriteria:
      - condition: ${deployment.risk} == HIGH
        minimumCount: 3
        includeGroups: ["security-team"]

      - condition: ${deployment.size} == LARGE
        includeGroups: ["vp-engineering"]

    timeout: 24h
    autoReject: true
```

**Benefits:**
- ✅ Configured once, applies to all 1000 services
- ✅ Conditional approval based on risk
- ✅ Integration with external systems
- ✅ Auto-reject if not approved within 24h

---

## Gap 3: No One-Click Rollback ❌

### What Happens When Deployment Fails

Let's say the deployment you just watched had a critical bug.

**In GitHub, to rollback:**

1. **Find the previous good commit:**
```bash
git log --oneline
```

2. **Revert or create a new commit:**
```bash
git revert HEAD
# OR
git checkout <previous-sha> -- services/user-service/
git commit -m "Rollback to previous version"
```

3. **Push to trigger CI/CD again:**
```bash
git push origin main
```

4. **Wait for CI workflow (7 minutes)**
5. **Wait for CD workflow (4 minutes)**

**Total time to rollback: 11+ minutes**

**And that's assuming:**
- You know which commit was good
- The previous version builds successfully
- Tests still pass
- No other changes snuck in

### What Harness Does

**In Harness UI:**
1. Click "Rollback" button
2. Confirm

**Total time: < 60 seconds**

**Harness automatically:**
- Knows the previous version
- Redeploys it immediately
- No need to rebuild (uses existing image)
- No need to re-run tests
- Updates traffic routing

**Plus, Harness can auto-rollback:**
```yaml
verification:
  failureStrategy:
    action: ROLLBACK  # Automatic
```

If metrics spike, Harness rolls back without human intervention.

---

## Gap 4: No Deployment Windows Enforcement ❌

### What Just Happened

The CD workflow ran **right now** - whenever CI completed.

**Could be:**
- Friday at 6pm ❌
- During a production incident ❌
- During peak traffic hours ❌
- On a holiday ❌

**GitHub has NO concept of deployment windows.**

### The Real-World Problem

The deployment that just ran would happen even if:
- It's 11:59pm on Friday
- There's an active P1 incident
- It's Black Friday (peak load)
- The on-call engineer is offline

### To Add Deployment Windows in GitHub

You'd need custom logic in the workflow:

```yaml
# Add this to EVERY workflow
- name: Check deployment window
  run: |
    HOUR=$(TZ='America/New_York' date +%H)
    DAY=$(TZ='America/New_York' date +%u)

    if [ $DAY -ge 5 ]; then
      echo "❌ No deployments on weekends"
      exit 1
    fi

    if [ $HOUR -lt 9 ] || [ $HOUR -ge 17 ]; then
      echo "❌ Only 9am-5pm EST"
      exit 1
    fi
```

**Problems:**
- ❌ Must add to 1000 workflows
- ❌ No holiday calendar (manual updates)
- ❌ No freeze period support
- ❌ No override mechanism for emergencies

### What Harness Does

```yaml
# Configured ONCE
deploymentWindow:
  environment: production
  allowedDays: ["Mon", "Tue", "Wed", "Thu"]
  allowedHours: "09:00-17:00"
  timezone: "America/New_York"

  holidays:
    - "2026-12-25"
    - "2026-07-04"

  freezePeriods:
    - name: "Holiday Freeze"
      start: "2026-12-20"
      end: "2026-01-02"
    - name: "Black Friday"
      start: "2026-11-25"
      end: "2026-11-29"

  emergencyOverride:
    approvers: ["vp-engineering"]
```

**Deployment attempt at Friday 6pm:**
```
❌ Deployment blocked: Outside deployment window
Next available: Monday 9:00 AM EST
Emergency override: Contact VP Engineering
```

---

## Gap 5: No Incident-Aware Deployments ❌

### What Just Happened

The CD workflow deployed regardless of production health.

**Even if:**
- There's an active P1 incident ❌
- Error rates are spiking ❌
- The site is partially down ❌

**GitHub doesn't know, doesn't care, deploys anyway.**

### The Real-World Disaster Scenario

1. 2:00 PM - Payment service starts failing (P1 incident)
2. 2:15 PM - Engineer investigating root cause
3. 2:30 PM - Someone merges an unrelated PR to user-service
4. 2:31 PM - **CD workflow auto-deploys during active incident**
5. 2:32 PM - Now TWO services are having issues
6. 2:45 PM - Incident escalates to P0

**The deployment made things worse during an incident.**

### What Harness Does

```yaml
# Integrated with incident management
deploymentPolicy:
  blockOnIncidents: true
  incidentSources:
    - type: PagerDuty
      severity: ["P1", "P2"]
    - type: OpsGenie
      priority: ["P1"]
```

**Deployment attempt during incident:**
```
❌ Deployment blocked: Active P1 incident

Incident: Payment Service Outage
Status: Investigating
Started: 2:00 PM
Owner: @john-doe

Deployments will resume when incident is resolved.
Override: Contact Incident Commander
```

**Harness queries PagerDuty/OpsGenie in real-time** before deploying.

---

## Gap 6: No Multi-Service Orchestration ❌

### What You Can't See (Yet)

The workflow you just watched deployed ONE service.

**But what if:**
- User-service depends on Auth-service
- Auth-service depends on Database-migrations

**Correct order:**
1. Database-migrations
2. Auth-service
3. User-service

### What GitHub Doesn't Do

There's **no way to enforce deployment order** across multiple repos/services.

**You could:**
- Manually coordinate ("deploy auth first, then user")
- Build a custom orchestrator (4-6 weeks of engineering)
- Use workflow dependencies (but each service still triggers independently)

**Result at scale:**
- Someone deploys user-service before auth-service
- User-service tries to authenticate against old auth API
- **Deployment succeeds but service is broken**

### What Harness Does

```yaml
# Multi-service pipeline
pipeline:
  stages:
    - parallel: false  # Sequential
      stages:
        - stage:
            name: Deploy Database Migrations
            service: database-migrations

        - stage:
            name: Deploy Auth Service
            service: auth-service
            dependsOn: [database-migrations]

        - stage:
            name: Deploy User Service
            service: user-service
            dependsOn: [auth-service, database-migrations]
```

**Harness ensures:**
- ✅ Correct deployment order
- ✅ Waits for previous stage to succeed
- ✅ Rolls back entire chain on failure
- ✅ Tracks dependencies automatically

---

## Gap 7: Developers Can Bypass Security ❌

### The CRITICAL Governance Problem

**In GitHub, workflow files live IN THE DEVELOPER'S REPO.**

This means developers can:
- ✅ Edit `.github/workflows/ci-user-service.yml`
- ✅ Comment out security scanning
- ✅ Remove approval gates
- ✅ Skip SBOM generation
- ✅ Commit and push

**This is the workflow that just ran** - look at it:
[.github/workflows/ci-user-service.yml](../.github/workflows/ci-user-service.yml)

### The Bypass Is Easy

A developer can edit the file and:

**Bypass 1: Skip security scanning**
```yaml
jobs:
  security-scan:
    continue-on-error: true  # ← Never fail, even with CVEs
```

**Bypass 2: Remove approval gate**
```yaml
  deploy-production:
    # environment: production  # ← Commented out, no approval needed
```

**Bypass 3: Skip SBOM**
```yaml
# jobs:
#   sbom:  # ← Entire job deleted
```

### What GitHub Provides (Doesn't Scale)

**Branch Protection + CODEOWNERS**:
- Requires platform team to review workflow changes
- Across ALL 1000 repos
- Catches obvious bypasses
- **Misses subtle ones** (continue-on-error, exit-code: 0)

**At 1000 repos**: Manual review doesn't scale.

### What Harness Does

**Templates live OUTSIDE repos** (in Harness platform):

```yaml
# In Harness (NOT in developer's repo)
template:
  stages:
    - stage:
        name: Security
        locked: true  # ← DEVELOPERS CANNOT MODIFY
        spec:
          tests:
            - trivy_scan:
                required: true  # ← CANNOT skip
            - sbom:
                required: true  # ← CANNOT skip
```

**Developers reference template**:
```yaml
# In developer's repo
pipeline:
  templateRef: prod_deploy_v1  # ← Cannot modify template
```

**Result**: **Architecturally impossible to bypass security.**

> 📖 **[Full Analysis: Developer vs Platform Team →](DEVELOPER_VS_PLATFORM.md)**

---

## Gap 8: No Deployment Observability ❌

### Questions GitHub Can't Answer

After the workflow completes, try to answer these:

**Questions:**
1. Which version of user-service is running in production RIGHT NOW?
2. When was it deployed?
3. Who approved it?
4. What's the error rate compared to the previous version?
5. Which services were deployed in the last 24 hours?
6. What's the deployment success rate this week?
7. How many deployments failed and why?

**In GitHub:**
- ❌ No deployment dashboard
- ❌ No version tracking
- ❌ No deployment history
- ❌ No metrics comparison
- ❌ No DORA metrics

**You'd have to:**
- Check the Actions tab manually
- Parse workflow logs
- Query GHCR for image tags
- **Build your own dashboard (3 weeks of engineering)**

### What Harness Provides

**Harness Deployment Dashboard shows:**

```
┌─────────────────────────────────────────────────────────┐
│ Deployments (Last 24 hours)                            │
├─────────────────────────────────────────────────────────┤
│ user-service       v1.2.3  →  Production   ✅ 2:30 PM  │
│ auth-service       v2.1.0  →  Production   ✅ 1:15 PM  │
│ payment-service    v3.0.1  →  Staging      🔄 Running  │
│ database-migrations v1.5.2 →  Production   ❌ Failed   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ DORA Metrics (This Week)                               │
├─────────────────────────────────────────────────────────┤
│ Deployment Frequency:    23 deployments (avg 4.6/day)  │
│ Lead Time:               2.3 hours                     │
│ Change Failure Rate:     4.3% (1 of 23 failed)        │
│ MTTR:                    12 minutes                    │
└─────────────────────────────────────────────────────────┘
```

**Plus:**
- Click any deployment to see full details
- Compare metrics between versions
- See who approved what
- Track deployment trends over time

---

## Summary: GitHub vs Harness (Real Gaps)

| Capability | GitHub (What You Just Saw) | Harness |
|------------|---------------------------|---------|
| **Deployment Verification** | ❌ Basic smoke tests only | ✅ ML-based metrics analysis |
| **Automated Rollback** | ❌ Manual (11+ minutes) | ✅ One-click (< 1 minute) |
| **Approval Gates** | ❌ Per-repo configuration | ✅ Centralized policy |
| **Deployment Windows** | ❌ Not supported | ✅ Built-in with freeze periods |
| **Incident Awareness** | ❌ Deploys during incidents | ✅ Blocks on active incidents |
| **Multi-Service Order** | ❌ No orchestration | ✅ Dependency management |
| **🔴 Security Enforcement** | **❌ Developers can bypass** | **✅ Architecturally enforced** |
| **Deployment Dashboard** | ❌ None (build your own) | ✅ Built-in with DORA metrics |
| **Rollback on Bad Metrics** | ❌ Manual detection + rollback | ✅ Automatic |
| **Time to Rollback** | ❌ 11+ minutes | ✅ < 60 seconds |
| **Deployment Observability** | ❌ Parse logs manually | ✅ Real-time dashboard |

---

## What You Can Do Right Now

### See the Gaps Yourself

1. **Check the Actions tab**: https://github.com/gregkroon/githubexample/actions
   - See the workflows succeeded
   - Ask yourself: "What if the service had 50% errors?"
   - GitHub would still show ✅ SUCCESS

2. **Look for deployment approval**:
   - There wasn't one
   - It auto-deployed to "production"
   - No approval gate, no verification

3. **Try to find what's deployed**:
   - Which version is running?
   - When was it deployed?
   - What's the error rate?
   - GitHub can't tell you without custom tooling

4. **Simulate a rollback**:
   - How would you roll back right now?
   - You'd need to revert code and wait 11+ minutes
   - No one-click solution

---

## The Harsh Reality

**GitHub's CI/CD (what you just watched):**
- ✅ Builds and deploys successfully
- ✅ Runs security scans
- ✅ Tests pass
- ❌ **But doesn't prevent bad deployments**
- ❌ **No governance or safety nets**
- ❌ **No deployment observability**
- ❌ **Manual rollback process**

**At 1 service: Manageable**

**At 1000 services:**
- Manual rollbacks = chaos
- No deployment windows = Friday 6pm disasters
- No incident awareness = incidents escalate
- No observability = "what's deployed?" requires custom tooling

**This is why the 5-year cost is $5.8M (GitHub) vs $3.9M (Harness).**

The workflows you just watched prove **everything works** - but they also prove **critical capabilities are missing**.

---

**[← Back to Live Deployment](LIVE_DEPLOYMENT.md)** | **[See Workarounds](GITHUB_WORKAROUNDS.md)** | **[Full Comparison](HARNESS_COMPARISON.md)**
