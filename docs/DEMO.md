# Technical Proof: The 3 Critical Enterprise Gaps

**Time**: 20 minutes
**What You'll See**: Real operational pain points that GitHub Actions + ArgoCD/Terraform cannot solve without custom engineering

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

## Gap 1: Cross-Environment Visibility (Not Single-Service State)

### The Real Problem

**It's not "can you check what's deployed?"** — You absolutely can:
```bash
kubectl get deployment user-service -o yaml | grep image:
# Output: user-service:abc123def
```

**The real problem is cross-environment visibility at scale.**

### The Question That Breaks GitHub Actions

**"Show me what version of all 50 microservices is deployed in Dev, QA, Staging, and Production right now."**

**With GitHub Actions + ArgoCD**:

```bash
# Option 1: Manual kubectl queries across 4 environments
for env in dev qa staging prod; do
  kubectl config use-context $env
  for service in $(cat services.txt); do
    kubectl get deployment $service -o jsonpath='{.spec.template.spec.containers[0].image}'
  done
done

# ❌ Must manually correlate 200 image tags with git commits
# ❌ No unified dashboard
# ❌ Takes 15-20 minutes to compile manually

# Option 2: Build a custom internal portal
# ❌ Requires building a web app
# ❌ Requires database to store deployment history
# ❌ Requires API to query GHA + ArgoCD + Kubernetes
# ❌ Requires maintenance: 4-6 hours/week
```

**Time to compile full environment matrix**: 15-20 minutes (manual) or build custom portal (weeks of engineering)

### What Enterprises Actually Build

To get cross-environment visibility, you build:

```
┌─────────────────────────────────────────────────────────┐
│  Custom Internal Portal                                 │
│  ├─ Database: deployment_history table                  │
│  ├─ API: /api/deployments?env=prod&service=user-service│
│  ├─ UI: Dashboard showing all envs × all services       │
│  ├─ Integrations: GHA webhooks, ArgoCD sync events      │
│  └─ Maintenance: 4-6 hours/week                         │
└─────────────────────────────────────────────────────────┘
```

**Engineering cost**: 6-8 weeks to build, 4-6 hours/week to maintain

### The Harness Approach

**Built-in environment matrix dashboard**:
```bash
# Single API query
curl https://app.harness.io/api/services/matrix

# Returns:
# {
#   "user-service": {
#     "dev": "v1.2.5 (deployed 2h ago)",
#     "qa": "v1.2.4 (deployed 1d ago)",
#     "staging": "v1.2.4 (deployed 1d ago)",
#     "production": "v1.2.3 (deployed 3d ago)"
#   },
#   "payment-service": { ... },
#   ... (all 50 services)
# }

# Time: 5 seconds
# Maintenance: 0 hours (vendor maintains)
```

---

## Gap 2: Automated Verification Beyond Kubernetes

### The Real Problem

**It's not "can you do automated verification?"** — You can with Argo Rollouts:

```yaml
# Argo Rollouts for Kubernetes (works great!)
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 5m}
        - analysis:
            templates:
              - templateName: success-rate
```

**The real problem is: Argo Rollouts only works for Kubernetes.**

### What About Your AWS Lambdas? Your ECS Containers? Your VMs?

**30% of your infrastructure is Serverless/ECS. There is no "Argo Rollouts for Lambda."**

You have to write custom verification scripts in GitHub Actions:

```yaml
# .github/workflows/deploy-lambda.yml
- name: Deploy Lambda
  run: |
    aws lambda update-function-code \
      --function-name user-service \
      --zip-file fileb://function.zip

    # Update alias to point to new version
    VERSION=$(aws lambda publish-version --function-name user-service --query Version --output text)
    aws lambda update-alias --function-name user-service --name production --function-version $VERSION

- name: Verify Lambda deployment
  run: |
    # Wait for metrics to populate
    sleep 300  # 5 minutes

    # Query CloudWatch for error rate
    ERROR_RATE=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/Lambda \
      --metric-name Errors \
      --dimensions Name=FunctionName,Value=user-service \
      --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
      --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
      --period 300 \
      --statistics Sum \
      --query 'Datapoints[0].Sum' --output text)

    # Hard-coded threshold check
    if [ "$ERROR_RATE" -gt 5 ]; then
      echo "Lambda verification failed: $ERROR_RATE errors"

      # Manual rollback: point alias back to previous version
      PREV_VERSION=$(aws lambda list-versions-by-function \
        --function-name user-service \
        --query 'Versions[-2].Version' --output text)

      aws lambda update-alias \
        --function-name user-service \
        --name production \
        --function-version $PREV_VERSION

      exit 1
    fi
```

**Problems**:
1. **Hard-coded threshold** (5 errors) — might be normal during peak traffic
2. **No baseline comparison** — doesn't compare to historical error rates
3. **5-minute sleep** wastes CI runner time on every deployment
4. **Manual rollback logic** — you're writing your own deployment orchestration
5. **Maintenance burden** — every CloudWatch API change requires updating this script

### This Pattern Repeats for Every Non-Kubernetes Platform

**ECS/Fargate**:
```yaml
# Custom verification polling AWS CloudWatch Container Insights
# Custom rollback logic pointing ECS service to previous task definition
```

**VMs**:
```yaml
# Custom verification SSH-ing to server and checking /health endpoint
# Custom rollback logic SCP-ing previous version from backup
```

**You're maintaining platform-specific verification scripts for 60% of your infrastructure.**

### The Harness Approach

**Unified verification across all platforms**:

```yaml
# Same verification pattern for Kubernetes AND Lambda AND ECS AND VMs
stages:
  - stage:
      name: Deploy Lambda
      type: Deployment
      spec:
        service: user-service-lambda
        infrastructure: aws-lambda
        strategy:
          canary:
            steps:
              - step: 50%  # Deploy new version to 50% traffic

              - step:
                  type: Verify
                  spec:
                    type: CloudWatch  # Native integration
                    sensitivity: Medium  # ML-based anomaly detection
                    duration: 5m
                    metrics:
                      - Errors
                      - Duration
                    # ✅ Compares to baseline automatically
                    # ✅ No hard-coded thresholds
                    # ✅ Auto-rollback on anomaly

              - step: 100%  # Full rollout if verification passes

        rollbackSteps:
          - LambdaRollback  # Native Lambda rollback
```

**Key differences**:
- Same verification pattern works for K8s, Lambda, ECS, VMs
- ML-based baseline comparison (not hard-coded thresholds)
- Automatic rollback (no custom scripts)
- Vendor maintains CloudWatch/Datadog/NewRelic integrations

---

## Gap 3: Ongoing Maintenance Burden of Reusable Workflows

### The Real Problem

**It's not "you'll write 84,000 lines of custom code."** Smart teams use Reusable Workflows to centralize deployment logic.

**The real problem is: Your platform team is now on the hook for maintaining that centralized deployment logic forever.**

### What You Actually Centralize

**Centralized Lambda deployment reusable workflow**:

```yaml
# .github/workflows/reusable-lambda-deploy.yml
name: Deploy Lambda (Reusable)

on:
  workflow_call:
    inputs:
      function-name:
        required: true
      runtime:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Package Lambda
        run: |
          # Install dependencies
          pip install -r requirements.txt -t package/

          # Create deployment package
          cd package && zip -r ../function.zip .
          cd .. && zip -g function.zip lambda_function.py

      - name: Deploy to AWS
        run: |
          # Update function code
          aws lambda update-function-code \
            --function-name ${{ inputs.function-name }} \
            --zip-file fileb://function.zip

          # Wait for update to complete
          aws lambda wait function-updated \
            --function-name ${{ inputs.function-name }}

          # Publish new version
          VERSION=$(aws lambda publish-version \
            --function-name ${{ inputs.function-name }} \
            --query Version --output text)

          # Update production alias
          aws lambda update-alias \
            --function-name ${{ inputs.function-name }} \
            --name production \
            --function-version $VERSION

      - name: Verify deployment
        run: |
          # Custom CloudWatch polling logic
          # (50+ lines of bash parsing AWS CLI output)

      - name: Rollback on failure
        if: failure()
        run: |
          # Custom rollback logic
          # (30+ lines of bash to revert alias)
```

**Total**: ~150 lines of centralized deployment logic

**This works great!** All 200 Lambda services call this reusable workflow.

### The Maintenance Burden No One Talks About

**Scenario 1: AWS deprecates Python 3.8 runtime** (happens every 2 years)

```yaml
# Your platform team must:
# 1. Update the reusable workflow to support Python 3.9/3.10
# 2. Test the new packaging logic across all Lambda configurations
# 3. Coordinate rollout across 200 Lambda services
# 4. Handle edge cases (some services still need 3.8)
# 5. Update documentation and notify all teams

# Engineering cost: 2-3 weeks
# Ongoing risk: Breaking changes affect 200 services
```

**Scenario 2: AWS changes Lambda versioning API** (happens occasionally)

```yaml
# The publish-version command changes behavior
# Your platform team must:
# 1. Debug why deployments suddenly started failing
# 2. Update the reusable workflow
# 3. Test across all environments
# 4. Coordinate emergency rollout

# Engineering cost: 1 week emergency work
# Business impact: Deployment pipeline blocked
```

**Scenario 3: Security team requires Lambda layer support**

```yaml
# New requirement: All Lambdas must use centralized security layer
# Your platform team must:
# 1. Add layer support to reusable workflow
# 2. Handle layer versioning
# 3. Update verification logic
# 4. Test across 200 Lambdas
# 5. Document new parameters

# Engineering cost: 3-4 weeks
```

**This pattern repeats for every platform**:
- ECS task definition changes
- VM systemd config updates
- Database migration tool updates
- Kubernetes API deprecations

### The Harness Approach

**Vendor maintains the deployment integrations**:

```yaml
# Your pipeline YAML stays the same
stages:
  - stage:
      name: Deploy Lambda
      type: Deployment
      spec:
        service: user-service
        infrastructure: aws-lambda
        # Native Lambda support maintained by Harness

# When AWS deprecates Python 3.8:
# ✅ Harness updates their Lambda integration
# ✅ Your pipeline YAML: unchanged
# ✅ Your platform team: zero work

# When AWS changes versioning API:
# ✅ Harness handles the change
# ✅ Your deployments: keep working
# ✅ Your platform team: zero emergency work

# When security requires Lambda layers:
# ✅ Harness adds native layer support
# ✅ You configure it in YAML
# ✅ No custom bash script updates
```

**The strategic difference**:

| What Changes | GitHub Actions (Your Team) | Harness (Vendor) |
|--------------|----------------------------|------------------|
| AWS Lambda API changes | Update reusable workflow | Harness updates integration |
| ECS API changes | Update reusable workflow | Harness updates integration |
| Kubernetes deprecations | Update reusable workflow | Harness updates integration |
| New security requirements | Implement in bash scripts | Configure in YAML |
| **Annual maintenance burden** | **80-120 hours/year** | **~10 hours/year (config changes)** |

---

## The Bottom Line

### What GitHub Actions + ArgoCD Actually Forces You to Maintain

```
Gap 1: Cross-Environment Visibility
  → Build custom internal portal (6-8 weeks)
  → Maintain database + API + UI (4-6 hours/week)

Gap 2: Verification Beyond Kubernetes
  → Write custom CloudWatch/Datadog polling scripts
  → Maintain platform-specific verification for Lambda/ECS/VMs
  → Update scripts when observability APIs change

Gap 3: Reusable Workflow Maintenance
  → Maintain centralized Lambda deployer
  → Maintain centralized ECS deployer
  → Maintain centralized VM deployer
  → Update all three when AWS/Azure/GCP APIs change
  → Annual burden: 80-120 hours/year per platform

= Your platform team is a deployment integration maintenance team
```

### What Harness Provides

```
Gap 1: Built-in environment matrix dashboard
  → Zero custom portal to build
  → Zero database to maintain

Gap 2: Unified verification across all platforms
  → Native CloudWatch/Datadog integration
  → Same ML-based verification for K8s, Lambda, ECS, VMs
  → Vendor maintains observability integrations

Gap 3: Vendor-maintained deployment integrations
  → Native support for all platforms
  → Vendor handles AWS/Azure/GCP API changes
  → Your platform team configures, doesn't maintain

= Your platform team builds developer productivity features
```

---

## Try It Yourself

### Exercise 1: Cross-Environment Visibility
```bash
# How long does it take to compile a matrix showing:
# - All 3 microservices
# - Across 4 environments (dev, qa, staging, prod)
# - With version numbers and deployment timestamps

# With GitHub Actions + ArgoCD:
# 1. Query kubectl for each service in each environment
# 2. Correlate image tags with git commits
# 3. Look up deployment times from GHA logs
# Time: 15-20 minutes of manual work

# With Harness:
# curl https://app.harness.io/api/services/matrix
# Time: 5 seconds
```

### Exercise 2: Lambda Verification Without Custom Scripts
```bash
# Deploy a Lambda with automated verification (no Argo Rollouts)

# With GitHub Actions:
# Write custom bash script polling CloudWatch
# Implement hard-coded threshold logic
# Implement manual rollback on failure
# Code required: ~80 lines

# With Harness:
# Configure native CloudWatch verification
# ML-based baseline comparison
# Automatic rollback
# Code required: ~15 lines of YAML
```

### Exercise 3: Runtime Deprecation Impact
```bash
# Scenario: AWS deprecates Python 3.8 runtime next month
# You have 50 Lambda functions using Python 3.8

# With GitHub Actions Reusable Workflows:
# 1. Update centralized deployment workflow
# 2. Test across all Lambda configurations
# 3. Coordinate rollout to 50 functions
# 4. Handle edge cases and failures
# Engineering time: 2-3 weeks

# With Harness:
# 1. Harness updates Lambda integration
# 2. Your pipelines: unchanged
# Engineering time: 0 hours
```

---

## The Honest Assessment

**GitHub Actions + ArgoCD is excellent if**:
- You have < 50 services
- 90%+ of infrastructure is Kubernetes
- Your platform team has bandwidth to build custom tooling
- You're okay maintaining reusable workflows as AWS/Azure/GCP APIs change

**Harness makes sense if**:
- You have 100+ services across heterogeneous infrastructure
- You need cross-environment visibility without building a portal
- You want automated verification for Lambda/ECS/VMs (not just K8s)
- You'd rather your platform team build features than maintain deployment integrations

**The question**: Do you want your platform engineers maintaining deployment tooling, or building the next generation of developer productivity features?

---

**[← Back to README](../README.md)**
