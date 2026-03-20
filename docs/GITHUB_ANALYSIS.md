# GitHub Analysis: Enterprise Features, Gaps, and Workarounds

**Complete GitHub analysis** - what works, what doesn't, and how to solve every gap at 1000+ repo scale.

> **Consolidates**: GitHub Gaps (Real), Developer vs Platform, Why Templates Fail, Enterprise Setup, Workarounds, Environments

---

## Table of Contents

1. [The 7 Critical Gaps](#the-7-critical-gaps)
2. [Developer vs Platform Team](#developer-vs-platform-team)
3. [Why GitHub Templates Fail](#why-github-templates-fail)
4. [GitHub Enterprise Setup](#github-enterprise-setup)
5. [Workarounds for Every Gap](#workarounds-for-every-gap)
6. [The Bottom Line](#the-bottom-line)

---

## The 7 Critical Gaps

**What's missing vs dedicated CD platforms like Harness** - demonstrated in the running workflows.

### Gap #1: No One-Click Rollback

**What you see in the running pipeline**:
```yaml
# .github/workflows/cd-user-service.yml
- name: Deploy to Kubernetes
  run: kubectl apply -f services/user-service/k8s/
```

**The problem**:
- Deployment completes, application has bugs
- No "Rollback" button
- Must manually: git revert → wait for CI → redeploy (5-15 min)
- Or: kubectl rollout undo (error-prone)

**Harness**:
- Click "Rollback" button
- 30 seconds to previous version
- Automatic, safe, tracked

**Evidence**: Try deploying user-service, then rolling back. No automation.

---

### Gap #2: No Deployment Verification

**What you see**:
```yaml
# After deployment, only basic smoke tests
- name: Run smoke tests
  run: |
    curl -f http://localhost:3000/health
    curl -f http://localhost:3000/api/users
```

**What's missing**:
- Monitor error rate, latency, CPU for 15 minutes
- Compare metrics to baseline
- Automatic rollback if degradation detected
- ML-based anomaly detection

**What you must build**:
```javascript
// Custom Deployment Protection Rule (4 weeks to build)
app.post('/deployment-gate', async (req, res) => {
  const errorRate = await prometheus.query('error_rate');
  const latency = await prometheus.query('p95_latency');

  if (errorRate > 0.05 || latency > 500) {
    return res.json({ state: 'rejected' });
  }
  res.json({ state: 'approved' });
});
```

**Harness**: Built-in ML verification

---

### Gap #3: Configuration Sprawl (3,000 Configs)

**What you see**:
- Each service has its own workflow file
- Environments configured in repo settings (UI)
- Secrets per repository

**The problem**:
```
user-service
  ├─ Environments (staging, production) ← Repo-specific
  ├─ Secrets (per environment) ← Distributed
  └─ .github/workflows/cd-*.yml ← In repo

payment-service
  ├─ Environments (staging, production) ← Duplicate config
  ├─ Secrets (per environment) ← More duplication
  └─ .github/workflows/cd-*.yml ← Another copy

× 1000 repos = 3,000 environment configs
```

**Impact**:
- 15 min setup per repo × 1000 = **250 hours**
- Update approval team? Touch 1000 repos
- Configuration drift inevitable

**Harness**: Centralized environment configuration

---

### Gap #4: No Multi-Service Orchestration

**Scenario**: Deploy database-migration BEFORE api-gateway

**GitHub**: Each service has independent workflow
- No way to make api-gateway wait for database-migration
- Must build custom orchestrator (6 weeks)

**Evidence**: All 3 services deploy independently

**Harness**: Pipeline dependencies built-in

---

### Gap #5: No Deployment Observability

**What you see**:
- GitHub Actions tab shows workflow runs
- No centralized deployment dashboard
- No DORA metrics (deployment frequency, lead time, MTTR, change failure rate)

**What you must build**:
- Custom DORA metrics collector (3 weeks)
- Query GitHub API for deployment data
- Store in database
- Build Grafana dashboards

**Harness**: Built-in deployment observability + DORA metrics

---

### Gap #6: Parallel Execution Race Condition

**THE CRITICAL ARCHITECTURAL GAP**

**What happens** (demonstrated in running workflows):
```
t=0:   Push to main
t=0:   Required Workflow starts (platform/.github/workflows/required-security-scan.yml)
       └─ Scans filesystem with Trivy
t=0:   Developer Workflow starts (.github/workflows/cd-user-service.yml)
       └─ Builds Docker image
       └─ Deploys to Kubernetes
t=3m:  Developer workflow COMPLETES ✅
       └─ Code is IN PRODUCTION
t=5m:  Required workflow finds CVE ❌
       └─ Too late, already deployed
```

**Why**: GitHub Actions has no cross-workflow dependency mechanism.

**Even with GitHub Enterprise**:
- ✅ Required Workflows run org-wide
- ✅ Organization Rulesets enforce status checks
- ❌ **Both workflows triggered by same event run in PARALLEL**
- ❌ **No way to make developer workflow wait for required workflow**

**The files proving this**:
- `platform/.github/workflows/required-security-scan.yml` - Scans filesystem
- `.github/workflows/cd-user-service.yml` - Builds image, deploys

Both start at t=0. Deploy finishes before scan completes.

**Harness**: Sequential enforcement
```yaml
stages:
  - Security (must complete)
  - Deploy (waits for Security)
```

---

### Gap #7: Developers Can Bypass Security

**The Core Problem**: Workflow files live IN developer repositories.

**Demonstration**: See `.github/workflows/ci-user-service.yml`
- Developers can edit this file
- Can comment out security jobs
- Can add `continue-on-error: true`
- Can skip conditionally

**Even with CODEOWNERS** (`.github/CODEOWNERS`):
```bash
/.github/workflows/ @platform-team @security-team
```

**Helps but doesn't scale**:
- Requires manual code review
- 10-20 PRs/day × 1000 repos = unsustainable
- Subtle bypasses slip through

**Example bypass that passes review**:
```yaml
jobs:
  security-scan:
    continue-on-error: true  # ← Looks like error handling
    steps:
      - uses: trivy-action@master
        with:
          exit-code: 0  # ← Security never fails
```

Reviewer approves → security bypassed.

---

## Developer vs Platform Team

### The Two Roles

**Platform Team wants**:
- Enforce security scanning (all vulnerabilities caught)
- Require approval gates (no unauthorized deploys)
- Standardized workflows (consistency across 1000 repos)
- Locked templates (developers cannot modify)

**Developers have**:
- Full control of `.github/workflows/` files
- Ability to edit, skip, or bypass security steps
- Legitimate need to customize for their service

**The conflict**: At 1000+ repos, manual review doesn't scale.

---

### The 4 Bypass Scenarios

#### Bypass #1: Comment Out Security Job

```yaml
# What Platform Team wants
jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          exit-code: 1  # Fail on CVEs

# What Developer can do
# jobs:
#   security-scan:
#     ...
```

**Prevention**: CODEOWNERS requires platform team approval
**Limitation**: Obvious, would be caught in review

---

#### Bypass #2: Subtle Configuration Change

```yaml
# Looks reasonable, might pass review
jobs:
  security-scan:
    continue-on-error: true  # ← "For stability"
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          exit-code: 0  # ← "Updated config"
```

**Prevention**: CODEOWNERS requires approval
**Limitation**: Reviewer might miss these changes in a large PR

---

#### Bypass #3: Conditional Skip

```yaml
jobs:
  security-scan:
    # Looks like feature flag logic
    if: "!contains(github.event.head_commit.message, 'skip-security')"
    steps:
      - uses: aquasecurity/trivy-action@master
```

Developer commits with message: `"fix: update API skip-security"` → scan skipped

**Prevention**: CODEOWNERS requires approval
**Limitation**: Looks like reasonable conditional logic

---

#### Bypass #4: Deploy Before Scan Completes (Timing Race)

```yaml
# Developer's workflow
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: kubectl apply -f k8s/  # Deploys immediately
```

**Meanwhile**: Required Workflow is still scanning (runs in parallel)

**Prevention**: NONE (architectural limitation)
**Limitation**: No cross-workflow dependencies in GitHub Actions

---

### GitHub Enterprise Protections

GitHub Enterprise provides 3 features to prevent bypasses:

#### 1. CODEOWNERS (`.github/CODEOWNERS`)

```bash
# Requires platform team approval for workflow changes
/.github/workflows/ @platform-team @security-team
```

**What it provides**:
- Platform team MUST review workflow changes
- Prevents obvious bypasses (commented out jobs)
- Creates audit trail

**What it DOESN'T prevent**:
- Subtle bypasses (reviewer misses change)
- Scale issues (reviewing 1000 repos)
- Context switching (20 different services/day)

**Time cost**: 2-4 hrs/day reviewing workflow PRs at scale

---

#### 2. Organization Rulesets (`platform/rulesets/organization-production-ruleset.json`)

```json
{
  "name": "Production Branch Protection",
  "enforcement": "active",
  "rules": [
    {
      "type": "required_status_checks",
      "parameters": {
        "required_status_checks": [
          {"context": "Required Security Scan"}
        ]
      }
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 2,
        "require_code_owner_review": true
      }
    }
  ]
}
```

**What it provides**:
- Centralized policy (applies to all repos)
- Requires status checks from Required Workflows
- Enforces code owner review

**What it DOESN'T prevent**:
- Developer's workflow deploying in parallel
- Deployment before required workflow completes
- Developer removing security from their workflow

**Why**: Rulesets enforce **pre-merge** checks, not **deployment-time** policies.

---

#### 3. Required Workflows (`platform/.github/workflows/required-security-scan.yml`)

```yaml
# Lives in org-name/.github-private repository
# Runs automatically on ALL repos (developers cannot disable)

name: Required Security Scan (Organization-Wide)

on: [pull_request, push]

jobs:
  filesystem-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'  # Scans filesystem
          exit-code: 1
```

**What it provides**:
- Runs on ALL 1000 repos automatically
- Developers cannot disable
- Creates required status check for rulesets
- Centralized management

**What it DOESN'T prevent**:
- **Critical**: Runs in PARALLEL with developer's workflow
- **Critical**: Scans filesystem, NOT Docker images
- **Critical**: Cannot block deployment in developer's workflow

**The limitation**:
```
Required Workflow: Scans source code at t=0
Developer Workflow: Builds Docker image at t=0
                     └─ Image built AFTER scan completes
                     └─ Image is NEVER scanned by required workflow
                     └─ Deploys at t=3m (before required workflow finishes at t=5m)
```

---

### Why Manual Review Doesn't Scale

**At < 50 repos**:
- ✅ Platform team can review all PRs
- ✅ 2-3 workflow changes/day is manageable
- ✅ Can catch subtle bypasses

**At 1000 repos**:
- ❌ 10-20 workflow PRs/day
- ❌ Context switching between different services
- ❌ Reviewer fatigue
- ❌ Subtle bypasses slip through
- ❌ 2-4 hours/day just reviewing workflows

---

### The Harness Solution

**Templates live OUTSIDE developer repos**:
```yaml
# Platform repo (locked, developers cannot access)
template:
  name: Production Deployment
  stages:
    - stage:
        name: Security
        locked: true  # ← Developers CANNOT modify
        spec:
          imageScan:
            failOnCVE: true
    - stage:
        name: Deploy
        locked: true
        dependsOn: [Security]  # ← Sequential enforcement

# Developer repo (references template)
pipeline:
  template: Production Deployment  # ← Cannot modify
  variables:
    service: user-service
```

**Key differences**:
- Developers reference templates, cannot edit
- No code review needed (impossible to bypass)
- Sequential stages (deploy waits for security)
- Scales to unlimited repos

---

## Why GitHub Templates Fail

**GitHub has "reusable workflows"** - are they like Harness templates?

**No. Here's why.**

### GitHub Reusable Workflows

**Example** (`.github/workflows/ci-user-service.yml` - 180 lines):

```yaml
name: CI - User Service

on:
  push:
    branches: [main]

permissions:
  contents: read
  packages: write
  security-events: write
  id-token: write

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm test

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}/user-service:${{ github.sha }}

  security-scan:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: ghcr.io/${{ github.repository }}/user-service:${{ github.sha }}
          exit-code: 1

  # ... 3 more jobs (SBOM, sign, policy)
```

**You can extract to reusable workflow**:
```yaml
# platform/.github/workflows/reusable-ci.yml
name: Reusable CI Pipeline

on:
  workflow_call:
    inputs:
      service_name:
        required: true
        type: string

jobs:
  # Same jobs as above, parameterized
```

**Call from developer repo**:
```yaml
# user-service/.github/workflows/ci.yml
name: CI - User Service

on: [push]

jobs:
  ci:
    uses: org/platform/.github/workflows/reusable-ci.yml@main
    with:
      service_name: user-service
```

**Looks good! What's the problem?**

---

### The 3 Problems with GitHub Reusable Workflows

#### Problem #1: Still Need 1000 Workflow Files

**Every repository needs**:
```
repo-1/.github/workflows/ci.yml  (calls reusable workflow)
repo-2/.github/workflows/ci.yml  (calls reusable workflow)
...
repo-1000/.github/workflows/ci.yml  (calls reusable workflow)
```

**Impact**:
- 1000 files to create initially
- Update trigger condition? Touch 1000 files
- Add new permission? Touch 1000 files

**Harness**:
- Zero workflow files in developer repos
- Pure reference to centralized template

---

#### Problem #2: Developers Can Modify or Skip

```yaml
# Developer can comment out the reusable workflow
# jobs:
#   ci:
#     uses: org/platform/.github/workflows/reusable-ci.yml@main

# Or add their own jobs that bypass security
jobs:
  ci:
    uses: org/platform/.github/workflows/reusable-ci.yml@main

  deploy-directly:
    runs-on: ubuntu-latest
    steps:
      - run: kubectl apply -f k8s/  # Bypasses CI!
```

**Harness**: Locked templates cannot be modified

---

#### Problem #3: Still Need 3,000 Environment Configs

```yaml
# Call reusable workflow
jobs:
  ci:
    uses: org/platform/.github/workflows/reusable-ci.yml@main

  # But environments are STILL per-repo
  deploy:
    environment: production  # ← Configured in repo settings
    steps:
      - run: deploy.sh
```

**Each repo still needs**:
- Environment created in settings (UI or API)
- Secrets configured per environment
- Approval team configured
- Deployment protection rules

**Total**: 3,000 environment configs

**Harness**: Centralized environment configuration

---

### The Brutal Comparison

| Feature | GitHub Reusable Workflows | Harness Templates |
|---------|--------------------------|-------------------|
| **Workflow files in repos** | 1000 files | 0 files |
| **Developers can modify** | Yes (can comment out) | No (locked) |
| **Environment configs** | 3000 (distributed) | 1 (centralized) |
| **Secrets management** | Per repo/environment | Centralized |
| **Update rollout** | Touch 1000 repos | Update 1 template |
| **Configuration drift** | Inevitable | Impossible |
| **Bypass risk** | Developers can skip | Architecturally prevented |

**GitHub "templates" reduce duplication, but don't solve governance at scale.**

---

## GitHub Enterprise Setup

**How to configure ALL GitHub Enterprise features** (we did this in the repo).

### Prerequisites

**Required**:
- GitHub Enterprise Cloud organization
- GitHub Advanced Security enabled
- Organization owner permissions

**Cost**: ~$400,000/year for 1000 users
- GitHub Enterprise: $21/user/month × 1000 = $252k/year
- Compute for Required Workflows: ~$148k/year
- **Total: ~$400k/year**

---

### Step 1: Enable Advanced Security

```bash
# Via GitHub UI:
Organization Settings → Code security and analysis
→ Enable GitHub Advanced Security for all repositories
→ Enable Dependency graph
→ Enable Dependabot alerts
→ Enable Dependabot security updates
→ Enable Code scanning
→ Enable Secret scanning
```

**Time**: 30 minutes
**What you get**: CVE scanning, secret detection, dependency alerts

---

### Step 2: Deploy CODEOWNERS to All Repos

**Create** `.github/CODEOWNERS` in each repo:
```bash
# Workflow files require platform team approval
/.github/workflows/ @platform-team @security-team

# Deployment manifests require approval
**/Dockerfile @platform-team @security-team
**/k8s/ @platform-team
```

**Automate deployment**:
```bash
#!/bin/bash
ORG="your-org"
REPOS=$(gh repo list $ORG --limit 1000 --json name -q '.[].name')

for repo in $REPOS; do
  gh repo clone $ORG/$repo temp/$repo
  cd temp/$repo
  mkdir -p .github
  cp /path/to/CODEOWNERS .github/CODEOWNERS
  git add .github/CODEOWNERS
  git commit -m "Add CODEOWNERS for governance"
  git push origin main
  cd ../..
  rm -rf temp/$repo
done
```

**Time**: 8-10 hours for 1000 repos

**What you get**:
- Platform team approval required for workflow changes
- Blocks obvious bypasses

**What you DON'T get**:
- Protection from subtle bypasses
- Scale (manual review of 1000 repos)

---

### Step 3: Create Organization Rulesets

**File**: `platform/rulesets/organization-production-ruleset.json`

```json
{
  "name": "Production Branch Protection",
  "enforcement": "active",
  "target": "branch",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main", "refs/heads/master", "refs/heads/production"]
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 2,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "required_status_checks": [
          {"context": "Required Security Scan"},
          {"context": "Required SBOM Generation"},
          {"context": "Required Policy Validation"}
        ]
      }
    },
    {
      "type": "non_fast_forward"
    }
  ]
}
```

**Deploy via API**:
```bash
curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/orgs/YOUR_ORG/rulesets \
  -d @platform/rulesets/organization-production-ruleset.json
```

**Time**: 2-3 hours
**What you get**: Centralized policy across all repos

---

### Step 4: Deploy Required Workflows

**Create** `org/.github-private` repository (special name):
```bash
gh repo create your-org/.github-private --private
cd .github-private
mkdir -p .github/workflows
```

**Add** `platform/.github/workflows/required-security-scan.yml`:
```yaml
name: Required Security Scan (Organization-Wide)

on: [pull_request, push]

permissions:
  contents: read
  security-events: write

jobs:
  filesystem-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          exit-code: 1
```

**Configure in Organization Settings**:
```
Organization Settings → Actions → Required workflows
→ Add workflow: .github/workflows/required-security-scan.yml
→ Repository: your-org/.github-private
→ Apply to: All repositories
```

**Time**: 4-6 hours
**What you get**: Org-wide security scanning

**Critical limitation**: Runs in PARALLEL, cannot block deployments

---

### What You've Deployed

| Feature | Status | Time | Ongoing |
|---------|--------|------|---------|
| Advanced Security | ✅ | 30 min | Low |
| CODEOWNERS | ✅ | 8-10 hrs | 2-4 hrs/week (reviews) |
| Organization Rulesets | ✅ | 2-3 hrs | Low |
| Required Workflows | ✅ | 4-6 hrs | Low |
| **Total** | ✅ | **15-20 hrs** | **2-4 hrs/week** |

**Annual Cost**: ~$400,000 (GitHub Enterprise)
**Ongoing Effort**: 2-4 hrs/week (workflow reviews)

---

### What's STILL Missing

Even with GitHub Enterprise fully configured:

❌ **Parallel execution gap** - Required workflows run alongside developer workflows
❌ **Cannot scan Docker images** - Required workflows scan filesystem only
❌ **Cannot block deployments** - No cross-workflow dependency mechanism
❌ **Distributed environments** - 3,000 environment configs
❌ **Developers control workflows** - Can bypass with subtle changes

---

## Workarounds for Every Gap

**Can you solve GitHub's gaps?** YES - but at significant cost.

### Workaround #1: Production Approval Gates

**Requirement**: Require approval from platform team before production deployment.

#### GitHub Solution: Environments

**Already built-in!**
```yaml
# .github/workflows/cd-user-service.yml
jobs:
  deploy:
    environment: production  # ← Requires approval
    steps:
      - run: kubectl apply -f k8s/
```

**Configure in repo settings**:
```
Settings → Environments → production
→ Required reviewers: @platform-team
```

**Cost**: ✅ Free (built-in)
**Time**: 15 min per repo × 1000 = **250 hours** (one-time)
**Ongoing**: Low (just approving deployments)

**Limitation**: Per-repo configuration (3,000 environment configs)

#### Harness Solution

```yaml
# Centralized template
stages:
  - stage:
      approval:
        type: manual
        approvers: [platform-team]
```

**Cost**: ✅ Built-in
**Time**: 1 hour (one template)

---

### Workaround #2: Metrics-Based Verification

**Requirement**: Prevent deploying if staging has high error rate.

#### GitHub Solution: Custom Deployment Protection Rule

**Must build custom service**:

```javascript
// deployment-gate-service.js
const express = require('express');
const axios = require('axios');

const app = express();

app.post('/evaluate', async (req, res) => {
  const { environment, service } = req.body;

  // Query Prometheus for error rate
  const errorRate = await axios.get(
    `http://prometheus:9090/api/v1/query?query=rate(errors_total{service="${service}"}[5m])`
  );

  if (errorRate.data.data.result[0]?.value[1] > 0.05) {
    return res.json({
      state: 'rejected',
      message: 'Error rate > 5%'
    });
  }

  res.json({ state: 'approved' });
});

app.listen(3000);
```

**Configure in environment**:
```
Settings → Environments → production
→ Deployment protection rules
→ Add custom deployment protection rule
→ Endpoint: https://deployment-gate.example.com/evaluate
```

**Cost**:
- **Build**: 3-4 weeks (Node.js service + Prometheus integration)
- **Hosting**: $50-100/month
- **Maintenance**: 4-8 hrs/week

**Limitation**:
- Must build and maintain yourself
- No ML, no statistical analysis
- Critical path dependency (service down = no deploys)

#### Harness Solution

```yaml
verification:
  type: auto
  providers: [Prometheus]
  sensitivity: medium
  duration: 15m
```

**Cost**: ✅ Built-in
**Time**: 5 minutes configuration

---

### Workaround #3: Soak Time Enforcement

**Requirement**: Wait 1 hour after staging deployment before allowing production.

#### GitHub Solution A: Workflow Logic

```yaml
# .github/workflows/cd-user-service.yml
jobs:
  deploy-staging:
    environment: staging
    steps:
      - run: deploy.sh staging

  wait-soak-time:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - run: sleep 3600  # 1 hour

  deploy-production:
    needs: wait-soak-time
    environment: production
    steps:
      - run: deploy.sh production
```

**Cost**: ✅ Free
**Time**: 1-2 hours per repo × 1000 = **2,000 hours**

**Limitation**:
- Workflow runs for 1 hour (wastes compute)
- Hard to change soak time (1000 files to update)

#### GitHub Solution B: Custom Deployment Protection Rule

```javascript
app.post('/evaluate', async (req, res) => {
  const stagingDeployTime = await getLastDeploymentTime('staging');
  const hoursSince = (Date.now() - stagingDeployTime) / 3600000;

  if (hoursSince < 1) {
    return res.json({
      state: 'rejected',
      message: `Soak time: ${hoursSince.toFixed(1)}/1.0 hours`
    });
  }

  res.json({ state: 'approved' });
});
```

**Cost**:
- **Build**: 1-2 weeks
- **Maintenance**: 2-4 hrs/week

#### Harness Solution

```yaml
stages:
  - stage: Staging
  - stage: Production
    waitInterval: 1h  # ← Built-in soak time
```

**Cost**: ✅ Built-in

---

### Workaround #4: Deployment Windows

**Requirement**: No Friday 6pm deployments, respect holidays.

#### GitHub Solution A: Workflow Logic

```yaml
jobs:
  check-deployment-window:
    runs-on: ubuntu-latest
    steps:
      - name: Check time
        run: |
          DAY=$(date +%u)  # 1-7 (Mon-Sun)
          HOUR=$(date +%H)

          # Block Friday 6pm-11pm
          if [ $DAY -eq 5 ] && [ $HOUR -ge 18 ]; then
            echo "Deployment blocked: Friday evening"
            exit 1
          fi

          # Block weekends
          if [ $DAY -ge 6 ]; then
            echo "Deployment blocked: Weekend"
            exit 1
          fi

  deploy:
    needs: check-deployment-window
    steps:
      - run: deploy.sh
```

**Cost**: ✅ Free
**Time**: 1 hour per repo × 1000 = **1,000 hours**

**Limitation**: Hard-coded logic, no holiday calendar

#### GitHub Solution B: Deployment Protection Rule

```javascript
const holidays = ['2024-12-25', '2025-01-01']; // Update manually

app.post('/evaluate', async (req, res) => {
  const now = new Date();
  const day = now.getDay(); // 0-6 (Sun-Sat)
  const hour = now.getHours();
  const date = now.toISOString().split('T')[0];

  // Block Friday 6pm+
  if (day === 5 && hour >= 18) {
    return res.json({ state: 'rejected', message: 'Friday evening' });
  }

  // Block weekends
  if (day === 0 || day === 6) {
    return res.json({ state: 'rejected', message: 'Weekend' });
  }

  // Block holidays
  if (holidays.includes(date)) {
    return res.json({ state: 'rejected', message: 'Holiday' });
  }

  res.json({ state: 'approved' });
});
```

**Cost**:
- **Build**: 1 week
- **Maintenance**: 2 hrs/month (update holiday calendar)

#### Harness Solution

```yaml
deploymentWindows:
  - type: scheduled
    schedule: "Mon-Thu 9am-6pm, Fri 9am-4pm"
    holidays: US  # ← Built-in calendar
```

---

### Workaround #5: Incident Blocking

**Requirement**: Block deployments during P1 incidents.

#### GitHub Solution: Custom Deployment Protection Rule + PagerDuty

```javascript
const axios = require('axios');

app.post('/evaluate', async (req, res) => {
  // Query PagerDuty for active incidents
  const incidents = await axios.get('https://api.pagerduty.com/incidents', {
    headers: { Authorization: `Token token=${PAGERDUTY_TOKEN}` },
    params: { statuses: ['triggered', 'acknowledged'] }
  });

  // Check for P1 incidents
  const p1Incidents = incidents.data.incidents.filter(i => i.urgency === 'high');

  if (p1Incidents.length > 0) {
    return res.json({
      state: 'rejected',
      message: `Active P1 incidents: ${p1Incidents.map(i => i.summary).join(', ')}`
    });
  }

  res.json({ state: 'approved' });
});
```

**Cost**:
- **Build**: 2-3 weeks (PagerDuty/OpsGenie integration)
- **Maintenance**: 4-6 hrs/week
- **Dependency**: PagerDuty API ($$$)

#### Harness Solution

```yaml
failureStrategy:
  - on: ActiveIncidents
    action: pauseDeployment
    integrations: [PagerDuty]
```

---

### Workaround #6: Multi-Service Orchestration

**Requirement**: Deploy services in correct order (database → APIs → frontend).

#### GitHub Solution: Custom Orchestrator Service

```javascript
// deployment-orchestrator.js
const dependencyGraph = {
  'frontend': ['api-gateway', 'user-service'],
  'api-gateway': ['database-migration'],
  'user-service': ['database-migration'],
  'payment-service': ['database-migration'],
};

async function deployService(service) {
  // Check dependencies
  const deps = dependencyGraph[service] || [];
  for (const dep of deps) {
    const depStatus = await getDeploymentStatus(dep);
    if (depStatus !== 'success') {
      throw new Error(`Dependency ${dep} not ready`);
    }
  }

  // Trigger deployment via GitHub API
  await triggerWorkflow(service);
}

app.post('/deploy', async (req, res) => {
  const { services } = req.body;

  // Topological sort
  const sorted = topologicalSort(services, dependencyGraph);

  // Deploy in order
  for (const service of sorted) {
    await deployService(service);
  }

  res.json({ status: 'complete' });
});
```

**Cost**:
- **Build**: 4-6 weeks (dependency graph + GitHub API integration)
- **Maintenance**: 8-12 hrs/week
- **Complexity**: High (you're building a mini-Harness)

#### Harness Solution

```yaml
pipeline:
  stages:
    - stage: database-migration
    - parallel:
        - stage: api-gateway
        - stage: user-service
        - stage: payment-service
      dependsOn: [database-migration]
    - stage: frontend
      dependsOn: [api-gateway, user-service, payment-service]
```

---

### Cost Summary: Workarounds

| Workaround | Build Time | Ongoing | Harness |
|------------|------------|---------|---------|
| Production approval | ✅ Built-in | Low | ✅ Built-in |
| Metrics verification | 3-4 weeks | 4-8 hrs/week | ✅ Built-in |
| Soak time | 1-2 weeks | 2-4 hrs/week | ✅ Built-in |
| Deployment windows | 1 week | 2 hrs/month | ✅ Built-in |
| Incident blocking | 2-3 weeks | 4-6 hrs/week | ✅ Built-in |
| Multi-service orchestration | 4-6 weeks | 8-12 hrs/week | ✅ Built-in |
| **TOTAL** | **12-18 weeks** | **18-30 hrs/week** | **2-4 hrs/week** |

**You can solve every gap in GitHub, but it costs MORE to build than using Harness.**

---

## The Bottom Line

### What GitHub Enterprise Provides

**Pre-Merge Security** ✅:
- Advanced Security (CVE scanning, secret detection)
- CODEOWNERS (platform team approval)
- Organization Rulesets (centralized policies)
- Required Workflows (org-wide scanning)

**Cost**: ~$400k/year
**Time**: 15-20 hours setup
**Ongoing**: 2-4 hrs/week (workflow reviews)

### What's Still Missing

**Deployment-Time Governance** ❌:
- Sequential enforcement (security BEFORE deploy)
- Centralized configuration
- Locked templates
- Multi-service orchestration
- Deployment verification
- One-click rollback

**To solve**: Build 6 custom services
**Cost**: 17 weeks + 18-30 hrs/week
**Total**: Costs MORE than using Harness

### The Architectural Difference

**GitHub**: Parallel workflow execution
- Cannot enforce "deploy ONLY IF security passes"
- Developers control workflow files
- Configuration distributed across 1000 repos

**Harness**: Sequential pipeline execution
- Deploy cannot run until Security stage passes
- Platform team controls templates (locked)
- Configuration centralized

**At 1000+ repos, architectural enforcement > process-based enforcement.**

---

**[← Back to README](../README.md)** | **[Technical Analysis](TECHNICAL_ANALYSIS.md)** | **[Hands-On Guide](HANDS_ON_GUIDE.md)**
