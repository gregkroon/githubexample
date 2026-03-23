# Technical Proof: The 3 Critical Enterprise Gaps

**Time**: 20 minutes
**What You'll See**: Real operational pain points that GitHub Actions + ArgoCD/Terraform cannot solve without custom engineering.

---

## Setup

This repository has 3 real microservices with working CI/CD:

- **user-service** (Node.js)
- **payment-service** (Go)
- **notification-service** (Python)

Each has a standard pipeline: Build → Test → Security Scan → Deploy

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
```

### What Enterprises Actually Build

To get cross-environment visibility, Platform Teams are forced to build an **Internal Developer Portal (IDP)**:

- **Database**: To track deployment history.
- **API**: To aggregate data from GHA webhooks, ArgoCD sync events, and K8s.
- **UI**: A dashboard showing the environment matrix.
- **Maintenance Tax**: 4-6 hours/week just keeping the portal running.

### The Harness Approach

**Built-in environment matrix dashboard out of the box.**

```bash
# Single API query
curl https://app.harness.io/api/services/matrix

# Returns:
# {
#   "user-service": {
#     "dev": "v1.2.5 (deployed 2h ago)",
#     "staging": "v1.2.4 (deployed 1d ago)",
#     "production": "v1.2.3 (deployed 3d ago)"
#   },
#   ... (all 50 services)
# }

# Time: 5 seconds
# Maintenance: 0 hours
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

**30-50% of enterprise infrastructure is Serverless, ECS, or EC2.** There is no "Argo Rollouts for Lambda."

You have to write custom verification scripts in GitHub Actions:

```yaml
# .github/workflows/deploy-lambda.yml
- name: Verify Lambda deployment
  run: |
    # Wait for metrics to populate
    sleep 300

    # Query CloudWatch for error rate
    ERROR_RATE=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/Lambda --metric-name Errors \
      --dimensions Name=FunctionName,Value=user-service \
      --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
      --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum \
      --query 'Datapoints[0].Sum' --output text)

    # Hard-coded threshold check
    if [ "$ERROR_RATE" -gt 5 ]; then
      echo "Lambda verification failed: $ERROR_RATE errors"
      # Manual rollback logic here...
      exit 1
    fi
```

**The problems with this approach**:

1. **Hard-coded thresholds**: 5 errors might be normal during peak traffic.
2. **No baseline comparison**: It doesn't compare to historical error rates.
3. **Wastes CI minutes**: A 5-minute sleep runs on every deployment runner.
4. **Fragile**: Every observability API change breaks your deployment pipeline.

**This pattern repeats for every non-Kubernetes platform (ECS, VMs, Databases).**

### The Harness Approach

**Unified Continuous Verification across all platforms.**

```yaml
# Same verification pattern for Kubernetes AND Lambda AND ECS AND VMs
stages:
  - stage:
      name: Deploy Lambda
      type: Deployment
      spec:
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
```

---

## Gap 3: Ongoing Maintenance Burden of Reusable Workflows

### The Real Problem

Smart teams don't write 84,000 lines of code; they use **GitHub Reusable Workflows** to centralize deployment logic.

**The real problem is: Your platform team is now on the hook for maintaining that centralized deployment API forever.**

### The Maintenance Burden No One Talks About

Let's say you have a beautifully centralized **150-line Reusable Workflow** for deploying to AWS Lambda. All 200 Lambda services call it.

**Scenario: AWS deprecates the Python 3.8 runtime** (happens every 2 years)

**The GHA Burden**: Your platform team must update the reusable workflow, test the new packaging logic across all Lambda configurations, coordinate the rollout across 200 services, and handle edge cases.

**Engineering cost**: 2-3 weeks of toil.

---

**Scenario: AWS changes the Lambda versioning API**

**The GHA Burden**: Deployments suddenly fail. Your team must debug the AWS CLI output, patch the reusable workflow, and coordinate an emergency rollout.

**Business impact**: Deployment pipeline blocked; 1 week of emergency work.

---

**This pattern repeats endlessly** for ECS task definition changes, VM systemd updates, and Database migration tool deprecations.

### The Harness Approach

**The vendor maintains the deployment integrations.**

When AWS deprecates Python 3.8 or changes their versioning API:
- ✅ Harness updates their native Lambda integration on the backend.
- ✅ Your pipeline YAML remains unchanged.
- ✅ Your platform team does zero emergency work.

| Event | GitHub Actions (Your Team) | Harness CD (The Vendor) |
|-------|----------------------------|-------------------------|
| AWS Lambda API changes | Update reusable workflow | Harness updates integration |
| ECS API changes | Update reusable workflow | Harness updates integration |
| New security requirements | Implement in bash scripts | Configure in YAML |
| **Annual maintenance burden** | **80-120 hours/year** | **~10 hours/year (config changes)** |

---

## The Honest Assessment

**GitHub Actions + ArgoCD is excellent if**:
- You have **< 50 services**.
- **90%+ of your infrastructure is modern Kubernetes**.
- Your platform team has the **bandwidth to build custom internal portals** and maintain observability scripts.

**Harness makes sense if**:
- You have **100+ services** across heterogeneous infrastructure.
- You need **cross-environment visibility without building an internal portal**.
- You want **automated, ML-driven verification for Lambda/ECS/VMs** (not just K8s).
- You'd rather your platform team **build developer productivity features** than maintain deployment integrations.

---

**[← Back to README](../README.md)**
