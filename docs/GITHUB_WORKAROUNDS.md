# GitHub Workarounds for Deployment-Time Governance

**Can GitHub solve deployment-time governance issues? YES - but at a cost.**

This document shows EXACTLY how to workaround each deployment governance gap using GitHub features, and the operational cost of each workaround.

---

## Summary Table

| Governance Requirement | GitHub Solution | Effort | Operational Burden | Harness Equivalent |
|------------------------|-----------------|--------|-------------------|-------------------|
| **Production approval** | ✅ GitHub Environments | Easy | 🟡 Medium (3000 configs) | Built-in (centralized) |
| **Metrics-based verification** | ⚠️ Custom Deployment Protection Rule | 3-4 weeks | 🔴 High (maintain service) | Built-in (AI/ML) |
| **Soak time enforcement** | ⚠️ Custom logic + Actions | 1-2 weeks | 🟡 Medium | Built-in (policy) |
| **Deployment windows** | ⚠️ Custom logic + Actions | 1 week | 🟡 Medium | Built-in (policy) |
| **Incident blocking** | ⚠️ Custom integration | 2-3 weeks | 🔴 High | Built-in (integration) |
| **Multi-service orchestration** | ⚠️ Custom orchestrator | 4-6 weeks | 🔴 High | Built-in (pipelines) |

**Bottom line**: Everything is POSSIBLE, but requires custom engineering and ongoing maintenance.

---

## 1. ✅ Prevent Deploying to Production Without Approval

### GitHub Solution: GitHub Environments (Built-in!)

This is the ONE thing GitHub handles well.

```yaml
# Configure in GitHub UI or via API
Environment: production
  Protection Rules:
    - Required reviewers: 2
    - Reviewer groups: ["platform-engineers", "security-team"]
    - Wait timer: 0 minutes
    - Deployment branches: ["main", "release/*"]
```

**In workflow:**
```yaml
jobs:
  deploy-production:
    runs-on: ubuntu-latest
    environment: production  # ← Requires approval before proceeding
    steps:
      - name: Deploy to Kubernetes
        run: kubectl apply -f deployment.yaml
```

### How It Works
1. Developer triggers deployment to `production` environment
2. GitHub pauses workflow execution
3. Sends notification to required reviewers
4. Reviewers approve or reject via GitHub UI
5. Workflow proceeds only after approval

### ✅ Pros
- Built into GitHub (no custom code)
- Approval history tracked in GitHub
- Mobile app support for approvals

### ❌ Cons
- **Must configure in EVERY repository**
  - 1000 repos × 3 environments = 3000 configurations
  - Via API or Terraform (automation required)
  - Configuration drift over time
- **No centralized management**
  - Can't change approval rules for all repos at once
  - Each repo must be updated individually
- **Limited approval logic**
  - Can't require "at least 1 security AND 1 platform engineer"
  - Can't require approval based on deployment size/risk
  - Can't integrate with external approval systems (JIRA, ServiceNow)

### Cost
- **Setup**: 2 weeks (automation to configure 3000 environments)
- **Ongoing**: 1-2 hours/week (config updates, drift remediation)
- **Per-repo burden**: 10 minutes per repo for initial setup

### Harness Comparison
```yaml
# Harness: Configure ONCE for all services
template:
  approval:
    approvers:
      userGroups: ["platform-engineers", "security-team"]
    minimumCount: 2
    approvalCriteria:
      # Advanced logic GitHub doesn't support
      riskLevel: HIGH → require security-team
      deploymentSize: LARGE → require 3 approvers
```

**Verdict**: ✅ GitHub CAN do this, but distributed configuration is painful at scale.

---

## 2. ⚠️ Prevent Deploying Version That Increases Error Rates

### GitHub Solution: Custom Deployment Protection Rule (NEW!)

GitHub introduced [Deployment Protection Rules](https://docs.github.com/en/actions/deployment/protecting-deployments/creating-custom-deployment-protection-rules) that allow custom logic via GitHub Apps.

**How it works:**
1. Build a GitHub App with deployment protection rule endpoint
2. App receives webhook when deployment is requested
3. App queries production metrics (Prometheus, Datadog, etc.)
4. App approves or rejects deployment based on error rate
5. GitHub workflow proceeds or fails

### Implementation

**Step 1: Build the GitHub App**

```javascript
// deployment-protection-service/index.js
const express = require('express');
const axios = require('axios');
const app = express();

app.post('/api/deployment-protection', async (req, res) => {
  const { deployment, environment } = req.body;

  if (environment === 'production') {
    // Query Prometheus for current error rate
    const errorRate = await getPrometheusErrorRate(deployment.service);

    // Query staging metrics for comparison
    const stagingErrorRate = await getStagingErrorRate(deployment.service);

    // Reject if error rate increased by >50%
    if (errorRate > stagingErrorRate * 1.5) {
      return res.json({
        state: 'rejected',
        comment: `Error rate too high: ${errorRate}% (staging: ${stagingErrorRate}%)`
      });
    }
  }

  return res.json({
    state: 'approved',
    comment: 'Metrics look healthy'
  });
});

async function getPrometheusErrorRate(service) {
  const response = await axios.get(
    `http://prometheus:9090/api/v1/query?query=rate(http_requests_total{service="${service}",status=~"5.."}[5m])`
  );
  return response.data.data.result[0].value[1];
}
```

**Step 2: Configure GitHub Environment**

```bash
# Enable deployment protection rule for environment
gh api repos/myorg/user-service/environments/production/deployment-protection-rules \
  -X POST \
  -f app_id=12345 \
  -f integration_id=67890
```

**Step 3: Workflow automatically waits for approval**

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # ← Automatically invokes protection rule
    steps:
      - run: kubectl apply -f deployment.yaml
```

### ✅ Pros
- Flexible (can implement any logic)
- Integrated with GitHub UI
- Webhook-driven (real-time)

### ❌ Cons
- **Custom service to build and maintain** (3-4 weeks initial build)
- **Must configure per-environment** (3000 environments)
- **Operational burden**:
  - Service uptime critical (deployments block if down)
  - Metrics integration fragile (Prometheus, Datadog, etc.)
  - Debugging failures complex
  - No built-in ML or anomaly detection
- **No statistical analysis** (you write the threshold logic)
- **No historical comparison** (you build the database)

### Cost
- **Build**: 3-4 weeks (GitHub App + metrics integration)
- **Infrastructure**: $500-1000/month (service hosting + monitoring)
- **Ongoing**: 4-8 hours/week (maintenance, debugging, updates)
- **Risk**: Critical path dependency (if service fails, all deployments block)

### Harness Comparison
```yaml
# Harness: Built-in continuous verification with ML
verification:
  type: Auto  # ML-based anomaly detection
  sensitivity: MEDIUM
  duration: 10m
  metrics:
    - error_rate < 1%
    - latency_p99 < 500ms

  # Harness automatically:
  # - Compares to historical baseline
  # - Uses statistical analysis
  # - Provides anomaly confidence scores
  # - Auto-rolls back on failure
```

**Verdict**: ⚠️ GitHub CAN do this with 3-4 weeks of custom engineering, but you're building a mini-Harness.

---

## 3. ⚠️ Prevent Deploying to Production Immediately After Staging

### GitHub Solution: Custom Soak Time Logic

**Option A: GitHub Actions `wait-timer` (Simple)**

```yaml
jobs:
  check-staging-soak-time:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Get last staging deployment
        id: staging
        run: |
          # Query GitHub API for last staging deployment
          STAGING_TIME=$(gh api repos/$REPO/deployments \
            --jq '.[] | select(.environment=="staging") | .created_at' | head -1)

          STAGING_EPOCH=$(date -d "$STAGING_TIME" +%s)
          NOW=$(date +%s)
          SOAK_TIME=$((NOW - STAGING_EPOCH))

          MIN_SOAK=$((60 * 60))  # 1 hour

          if [ $SOAK_TIME -lt $MIN_SOAK ]; then
            echo "❌ Staging soak time not met: ${SOAK_TIME}s / ${MIN_SOAK}s"
            exit 1
          fi

          echo "✅ Staging soak time OK: ${SOAK_TIME}s"

      - name: Deploy to production
        run: kubectl apply -f deployment.yaml
```

**Option B: Custom Deployment Protection Rule (Robust)**

```javascript
// In your deployment protection service
app.post('/api/deployment-protection', async (req, res) => {
  const { deployment, environment } = req.body;

  if (environment === 'production') {
    // Query GitHub API for last staging deployment
    const stagingDeployments = await octokit.repos.listDeployments({
      owner: deployment.repo.owner,
      repo: deployment.repo.name,
      environment: 'staging'
    });

    const lastStaging = stagingDeployments.data[0];
    const stagingTime = new Date(lastStaging.created_at);
    const now = new Date();
    const soakMinutes = (now - stagingTime) / 1000 / 60;

    const MIN_SOAK_MINUTES = 60;

    if (soakMinutes < MIN_SOAK_MINUTES) {
      return res.json({
        state: 'rejected',
        comment: `Staging soak time not met: ${soakMinutes.toFixed(0)} min / ${MIN_SOAK_MINUTES} min. Please wait ${(MIN_SOAK_MINUTES - soakMinutes).toFixed(0)} more minutes.`,
        next_allowed_time: new Date(stagingTime.getTime() + MIN_SOAK_MINUTES * 60000).toISOString()
      });
    }

    return res.json({
      state: 'approved',
      comment: `Staging soak time OK: ${soakMinutes.toFixed(0)} minutes`
    });
  }
});
```

### ✅ Pros
- Enforceable (deployment fails if soak time not met)
- Provides clear error message with time remaining

### ❌ Cons
- **Option A**: Must add to every workflow (1000 repos)
- **Option B**: Requires custom service (2 weeks to build)
- **No database of deployment history** (relying on GitHub API)
- **GitHub API rate limits** (5000 requests/hour for Enterprise)
- **Must configure per-repo** (1000 workflows or 3000 environments)

### Cost
- **Option A**: 1 week (update 1000 workflows)
- **Option B**: 2 weeks (build + integrate with deployment protection)
- **Ongoing**: 2-4 hours/week (debugging failures, API issues)

### Harness Comparison
```yaml
# Harness: One line
stagingGate:
  minimumSoakTime: 1h
  requiredEnvironment: staging
```

**Verdict**: ⚠️ Possible but requires custom logic in 1000 workflows OR a custom service.

---

## 4. ⚠️ Prevent Deploying Outside Business Hours

### GitHub Solution: Custom Deployment Window Check

**Option A: In GitHub Actions Workflow**

```yaml
jobs:
  check-deployment-window:
    runs-on: ubuntu-latest
    steps:
      - name: Check deployment window
        run: |
          # Get current time in EST
          HOUR=$(TZ='America/New_York' date +%H)
          DAY=$(TZ='America/New_York' date +%u)  # 1=Mon, 7=Sun

          # Allow Mon-Thu, 9am-5pm EST
          if [ $DAY -ge 5 ]; then
            echo "❌ Deployments not allowed on weekends"
            exit 1
          fi

          if [ $HOUR -lt 9 ] || [ $HOUR -ge 17 ]; then
            echo "❌ Deployments only allowed 9am-5pm EST"
            echo "Current time: $(TZ='America/New_York' date)"
            exit 1
          fi

          echo "✅ Within deployment window"

  deploy-production:
    needs: check-deployment-window
    environment: production
    runs-on: ubuntu-latest
    steps:
      - run: kubectl apply -f deployment.yaml
```

**Option B: Custom Deployment Protection Rule**

```javascript
// In deployment protection service
app.post('/api/deployment-protection', async (req, res) => {
  const { environment } = req.body;

  if (environment === 'production') {
    const now = new Date();
    const nyTime = new Date(now.toLocaleString('en-US', { timeZone: 'America/New_York' }));

    const hour = nyTime.getHours();
    const day = nyTime.getDay(); // 0=Sun, 6=Sat

    // Allow Mon-Thu (1-4), 9am-5pm
    if (day === 0 || day === 6 || day === 5) {
      return res.json({
        state: 'rejected',
        comment: `Production deployments not allowed on ${['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day]}. Allowed: Mon-Thu`,
        next_allowed_time: getNextDeploymentWindow()
      });
    }

    if (hour < 9 || hour >= 17) {
      return res.json({
        state: 'rejected',
        comment: `Production deployments only allowed 9am-5pm EST. Current time: ${nyTime.toLocaleString()}`,
        next_allowed_time: getNextDeploymentWindow()
      });
    }
  }

  return res.json({ state: 'approved' });
});
```

### ✅ Pros
- Straightforward logic
- Clear error messages

### ❌ Cons
- **Option A**: Must add to 1000 workflows
- **Option B**: Requires custom service
- **No holiday calendar** (you must maintain list of holidays)
- **No freeze periods** (must update code for holiday freezes)
- **Timezone complexity** (must handle DST, multiple timezones)

### Cost
- **Option A**: 1 week (update 1000 workflows)
- **Option B**: 1 week (add to deployment protection service)
- **Ongoing**: 2 hours/month (update holiday calendar)

### Harness Comparison
```yaml
deploymentWindow:
  environment: production
  allowedDays: ["Mon", "Tue", "Wed", "Thu"]
  allowedHours: "09:00-17:00"
  timezone: "America/New_York"

  holidays:
    - "2026-12-25"  # Christmas
    - "2026-01-01"  # New Year

  freezePeriods:
    - name: "Holiday Freeze"
      start: "2026-12-20"
      end: "2026-01-02"
```

**Verdict**: ⚠️ Easy to implement, but must add to 1000 workflows or build a service.

---

## 5. ⚠️ Prevent Deploying During Production Incident

### GitHub Solution: PagerDuty/Incident Management Integration

This requires a **custom deployment protection rule** that checks incident management systems.

```javascript
// In deployment protection service
const PagerDuty = require('node-pagerduty');
const pd = new PagerDuty(process.env.PAGERDUTY_TOKEN);

app.post('/api/deployment-protection', async (req, res) => {
  const { environment } = req.body;

  if (environment === 'production') {
    // Check for active incidents
    const incidents = await pd.incidents.listIncidents({
      statuses: ['triggered', 'acknowledged'],
      urgencies: ['high'],
      limit: 1
    });

    if (incidents.data.length > 0) {
      const incident = incidents.data[0];
      return res.json({
        state: 'rejected',
        comment: `❌ Active P1 incident: ${incident.title}\n\nDeployments blocked until incident is resolved.\n\nIncident: ${incident.html_url}`,
        incident_url: incident.html_url
      });
    }

    // Check OpsGenie, StatusPage, etc.
    const opsgenieIncidents = await checkOpsGenie();
    if (opsgenieIncidents.length > 0) {
      // Similar logic
    }
  }

  return res.json({ state: 'approved' });
});
```

### ✅ Pros
- Prevents deployments during active incidents
- Integrates with existing incident management

### ❌ Cons
- **Requires custom service** (2-3 weeks to build)
- **Must integrate with incident tools** (PagerDuty, OpsGenie, etc.)
- **Operational complexity**:
  - Service must be highly available (it's in critical path)
  - API token management (PagerDuty, OpsGenie)
  - Multiple incident systems (PagerDuty, OpsGenie, StatusPage)
- **No built-in incident detection** (must integrate external tools)

### Cost
- **Build**: 2-3 weeks (service + integrations)
- **Ongoing**: 4-6 hours/week (token rotation, debugging, new integrations)

### Harness Comparison
```yaml
deploymentPolicy:
  blockOnIncidents: true
  incidentSources:
    - type: PagerDuty
      severity: ["P1", "P2"]
    - type: OpsGenie
      priority: ["P1"]
    - type: StatusPage
      impact: ["critical"]
```

**Verdict**: ⚠️ Requires custom integration service, but definitely possible.

---

## 6. ⚠️ Prevent Deploying Multiple Services in Wrong Order

### GitHub Solution: Custom Orchestration Service

This is the MOST complex requirement and requires significant custom engineering.

**Problem**: Service A depends on Service B (e.g., database migration must complete before app deployment)

**GitHub Solution**: Build a deployment orchestrator

```javascript
// deployment-orchestrator/index.js
const deploymentGraph = {
  'user-service': {
    dependencies: ['database-migrations', 'auth-service'],
    deploymentOrder: 3
  },
  'database-migrations': {
    dependencies: [],
    deploymentOrder: 1
  },
  'auth-service': {
    dependencies: ['database-migrations'],
    deploymentOrder: 2
  }
};

app.post('/api/deployment-protection', async (req, res) => {
  const { deployment, environment } = req.body;
  const service = deployment.service;

  if (environment === 'production') {
    const deps = deploymentGraph[service].dependencies;

    // Check if dependencies are deployed
    for (const dep of deps) {
      const depDeployment = await getLastDeployment(dep, 'production');

      if (!depDeployment) {
        return res.json({
          state: 'rejected',
          comment: `Dependency not deployed: ${dep}\n\nPlease deploy ${dep} first, then retry ${service}.`
        });
      }

      // Check if dependency is on compatible version
      const compatible = await checkVersionCompatibility(service, dep, depDeployment.version);
      if (!compatible) {
        return res.json({
          state: 'rejected',
          comment: `Version incompatibility: ${dep}@${depDeployment.version} is not compatible with ${service}`
        });
      }
    }
  }

  return res.json({ state: 'approved' });
});
```

**Usage in workflow:**
```yaml
jobs:
  deploy:
    environment: production  # ← Orchestrator checks dependencies
    runs-on: ubuntu-latest
    steps:
      - run: kubectl apply -f deployment.yaml
```

### ✅ Pros
- Enforces deployment order
- Prevents incompatible version deployments

### ❌ Cons
- **Significant custom engineering** (4-6 weeks)
- **Complex operational burden**:
  - Dependency graph must be maintained
  - Version compatibility matrix
  - Deployment state tracking
  - Rollback coordination
- **No parallel deployments** (orchestrator serializes everything)
- **Single point of failure** (if orchestrator is down, all deployments block)

### Cost
- **Build**: 4-6 weeks (orchestrator + dependency management)
- **Ongoing**: 8-12 hours/week (maintain dependency graph, debug issues)
- **Risk**: High (critical path dependency)

### Harness Comparison
```yaml
# Harness: Built-in multi-service pipelines
pipeline:
  stages:
    - parallel: false  # Sequential
      stages:
        - stage: Deploy Database Migrations
          service: database-migrations
        - stage: Deploy Auth Service
          service: auth-service
          dependsOn: [database-migrations]
        - stage: Deploy User Service
          service: user-service
          dependsOn: [auth-service, database-migrations]

  # Harness handles:
  # - Execution order
  # - Failure rollback across services
  # - Version tracking
  # - Parallel where possible
```

**Verdict**: ⚠️ Possible but requires building a deployment orchestrator (mini-Harness).

---

## Total Cost of Workarounds

### Custom Services Required

| Service | Build Time | Ongoing Effort | Risk |
|---------|-----------|----------------|------|
| **Deployment Protection Rule** (metrics, soak time, windows, incidents) | 6-8 weeks | 8-12 hrs/week | 🔴 Critical path |
| **Multi-Service Orchestrator** | 4-6 weeks | 8-12 hrs/week | 🔴 Critical path |
| **Total** | **10-14 weeks** | **16-24 hrs/week** | **2 critical dependencies** |

### Workflow Updates

| Workaround | Repos Affected | Time per Repo | Total Time |
|------------|---------------|---------------|------------|
| Add deployment window check | 1000 | 10 min | 167 hours (4 weeks) |
| Add soak time check | 1000 | 10 min | 167 hours (4 weeks) |
| **Total** | **1000** | **20 min** | **334 hours (8 weeks)** |

### Overall Cost Summary

**Option 1: Custom Services (Recommended)**
- **Build**: 10-14 weeks
- **Infrastructure**: $1000-2000/month
- **Ongoing**: 16-24 hours/week (0.4-0.6 FTE)
- **Risk**: 2 critical path dependencies

**Option 2: Workflow Logic (Not Recommended)**
- **Build**: 8 weeks (update 1000 workflows)
- **Ongoing**: Configuration drift, debugging, updates
- **Risk**: Inconsistent enforcement

**Option 3: Hybrid (Most Common)**
- Custom protection service for metrics + incidents: 6-8 weeks
- Workflow logic for windows + soak time: 4 weeks
- **Total**: 10-12 weeks + 8-16 hours/week ongoing

---

## Comparison Matrix: GitHub Workarounds vs Harness

| Requirement | GitHub Workaround | Build Time | Ongoing | Harness | Build Time | Ongoing |
|-------------|-------------------|-----------|---------|---------|-----------|---------|
| **Prod approval** | GitHub Environments | 2 weeks | 🟡 Medium | Built-in | 0 | 🟢 Low |
| **Metrics verification** | Custom service | 3-4 weeks | 🔴 High | Built-in | 0 | 🟢 Low |
| **Soak time** | Custom logic | 2 weeks | 🟡 Medium | Built-in | 0 | 🟢 Low |
| **Deployment windows** | Custom logic | 1 week | 🟡 Medium | Built-in | 0 | 🟢 Low |
| **Incident blocking** | Custom integration | 2-3 weeks | 🔴 High | Built-in | 0 | 🟢 Low |
| **Service orchestration** | Custom orchestrator | 4-6 weeks | 🔴 High | Built-in | 0 | 🟢 Low |
| **TOTAL** | Multiple services | **14-19 weeks** | **🔴 High** | Configuration | **2-4 weeks** | **🟢 Low** |

---

## Conclusion

### Can GitHub Solve These Issues? YES ✅

Every single deployment governance requirement CAN be solved with GitHub, using:
1. GitHub Environments (built-in approvals)
2. Custom Deployment Protection Rules (custom logic)
3. Workflow logic (simpler checks)

### Should You Build These Workarounds? IT DEPENDS ⚠️

**For < 50 repos**: ✅ Workflow logic is manageable
**For 50-500 repos**: ⚠️ Consider custom services vs platform
**For 1000+ repos**: ❌ Custom engineering exceeds platform cost

### The Real Question: Build vs Buy

**If you build GitHub workarounds:**
- ✅ No vendor lock-in
- ✅ Full control over logic
- ❌ 14-19 weeks to build
- ❌ 16-24 hours/week to maintain (0.4-0.6 FTE)
- ❌ 2 critical path services
- ❌ No ML/statistical analysis
- ❌ You're building a mini-Harness

**If you use Harness:**
- ✅ 2-4 weeks to configure
- ✅ 2-4 hours/week to maintain (0.05-0.1 FTE)
- ✅ Zero custom services
- ✅ ML-powered verification
- ✅ One-click rollback
- ⚠️ Vendor dependency

### Updated Cost Analysis

**GitHub-Native (with all workarounds)**:
- Year 1: $1,277k (original) + custom services ($200k) = **$1,477k**
- Years 2-5: $992k + service maintenance ($100k) = **$1,092k/year**
- **5-Year Total**: **$5,845,000**

**Harness Hybrid**:
- Year 1: **$925k**
- Years 2-5: **$745k/year**
- **5-Year Total**: **$3,905,000**

**Savings with Harness: $1,940,000 (33%)**

---

## Recommendation

**Everything is technically possible with GitHub, but:**

At 1000+ repos, the cost of building and maintaining GitHub workarounds ($5.8M) exceeds the cost of using a purpose-built platform ($3.9M).

**You're not paying Harness for features - you're paying them to NOT build and maintain these 6 custom services.**

---

**See Also**:
- [ACCURACY_VERIFICATION.md](ACCURACY_VERIFICATION.md) - All claims verified
- [HARNESS_COMPARISON.md](HARNESS_COMPARISON.md) - Side-by-side comparison
- [OPERATIONAL_BURDEN.md](OPERATIONAL_BURDEN.md) - Day-to-day reality
