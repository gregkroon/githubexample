# Technical Proof: GitHub Actions vs Harness CD

**Time**: 15 minutes
**What You'll See**: Real code showing where GitHub Actions breaks down

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

## Problem 1: No Rollback (The Friday 5pm Disaster)

### The Scenario

Production breaks. How fast can you recover?

### Try It

```bash
# Break production
cd user-service
echo "// broken code" >> src/index.js
git commit -am "deploy broken code" && git push

# Watch it deploy
gh run watch
```

**What happened**: Broken code deployed to production

**Now try to roll back**:
- ❌ No rollback button
- ❌ No previous version tracking
- ❌ Must revert code + redeploy EVERYTHING

### The GitHub Actions Way

```bash
# Manual recovery process
git revert HEAD              # Revert the code
git push                     # Trigger full CI/CD again

# Wait for complete rebuild:
# - Install dependencies (2 min)
# - Run tests (2 min)
# - Security scan (3 min)
# - Build image (2 min)
# - Deploy (3 min)
# TOTAL: 12-15 minutes
```

### The Harness Way

```yaml
# One click rollback
- Previous version: user-service:v1.2.3
- Current version: user-service:v1.2.4 (broken)
- Action: Rollback to v1.2.3

# Time: < 1 minute
# No rebuild needed
# No code changes needed
```

**Impact**:
- GitHub: 15 minutes × $5M/hour = **$1.25M lost**
- Harness: 1 minute × $5M/hour = **$83k lost**
- **Savings: $1.17M per incident**

---

## Problem 2: No Deployment State (Where Did It Go?)

### The Scenario

Production is broken. What version is running?

### Try It

**With GitHub Actions**:
```bash
# Where can you see current deployed version?
# ❌ Not in GitHub Actions UI
# ❌ Not in workflow logs (they expire)
# ❌ Not tracked anywhere

# Must manually check:
kubectl get deployment user-service -o yaml | grep image
# Output: image: user-service:abc123def
# ❌ What version is abc123def? When was it deployed? By whom?

# Must dig through git history manually
git log --oneline | grep "deploy"
# ❌ Still don't know which commit is actually deployed
```

**Time to figure out current state**: 10-15 minutes

### The Harness Way

```yaml
# Deployment dashboard shows:
Service: user-service
Environment: production
Current Version: v1.2.4
Deployed: 2024-03-23 17:30 UTC
Deployed By: jane@company.com
Previous Version: v1.2.3
Rollback Available: Yes

# Time to see current state: 5 seconds
```

---

## Problem 3: No Multi-Service Coordination

### The Scenario

Deploy 3 services that depend on each other:

1. **Database schema** (add new column)
2. **Backend API** (uses new column)
3. **Frontend** (shows new data)

**Requirement**: If any fails, all must rollback.

### GitHub Actions Implementation

```yaml
# ❌ Cannot coordinate across repos
# Must use 3 separate workflows

# Workflow 1: database-migrations/.github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: flyway migrate
      # ✅ Succeeds

# Workflow 2: backend-api/.github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: kubectl apply -f k8s/
      # ✅ Succeeds

# Workflow 3: frontend/.github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: aws s3 sync build/ s3://frontend/
      # ❌ FAILS (S3 permissions error)
```

**What happened**:
- ✅ Database: new column added
- ✅ Backend: deployed (expects new column)
- ❌ Frontend: failed to deploy
- 💥 **System is broken** (backend shows errors, no matching UI)

**Rollback**:
- Must manually rollback backend
- Must manually rollback database (but column already added - can't undo!)
- **Time: 30-60 minutes**

### The Harness Way

```yaml
pipeline:
  stages:
    - stage: Database
      steps:
        - FlywayMigrate
      rollbackSteps:
        - FlywayUndo

    - stage: Backend API
      dependsOn: [Database]  # Won't run if Database fails
      steps:
        - K8sDeploy
      rollbackSteps:
        - K8sRollback

    - stage: Frontend
      dependsOn: [Backend API]  # Won't run if Backend fails
      steps:
        - S3Sync
      # ❌ Fails here

# Automatic rollback sequence:
# 1. Detect Frontend failure
# 2. Rollback Backend API
# 3. Rollback Database
# Time: < 2 minutes
```

---

## Problem 4: The Supply Chain Attack

### The Vulnerability

Look at any workflow in this repo:

```yaml
# .github/workflows/user-service.yml
- uses: actions/checkout@v4
- uses: actions/setup-node@v4
- uses: aquasecurity/trivy-action@v0.24.0  # ⚠️ MUTABLE TAG
```

**What could go wrong**:

```bash
# Attacker compromises Trivy maintainer account
# Force-pushes malicious code to v0.24.0 tag
git tag -d v0.24.0
git tag v0.24.0
git push --force origin v0.24.0

# Malicious code in trivy-action:
# - Steals $AWS_ACCESS_KEY_ID
# - Steals $AWS_SECRET_ACCESS_KEY
# - Steals $KUBECONFIG
# - Exfiltrates to attacker server
```

**Next workflow run**:
- ✅ Pulls malicious v0.24.0
- ✅ Executes credential stealer
- ✅ Attacker gets AWS keys, K8s access
- 💥 **Full infrastructure compromise**

**Your exposure**:
- 1000 services × 15 actions = 15,000 mutable dependencies
- **One compromised action = $50M+ breach**

### The "Pin to SHA" Defense

**Security team says**: Use immutable SHA

```yaml
- uses: aquasecurity/trivy-action@d9cd5b1c8ee3c92e2b2c7b1c3e4f5a6b7c8d9e0f
```

**The operational reality**:
- 15,000 dependencies × monthly updates = 15,000 SHA updates
- Dependabot creates 15,000 pull requests per month
- **1.4 people full-time just reviewing dependency updates**
- Reviews become rubber-stamps → vulnerabilities persist anyway

### The Harness Way

```yaml
# Use internal template library
steps:
  - step:
      type: SecurityScan
      spec:
        template: trivy-enterprise-v2  # Internal vetted template
```

**Security**:
- 50 templates (not 15,000 marketplace actions)
- Security team vets each template once
- Zero external marketplace exposure
- **8 hours/month** (not 1.4 people full-time)

---

## Problem 5: Multi-Platform Hell

### The Reality

Typical enterprise infrastructure:

- 30% Kubernetes
- 20% VMs (Linux + Windows)
- 20% ECS/Fargate
- 15% Lambda
- 10% On-premise
- 5% Other (Azure, GCP, etc.)

### GitHub Actions Approach

**Must write custom scripts for each**:

```yaml
# Kubernetes (~150 lines)
- run: |
    kubectl apply -f k8s/
    kubectl rollout status deployment/app
    kubectl rollout undo deployment/app  # Rollback

# VMs (~200 lines)
- run: |
    ssh user@server "systemctl stop app"
    scp package.tar.gz user@server:/opt/app
    ssh user@server "systemctl start app"
    # Rollback? Manual file copy

# ECS (~180 lines)
- run: |
    aws ecs register-task-definition --cli-input-json file://task.json
    aws ecs update-service --cluster prod --task-definition app:v2
    # Rollback? Update to previous task def

# Lambda (~150 lines)
- run: |
    aws lambda update-function-code --function-name app
    # Rollback? Shift alias to previous version

# VMs Windows (~220 lines)
- run: |
    winrm invoke-command -c "Stop-Service app"
    scp app.zip Administrator@server:C:\\app
    # Rollback? Hope you have backup

# On-premise (~250 lines)
- run: |
    vpn connect
    ansible-playbook deploy.yml
    # Rollback? Good luck
```

**Total**: 1,150 lines × 1000 services = **1.15 million lines of deployment code**

### The Harness Way

```yaml
# All platforms supported natively
- step: K8sDeploy         # Kubernetes
- step: SshDeploy         # VMs
- step: EcsDeploy         # ECS
- step: LambdaDeploy      # Lambda
- step: AzureDeploy       # Azure
- step: CustomDeploy      # On-premise

# Total custom code: 0 lines
# Vendor maintains integrations
```

---

## The Complete Cost

### GitHub Actions (5 Years)

**What you must build**:
- Rollback system: 8 weeks
- State tracker: 8 weeks
- Health monitoring: 6 weeks
- Multi-service orchestrator: 12 weeks
- Database coordinator: 4 weeks
- Release calendar: 10 weeks
- Supply chain security: 6 weeks

**Total**: 54 weeks + 6.4 people ongoing

**Cost**: $9.0M

### Harness (5 Years)

**What you get**:
- Rollback: Built-in
- State tracking: Built-in
- Health monitoring: Built-in ML
- Orchestration: Built-in
- Database DevOps: Built-in
- Release management: Built-in
- Supply chain security: Built-in

**Total**: 4 weeks setup + 2 people ongoing

**Cost**: $5.5M

**Savings**: $3.5M (39%)

---

## Try It Yourself

### Exercise 1: Rollback Test

```bash
# Deploy broken code
echo "bad code" >> user-service/src/index.js
git commit -am "break production" && git push

# Time how long to recover
# GitHub Actions: 12-15 minutes
# Harness: < 1 minute
```

### Exercise 2: State Check

```bash
# What version is in production right now?
# GitHub Actions: Must manually investigate
# Harness: Visible in dashboard
```

### Exercise 3: Multi-Service Deploy

```bash
# Deploy 3 dependent services
# GitHub Actions: 3 separate workflows, manual coordination
# Harness: 1 pipeline, automatic coordination
```

---

## The Bottom Line

**GitHub Actions**:
- $9M over 5 years
- 6.4 people maintaining
- 1.15M lines of custom code
- 15-minute rollback time
- No deployment state
- 15,000 security dependencies

**Harness**:
- $5.5M over 5 years
- 2 people managing
- 0 lines of custom code
- < 1 minute rollback time
- Complete deployment state
- 50 vetted templates

**Use GitHub Actions for what it's good at** (CI: build, test, scan)

**Use Harness for what it's good at** (CD: deploy, verify, rollback)

---

## Questions?

**"Can't we just add scripts to fix GitHub Actions?"**

You can. That's what the 54 weeks and 6.4 people are for. You'll spend $9M building a worse version of Harness.

**"What about Argo CD / Terraform / other tools?"**

Adding more tools doesn't fix the fundamental problems:
- Still no rollback for non-Kubernetes
- Still no deployment state tracking
- Still building custom integrations
- Now maintaining 3+ tools instead of 1

**"Isn't this vendor lock-in?"**

You're choosing between:
- Lock-in to 1.15M lines of custom code + 6.4 people (GitHub)
- Lock-in to vendor-supported platform (Harness)

Which is easier to migrate away from?

---

**[← Back to README](../README.md)**
