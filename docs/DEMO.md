# Technical Proof: The Frankenstein Architecture in Action

**Time**: 20 minutes
**What You'll See**: Real examples showing why GitHub Actions CD creates architectural sprawl

---

## Setup

This repository has 3 real microservices with working CI/CD:

- **user-service** (Node.js)
- **payment-service** (Go)
- **notification-service** (Python)

Each has: Build → Test → Security Scan → Deploy

**Fork and watch**:
```bash
gh repo fork gregkroon/githubexperiment
cd githubexperiment
echo "test" >> README.md && git commit -am "trigger deploy" && git push
gh run watch
```

**Live workflows**: https://github.com/gregkroon/githubexperiment/actions

---

## Problem 1: The Stateless Runner Problem

### The Architecture Reality

**What GitHub Actions Actually Does**:
```yaml
# .github/workflows/deploy.yml
name: Deploy
on: push

jobs:
  deploy:
    runs-on: ubuntu-latest  # ← Ephemeral VM (destroyed after run)
    steps:
      - name: Build
        run: npm run build

      - name: Deploy
        run: kubectl apply -f k8s/deployment.yaml

      # ✅ Deployment succeeds
      # ❌ Runner is destroyed
      # ❌ No record of what was deployed
      # ❌ No rollback capability
```

**What happens after deployment**:
- Runner VM is **destroyed**
- No persistent state remains
- You must build external systems to answer:
  - "What version is in production?"
  - "When was it deployed?"
  - "Who deployed it?"
  - "What was the previous version?"

### The Frankenstein Solution

To get basic deployment capabilities, you must add:

```
┌─────────────────────────────────────────────────────────┐
│  1. ArgoCD (for deployment history)                     │
│     └─ Tracks current state in Kubernetes               │
│     └─ Only works for K8s, not VMs/Lambda/databases     │
└─────────────────────────────────────────────────────────┘
                          +
┌─────────────────────────────────────────────────────────┐
│  2. Custom state tracker service                        │
│     └─ Database to record: service, version, timestamp  │
│     └─ API to query deployment history                  │
│     └─ Maintenance: 4-6 hours/week                      │
└─────────────────────────────────────────────────────────┘
                          +
┌─────────────────────────────────────────────────────────┐
│  3. Observability platform integration                  │
│     └─ Datadog/New Relic deployment markers             │
│     └─ Custom scripts to correlate deploys with metrics │
└─────────────────────────────────────────────────────────┘
```

**You're now maintaining 3 separate systems for basic "what's deployed where?" visibility.**

---

## Problem 2: The Rollback Coordination Nightmare

### The Scenario: Multi-Service Deployment Fails

**Real-world composite release**:
1. Database migration (add `user_preferences` table)
2. Backend API (reads from `user_preferences`)
3. Frontend (UI for user preferences)

### Try It: Deploy and Break

```bash
# Simulate a coordinated deployment
cd user-service
echo "-- Add user_preferences table" > migrations/001_add_preferences.sql
git add . && git commit -m "Add user preferences feature"
git push

# Watch 3 separate workflows run:
# 1. Database migration workflow ✅
# 2. Backend API workflow ✅
# 3. Frontend workflow ❌ (simulated S3 failure)
```

### What Actually Happens

**GitHub Actions + ArgoCD + Terraform approach**:

```yaml
# Workflow 1: database/.github/workflows/deploy.yml
jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - run: flyway migrate
      # ✅ SUCCESS: user_preferences table created
      # ❌ No coordination with other services
```

```yaml
# Workflow 2: backend-api/.github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: kubectl apply -f k8s/
      # ✅ SUCCESS: API deployed, reads from user_preferences
      # ❌ No check if database migration succeeded
```

```yaml
# Workflow 3: frontend/.github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: aws s3 sync build/ s3://frontend-bucket/
      # ❌ FAILS: S3 permissions error
```

**Current State**:
- ✅ Database: `user_preferences` table exists
- ✅ Backend: Deployed and working
- ❌ Frontend: Deployment failed
- 💥 **Production is broken** (backend expects frontend, frontend isn't there)

### The Manual Rollback Process

**What you must do manually**:

```bash
# 1. Notice the failure (5 min)
# - Frontend deploy failed
# - But database and backend succeeded
# - System is in inconsistent state

# 2. Coordinate rollback (10-15 min)

# Rollback frontend (doesn't exist, nothing to do)
# ✅ Easy

# Rollback backend
cd backend-api
git revert HEAD
git push
# Wait for: build (2 min) + test (2 min) + deploy (2 min) = 6 min

# Rollback database
cd database
# ❌ Table already has data!
# ❌ Can't just drop table (data loss)
# Must write custom down migration
echo "DROP TABLE user_preferences;" > migrations/down.sql
flyway undo
# Hope no other service started using this table

# 3. Verify system is restored (5 min)
# - Check backend is serving old version
# - Check database migration rolled back
# - Check for orphaned data
# - Check dependent services

# TOTAL TIME: 20-30 minutes
```

**Impact**:
- 30 minutes of broken production
- Manual coordination across 3 repos
- Risk of data loss in database rollback
- **No automatic detection, no automatic recovery**

### The Harness Approach

```yaml
# Single pipeline with automatic coordination
pipeline:
  name: User Preferences Feature

  stages:
    - stage:
        name: Database Migration
        type: Database
        spec:
          migration: user_preferences
        rollbackSteps:
          - FlywayUndo

    - stage:
        name: Backend API
        type: Deployment
        spec:
          service: backend-api
          dependsOn: [Database Migration]  # Won't run if DB fails
        rollbackSteps:
          - K8sRollback

    - stage:
        name: Frontend
        type: Deployment
        spec:
          service: frontend
          dependsOn: [Backend API]  # Won't run if backend fails
        rollbackSteps:
          - S3Rollback
        # ❌ FAILS HERE

  # Automatic rollback sequence:
  # 1. Frontend deployment fails
  # 2. Harness automatically triggers:
  #    - Backend K8sRollback
  #    - Database FlywayUndo
  # 3. System restored to consistent state
  #
  # TOTAL TIME: < 2 minutes
```

**Key difference**: One pipeline coordinator vs three independent workflows.

---

## Problem 3: The Governance Nightmare

### The Reality: 3,000 Workflow Files

**Your enterprise**:
- 1,000 microservices
- 3 environments (dev, staging, prod)
- 3 workflow files per service
- **= 3,000 workflow files to maintain**

### Try to Enforce a Policy

**Requirement**: All production deployments must:
1. Require manual approval
2. Block during blackout windows (Fri 4pm - Mon 8am)
3. Wait 1 hour after staging deployment
4. Block if active P1 incidents exist

### The GitHub Actions Approach

**You must implement in 3,000 separate files**:

```yaml
# Repo 1: user-service/.github/workflows/prod.yml
jobs:
  deploy:
    environment:
      name: production
      # Manual approval (built-in) ✅

    steps:
      # Blackout window check (custom script)
      - name: Check deployment window
        run: |
          # ❌ Custom bash logic
          HOUR=$(date +%H)
          DAY=$(date +%u)
          if [ $DAY -eq 5 ] && [ $HOUR -ge 16 ]; then
            echo "Deployment blocked: Friday after 4pm"
            exit 1
          fi

      # Soak time check (custom script)
      - name: Check staging soak time
        run: |
          # ❌ Query custom state tracker API
          STAGING_TIME=$(curl https://state-tracker/api/staging-deploy-time)
          # ❌ Calculate time difference
          # ❌ Exit if < 1 hour

      # Incident check (custom script)
      - name: Check active incidents
        run: |
          # ❌ Query PagerDuty API
          # ❌ Parse JSON response
          # ❌ Exit if P1 incidents exist

      - name: Deploy
        run: kubectl apply -f k8s/
```

**Now multiply this by 3,000 workflow files.**

### What Happens Over Time

**Month 1**: Team A copies the template correctly
**Month 3**: Team B copies an old version (missing incident check)
**Month 6**: Team C modifies blackout window logic (different time zone)
**Month 12**: Team D removes soak time check ("we deploy faster")

**Result**: **Configuration drift across 3,000 files**

### Compliance Audit Scenario

**Auditor**: "Show me all production deployments last quarter that violated the 1-hour soak time requirement."

**With GitHub Actions**:
```bash
# 1. Clone 1,000 repos
for repo in $(cat repos.txt); do
  git clone $repo
done

# 2. Parse 3,000 workflow files
for workflow in */.github/workflows/prod.yml; do
  # Extract soak time logic (if it exists)
  # Hope it's implemented consistently
done

# 3. Query workflow run logs (if not deleted)
gh api repos/{org}/{repo}/actions/runs --paginate

# 4. Correlate workflow runs with deployments
# How do you know which workflow actually deployed?
# ArgoCD has different timestamps
# Workflow logs might be deleted (90-day retention)

# 5. Manually verify each deployment
# Time required: 40-80 hours
```

**With Harness**:
```bash
# One API query
curl https://app.harness.io/api/deployments \
  -d 'environment=production' \
  -d 'startDate=2024-01-01' \
  -d 'endDate=2024-03-31' \
  -d 'policyViolation=soak_time'

# Response: JSON array of all violations
# Time required: 30 seconds
```

### The Harness Approach: Centralized Policy

```yaml
# One policy file for all 1,000 services
# File: .harness/policies/production-protection.yaml

apiVersion: policy.harness.io/v1
kind: Policy
metadata:
  name: Production Protection
  enforcement: HARD  # Cannot be bypassed

spec:
  rules:
    - name: Manual Approval Required
      type: approval
      enforcement: required

    - name: Blackout Windows
      type: deployment_window
      enforcement: required
      config:
        blackout:
          - days: [Friday, Saturday, Sunday]
            start: "16:00"
            end: "08:00"
            timezone: "America/New_York"
          - dates: ["2024-12-24", "2024-12-25"]  # Holidays

    - name: Staging Soak Time
      type: soak_time
      enforcement: required
      config:
        environment: staging
        minimumDuration: 1h

    - name: Incident Check
      type: external_check
      enforcement: required
      integration: pagerduty
      config:
        blockOnSeverity: ["P1", "P2"]

# Services reference this policy automatically
pipeline:
  environment: production  # ← Policy automatically applied
```

**Result**:
- **1 policy file** instead of 3,000 workflow files
- Automatic enforcement (no drift)
- Audit trail built-in
- Changes apply to all services instantly

---

## Problem 4: The Platform Team Burden

### Where Time Actually Goes

**6-person platform engineering team with GitHub Actions CD**:

```
Weekly Time Allocation:

Monday:
  - 4 hours: Debug ArgoCD sync failures
  - 2 hours: Help Team X with failed deployment
  - 2 hours: Fix Terraform state lock issue

Tuesday:
  - 3 hours: Update Flyway scripts across 50 services
  - 2 hours: Investigate "what version is in prod?" for Team Y
  - 3 hours: Write custom script to enforce new policy

Wednesday:
  - 4 hours: Upgrade GitHub Actions runners (security patch)
  - 2 hours: Fix broken Lambda deployment script
  - 2 hours: Coordinate multi-service rollback for Team Z

Thursday:
  - 3 hours: Review 47 Dependabot PRs (action version updates)
  - 3 hours: Standardize workflow files across repos
  - 2 hours: Debug "kubectl connection refused" in CI

Friday:
  - 3 hours: Emergency rollback (production incident)
  - 2 hours: Post-mortem documentation
  - 3 hours: Update deployment runbooks

──────────────────────────────────────────────────────
Total: 40 hours maintaining glue code
       0 hours building developer productivity features
```

**2-person platform engineering team with Harness**:

```
Weekly Time Allocation:

Monday:
  - 1 hour: Review Harness dashboard for deployment trends
  - 3 hours: Build new developer self-service portal
  - 4 hours: Design improved CI caching strategy

Tuesday:
  - 1 hour: Update deployment policy (1 file change)
  - 6 hours: Build automated environment provisioning

Wednesday:
  - 2 hours: Investigate failed deployment (Harness pinpointed root cause)
  - 5 hours: Implement developer productivity improvements

Thursday:
  - 1 hour: Configure new service in Harness
  - 6 hours: Build internal platform documentation

Friday:
  - 1 hour: One-click rollback (production incident)
  - 30 min: Post-mortem (Harness provided deployment timeline)
  - 5 hours: Strategic planning for Q2 platform improvements

──────────────────────────────────────────────────────
Total: 6 hours managing deployments
       34 hours building developer productivity features
```

**The difference**:
- GitHub Actions team: **100% reactive firefighting**
- Harness team: **85% proactive feature building**

---

## Problem 5: The Heterogeneous Infrastructure Reality

### Your Actual Infrastructure

```
1000 services deployed across:
  ├─ 300 Kubernetes pods (30%)
  ├─ 200 AWS Lambda functions (20%)
  ├─ 180 ECS/Fargate containers (18%)
  ├─ 150 EC2 VMs (15%)
  ├─ 100 RDS databases (10%)
  ├─ 50 On-premise VMs (5%)
  └─ 20 Azure App Services (2%)
```

### The GitHub Actions Approach

**You must maintain deployment scripts for each platform**:

```yaml
# Kubernetes deployment (~80 lines)
- name: Deploy to K8s
  run: |
    kubectl apply -f k8s/deployment.yaml
    kubectl rollout status deployment/$SERVICE
    kubectl rollout history deployment/$SERVICE

# Rollback K8s (~20 lines)
- name: Rollback K8s
  if: failure()
  run: kubectl rollout undo deployment/$SERVICE
```

```yaml
# Lambda deployment (~60 lines)
- name: Deploy Lambda
  run: |
    aws lambda update-function-code \
      --function-name $FUNCTION_NAME \
      --zip-file fileb://function.zip

    aws lambda wait function-updated \
      --function-name $FUNCTION_NAME

    aws lambda publish-version \
      --function-name $FUNCTION_NAME

# Rollback Lambda (~40 lines)
- name: Rollback Lambda
  if: failure()
  run: |
    # Get previous version
    PREV_VERSION=$(aws lambda list-versions-by-function ...)
    # Update alias to previous version
    aws lambda update-alias ...
```

```yaml
# ECS deployment (~90 lines)
- name: Deploy to ECS
  run: |
    aws ecs register-task-definition \
      --cli-input-json file://task-definition.json

    aws ecs update-service \
      --cluster $CLUSTER \
      --service $SERVICE \
      --task-definition $TASK_DEF

    aws ecs wait services-stable \
      --cluster $CLUSTER \
      --services $SERVICE

# Rollback ECS (~50 lines)
- name: Rollback ECS
  if: failure()
  run: |
    # Get previous task definition
    # Update service to previous version
```

```yaml
# VM deployment (~120 lines)
- name: Deploy to VM
  run: |
    # SSH to server
    ssh $USER@$SERVER "systemctl stop $SERVICE"

    # Copy new version
    scp package.tar.gz $USER@$SERVER:/opt/$SERVICE/

    # Extract and restart
    ssh $USER@$SERVER "tar -xzf /opt/$SERVICE/package.tar.gz"
    ssh $USER@$SERVER "systemctl start $SERVICE"

    # Health check
    ssh $USER@$SERVER "curl http://localhost:8080/health"

# Rollback VM (~80 lines)
- name: Rollback VM
  if: failure()
  run: |
    # SSH to server
    # Copy previous version from backup
    # Restart service
```

```yaml
# RDS migration (~70 lines)
- name: Deploy Database
  run: |
    flyway -url=$DB_URL \
           -user=$DB_USER \
           -password=$DB_PASSWORD \
           migrate

# Rollback RDS (~60 lines)
- name: Rollback Database
  if: failure()
  run: |
    flyway undo
    # Hope your down migrations are correct
```

**Total custom deployment code**:
- K8s: 100 lines × 300 services = 30,000 lines
- Lambda: 100 lines × 200 services = 20,000 lines
- ECS: 140 lines × 180 services = 25,200 lines
- VMs: 200 lines × 150 services = 30,000 lines
- RDS: 130 lines × 100 services = 13,000 lines

**= 118,200 lines of deployment code to maintain**

**And every time a platform changes**:
- Kubernetes upgrades kubectl API → update 300 workflows
- AWS deprecates Lambda runtime → update 200 workflows
- Company migrates to ECS Fargate → rewrite 180 workflows

### The Harness Approach

```yaml
# Kubernetes deployment
- step:
    type: K8sRollingDeploy
    spec:
      manifests: k8s/
    # Built-in rollback: automatic

# Lambda deployment
- step:
    type: AwsLambda
    spec:
      function: ${service.name}
    # Built-in rollback: automatic

# ECS deployment
- step:
    type: EcsRollingDeploy
    spec:
      service: ${service.name}
    # Built-in rollback: automatic

# VM deployment
- step:
    type: SshDeploy
    spec:
      host: ${env.vm_host}
      package: ${artifact.path}
    # Built-in rollback: automatic

# RDS migration
- step:
    type: DatabaseMigration
    spec:
      migration: flyway
    # Built-in rollback: automatic
```

**Total custom code**: **0 lines**

**Platform changes**:
- Harness maintains integrations
- Your workflows don't change
- Upgrades are automatic

---

## The Bottom Line

### What You're Actually Choosing Between

**GitHub Actions CD**:
```
Architecture: GHA + Terraform + ArgoCD + Bash + Glue Code
Team: 6 engineers maintaining the Frankenstein
Time: 80% firefighting, 20% building
Cost: $8.9M (5 years)
Rollback: Manual, 25-40 minutes
Governance: 3,000 workflow files to audit
```

**Harness CD**:
```
Architecture: Single control plane
Team: 2 engineers configuring policies
Time: 15% managing, 85% building
Cost: $5.6M (5 years)
Rollback: Automatic, < 2 minutes
Governance: 1 policy file for all services
```

### The Strategic Question

**Do you want your platform team:**
- Maintaining deployment glue code?
- Building developer productivity features?

**GitHub Actions is excellent for CI.** Use it for build, test, and scan.

**For enterprise CD**, the architectural sprawl and operational burden of the Frankenstein stack costs more than a purpose-built platform.

---

**[← Back to README](../README.md)**
