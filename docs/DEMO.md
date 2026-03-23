# Technical Proof: The 3 Critical Enterprise Gaps

**Time**: 20 minutes
**What You'll See**: Hands-on demonstration of why GitHub Actions forces you to build the Frankenstein architecture

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

## Gap 1: The State & Visibility Gap

### The Problem: Stateless Ephemeral Runners

**What GitHub Actions Actually Does**:
```yaml
# .github/workflows/deploy.yml
name: Deploy
on: push

jobs:
  deploy:
    runs-on: ubuntu-latest  # ← Ephemeral VM (destroyed after run)
    steps:
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
- GitHub Actions has no idea what's actually running in production

### Try It: Answer "What's Deployed?"

**The Question**: "What version of user-service is deployed in production right now?"

**With GitHub Actions**:
```bash
# Option 1: Check GitHub Actions logs
gh run list --workflow=deploy.yml --limit=1
# ❌ Only tells you what workflow ran, not what's actually deployed

# Option 2: Check the deployment target
kubectl get deployment user-service -o yaml | grep image:
# Output: image: user-service:abc123def
# ❌ What commit is abc123def? When was it deployed? By whom?

# Option 3: Correlate git history with workflow runs
git log --oneline | head -20
gh run list --limit=20
# ❌ Manual correlation, takes 10-15 minutes

# Option 4: SSH into production and inspect
kubectl exec -it user-service-pod -- cat /app/version.txt
# ❌ If you even have version tracking built in
```

**Time to answer**: 10-15 minutes of manual investigation

### The Frankenstein Solution You Build

To get basic "what's deployed where?" visibility, enterprises build:

```
┌─────────────────────────────────────────────────────────┐
│  1. ArgoCD (for Kubernetes state)                       │
│     └─ Only works for K8s, not Lambda/VMs/databases    │
└─────────────────────────────────────────────────────────┘
                          +
┌─────────────────────────────────────────────────────────┐
│  2. Custom state tracker service                        │
│     └─ Database recording: service, version, timestamp │
│     └─ API to query deployment history                 │
│     └─ Maintenance: 4-6 hours/week                     │
└─────────────────────────────────────────────────────────┘
                          +
┌─────────────────────────────────────────────────────────┐
│  3. Datadog/New Relic deployment markers                │
│     └─ Custom scripts to send deployment events        │
│     └─ Still doesn't track rollback capability         │
└─────────────────────────────────────────────────────────┘
```

**You're now maintaining 3 separate systems for basic deployment visibility.**

### The Harness Approach

```yaml
# Harness tracks state automatically
# No custom code required

# Query current state:
curl https://app.harness.io/api/deployments/user-service/production
# Returns:
# {
#   "service": "user-service",
#   "environment": "production",
#   "version": "v1.2.4",
#   "artifact": "user-service:abc123def",
#   "deployedAt": "2024-03-23T17:30:00Z",
#   "deployedBy": "jane@company.com",
#   "previousVersion": "v1.2.3",
#   "rollbackAvailable": true
# }

# Time: 5 seconds
```

---

## Gap 2: The Verification Gap

### The Problem: "Deploy and Pray"

**A successful GitHub Actions deployment means**:
- ✅ The container started
- ❌ NOT that the application is healthy
- ❌ NOT that error rates are normal
- ❌ NOT that the deployment should continue

### What Enterprises Actually Write

**Real-world custom verification script**:
```yaml
# .github/workflows/deploy.yml
- name: Deploy to production
  run: kubectl apply -f k8s/

- name: Wait and verify
  run: |
    # Wait for rollout
    kubectl rollout status deployment/user-service

    # Hard-coded sleep
    sleep 300  # Wait 5 minutes for metrics

    # Query observability platform
    ERROR_RATE=$(curl -s -H "DD-API-KEY: ${{ secrets.DATADOG_KEY }}" \
      "https://api.datadoghq.com/api/v1/query?query=sum:trace.express.request.errors{service:user-service,env:production}.as_rate()" \
      | jq '.series[0].pointlist[-1][1]')

    # Hard-coded threshold
    if (( $(echo "$ERROR_RATE > 0.05" | bc -l) )); then
      echo "ERROR: Error rate is ${ERROR_RATE}% (threshold: 5%)"
      exit 1
    fi

    echo "Verification passed: Error rate is ${ERROR_RATE}%"
```

**Problems with this approach**:

1. **Hard-coded thresholds**: 5% might be normal for this service during peak hours
2. **No baseline comparison**: Doesn't compare to pre-deployment error rates
3. **False positives**: Unrelated traffic spike triggers rollback
4. **Wastes CI minutes**: 5-minute sleep on every deployment
5. **No automatic rollback**: Just fails the workflow, doesn't undo deployment
6. **Maintenance burden**: Every observability platform change breaks this script

### Try It: Deploy with Broken Verification

**Scenario**: Deploy a version that increases error rate by 3% (below threshold, but anomalous)

```bash
# Deploy version with subtle performance degradation
cd user-service
# Simulate slow database queries
echo "await new Promise(resolve => setTimeout(resolve, 200))" >> src/index.js
git commit -am "Add latency (below threshold)"
git push

# Watch deployment succeed despite degradation
gh run watch

# ✅ Deployment succeeds (errors < 5%)
# ❌ But service is degraded (3% error rate is 10x normal baseline)
# ❌ No rollback triggered
# ❌ Production is degraded until next deployment
```

### The Manual Rollback Process

**When engineers notice the problem** (30-60 minutes later):

```bash
# 1. Investigate (10-15 min)
# - Check Datadog dashboards
# - Correlate error spike with deployment time
# - Confirm it's the latest deployment

# 2. Decide to rollback (5 min)
# - Discuss with team
# - Verify no other changes deployed

# 3. Execute rollback (10-15 min)
cd user-service
git revert HEAD
git push

# Wait for full CI/CD:
# - Install dependencies (2 min)
# - Run tests (2 min)
# - Security scan (3 min)
# - Build image (2 min)
# - Deploy (3 min)
# Total: 12-15 minutes

# TOTAL TIME: 30-45 minutes from detection to recovery
```

**At $100k/hour downtime**: 30 minutes = **$50k incident cost**

### The Harness Approach

```yaml
# Harness Continuous Verification
stages:
  - stage:
      name: Deploy to Production
      type: Deployment
      spec:
        service: user-service
        environment: production

        # Native canary deployment
        strategy:
          canary:
            steps:
              - step: 10%  # Deploy to 10% of pods
              - step:
                  type: Verify
                  spec:
                    type: Datadog
                    sensitivity: Medium  # ML-based
                    duration: 5m
                    # ✅ Compares to baseline automatically
                    # ✅ Uses ML to detect anomalies
                    # ✅ No hard-coded thresholds

              - step: 50%  # If verification passes
              - step:
                  type: Verify
                  spec:
                    type: Datadog
                    duration: 5m

              - step: 100%  # Full rollout

        # Automatic rollback on failure
        rollbackSteps:
          - K8sRollingRollback
```

**What happens with the degraded deployment**:

```
1. Canary deploys to 10% of pods (1 min)
2. Harness ML analyzes Datadog metrics (5 min)
3. Detects 3% error rate is anomalous vs baseline (even though < 5%)
4. Automatically halts deployment
5. Automatically triggers rollback
6. Production restored

TOTAL TIME: 6-8 minutes (85% faster than manual)
```

**Incident cost at $100k/hour**: 8 minutes = **$13k** (vs $50k manual)

---

## Gap 3: The Heterogeneous Infrastructure Tax

### The Reality: You're Not 100% Kubernetes

**Typical enterprise infrastructure breakdown**:
```
1000 services distributed across:
  ├─ 40% Kubernetes (400 services)
  ├─ 30% Serverless/ECS (300 services)
  ├─ 20% EC2/VMs (200 services)
  └─ 10% Managed Databases (100 services)
```

**ArgoCD handles 40%. What about the other 60%?**

### What You Actually Build

**For each platform, you maintain custom deployment scripts**:

#### Kubernetes (ArgoCD handles this ✅)
```yaml
# .github/workflows/deploy-k8s.yml
- name: Deploy to Kubernetes
  run: |
    kubectl apply -f k8s/deployment.yaml
    kubectl rollout status deployment/$SERVICE

# Rollback:
- run: kubectl rollout undo deployment/$SERVICE
```

**Lines per service**: ~80
**Services**: 400
**Total**: 32,000 lines

---

#### AWS Lambda (Custom scripts ❌)
```yaml
# .github/workflows/deploy-lambda.yml
- name: Package Lambda
  run: |
    pip install -r requirements.txt -t package/
    cd package && zip -r ../function.zip .
    cd .. && zip -g function.zip lambda_function.py

- name: Deploy Lambda
  run: |
    aws lambda update-function-code \
      --function-name $FUNCTION_NAME \
      --zip-file fileb://function.zip

    aws lambda wait function-updated \
      --function-name $FUNCTION_NAME

    # Publish new version
    VERSION=$(aws lambda publish-version \
      --function-name $FUNCTION_NAME \
      --query 'Version' --output text)

    # Update alias to new version
    aws lambda update-alias \
      --function-name $FUNCTION_NAME \
      --name production \
      --function-version $VERSION

- name: Rollback Lambda (if deployment fails)
  if: failure()
  run: |
    # Get previous version
    PREV_VERSION=$(aws lambda list-versions-by-function \
      --function-name $FUNCTION_NAME \
      --query 'Versions[-2].Version' --output text)

    # Point alias back
    aws lambda update-alias \
      --function-name $FUNCTION_NAME \
      --name production \
      --function-version $PREV_VERSION
```

**Lines per service**: ~100
**Services**: 200
**Total**: 20,000 lines

**Maintenance burden**:
- AWS deprecates Python 3.8 → update 200 workflows
- Lambda packaging changes → update 200 workflows
- IAM policy updates → update 200 workflows

---

#### EC2/VMs (Custom scripts ❌)
```yaml
# .github/workflows/deploy-vm.yml
- name: Deploy to VMs
  run: |
    # Stop service
    ssh $USER@$SERVER "sudo systemctl stop $SERVICE"

    # Backup current version
    ssh $USER@$SERVER "sudo cp -r /opt/$SERVICE /opt/$SERVICE.backup"

    # Copy new version
    scp -r build/* $USER@$SERVER:/tmp/$SERVICE/
    ssh $USER@$SERVER "sudo cp -r /tmp/$SERVICE/* /opt/$SERVICE/"

    # Restart service
    ssh $USER@$SERVER "sudo systemctl start $SERVICE"

    # Health check
    sleep 10
    HEALTH=$(ssh $USER@$SERVER "curl -s http://localhost:8080/health" | jq -r '.status')

    if [ "$HEALTH" != "ok" ]; then
      echo "Health check failed, rolling back"
      ssh $USER@$SERVER "sudo systemctl stop $SERVICE"
      ssh $USER@$SERVER "sudo rm -rf /opt/$SERVICE"
      ssh $USER@$SERVER "sudo mv /opt/$SERVICE.backup /opt/$SERVICE"
      ssh $USER@$SERVER "sudo systemctl start $SERVICE"
      exit 1
    fi
```

**Lines per service**: ~120
**Services**: 200
**Total**: 24,000 lines

**Maintenance burden**:
- SSH key rotation → update 200 workflows
- Systemd changes → update 200 workflows
- Backup strategy changes → update 200 workflows

---

#### RDS Databases (Custom scripts ❌)
```yaml
# .github/workflows/deploy-database.yml
- name: Run database migration
  run: |
    # Download Flyway
    wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/9.0.0/flyway-commandline-9.0.0-linux-x64.tar.gz | tar xvz

    # Run migration
    ./flyway-9.0.0/flyway \
      -url="jdbc:postgresql://${{ secrets.DB_HOST }}:5432/${{ secrets.DB_NAME }}" \
      -user="${{ secrets.DB_USER }}" \
      -password="${{ secrets.DB_PASSWORD }}" \
      migrate

- name: Rollback database (if migration fails)
  if: failure()
  run: |
    ./flyway-9.0.0/flyway \
      -url="jdbc:postgresql://${{ secrets.DB_HOST }}:5432/${{ secrets.DB_NAME }}" \
      -user="${{ secrets.DB_USER }}" \
      -password="${{ secrets.DB_PASSWORD }}" \
      undo
```

**Lines per service**: ~80
**Services**: 100
**Total**: 8,000 lines

**Maintenance burden**:
- Flyway version updates → update 100 workflows
- Database credential rotation → update 100 workflows
- Migration strategy changes → update 100 workflows

---

### Total Custom Deployment Code

```
Kubernetes:  32,000 lines (ArgoCD reduces this)
Lambda:      20,000 lines
VMs:         24,000 lines
Databases:    8,000 lines
─────────────────────────
TOTAL:       84,000 lines of custom deployment code to maintain
```

**Every infrastructure change propagates to hundreds of workflows.**

### The Harness Approach

**Same deployment logic, all platforms**:

```yaml
# Harness pipeline handles all infrastructure types
stages:
  - stage:
      name: Deploy Kubernetes
      type: Deployment
      spec:
        service: user-service
        infrastructure: kubernetes
        strategy: Canary
        # Native K8s support, no custom code

  - stage:
      name: Deploy Lambda
      type: Deployment
      spec:
        service: user-service-lambda
        infrastructure: aws-lambda
        strategy: AllAtOnce
        # Native Lambda support, no custom code

  - stage:
      name: Deploy to VMs
      type: Deployment
      spec:
        service: user-service-vm
        infrastructure: ssh
        strategy: Rolling
        # Native SSH deployment, no custom code

  - stage:
      name: Database Migration
      type: Deployment
      spec:
        service: user-service-db
        infrastructure: database
        migration: flyway
        # Native Flyway integration, no custom code
```

**Custom code required**: **0 lines**

**Platform changes**:
- AWS deprecates runtime → Harness updates Lambda integration
- Flyway releases new version → Harness updates database integration
- Your workflows: **unchanged**

---

## The Bottom Line

### What GitHub Actions Forces You to Build

```
ArgoCD (for 40% of infrastructure)
  + Custom Lambda deployer (20,000 lines)
  + Custom VM deployer (24,000 lines)
  + Custom database migrator (8,000 lines)
  + Custom state tracker (for "what's deployed?")
  + Custom verification scripts (for health checks)
  + Custom approval system (for manual gates)

= The Frankenstein Architecture
= Your platform team maintaining glue code instead of building features
```

### What Harness Provides

```
Single control plane
  + Native multi-infrastructure support
  + Built-in state tracking
  + ML-driven verification
  + Automatic rollback
  + Native approval workflows

= Zero custom deployment code
= Platform team builds developer portals instead
```

---

## Try It Yourself

### Exercise 1: State Check
```bash
# How long does it take to answer:
# "What version of user-service is in production right now?"

time (gh run list && kubectl get deployment user-service -o yaml | grep image)

# GitHub Actions: 10-15 minutes (manual correlation)
# Harness: 5 seconds (API query)
```

### Exercise 2: Verification Test
```bash
# Deploy code with subtle performance degradation
echo "await new Promise(r => setTimeout(r, 200))" >> user-service/src/index.js
git commit -am "Add latency" && git push

# Does your pipeline catch this?
# GitHub Actions: No (unless you wrote custom verification)
# Harness: Yes (ML detects baseline deviation)
```

### Exercise 3: Multi-Platform Deployment
```bash
# Deploy the same service to:
# 1. Kubernetes
# 2. AWS Lambda
# 3. EC2 VM

# Count the custom code required
# GitHub Actions: ~300 lines of bash/Python
# Harness: ~30 lines of YAML (native integrations)
```

---

**[← Back to README](../README.md)**
