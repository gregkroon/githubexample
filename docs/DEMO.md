# Technical Proof: The 3 Critical Enterprise Gaps

**Time:** 20 minutes
**What You'll See:** Real operational pain points that GitHub Actions + ArgoCD/Terraform cannot solve without custom engineering.

---

## Setup

This repository has 3 real microservices with working CI/CD:

- **user-service** (Node.js)
- **payment-service** (Go)
- **notification-service** (Python)

Each has a standard pipeline: Build → Test → Security Scan → Deploy

**Fork and watch:**
```bash
gh repo fork gregkroon/githubexperiment
cd githubexperiment
echo "test" >> README.md && git commit -am "trigger deploy" && git push
gh run watch
```

**Live workflows**: https://github.com/gregkroon/githubexperiment/actions

---

## Gap 1: The State & Visibility Gap (Stateless Runners)

### The Real Problem

GitHub Actions runners are **stateless, ephemeral VMs**. They run a job and die. They have no memory of what they deployed, what version is currently running in production, or how to roll it back.

**It's not "can you check what's deployed?"** — You absolutely can:
```bash
kubectl get deployment user-service -o yaml | grep image:
# Output: user-service:abc123def
```

**The real problem is cross-environment visibility at scale** when runners have no deployment state.

### The Question That Breaks GitHub Actions

**"Show me what version of all 50 microservices is deployed in Dev, QA, Staging, and Production right now."**

**With GitHub Actions + ArgoCD:**

```bash
# Option 1: Manual kubectl queries across 4 environments
for env in dev qa staging prod; do
  kubectl config use-context $env
  for service in $(cat services.txt); do
    kubectl get deployment $service -o jsonpath='{.spec.template.spec.containers[0].image}'
  done
done
# ❌ Must manually correlate 200 image tags with git commits
# ❌ Takes 15-20 minutes to compile manually
```

### The GHA Workaround

Because GitHub Actions runners are stateless (no deployment memory), Platform Teams are forced to implement an **Internal Developer Portal (IDP)** like **Spotify Backstage** to track deployment state.

But Backstage isn't free visibility. Your platform team is now on the hook for writing and maintaining custom data-aggregation plugins to stitch together GitHub Actions logs, ArgoCD sync states, and AWS Lambda versions. **You are maintaining a complex data pipeline just to answer "what's in production?"**

### The Harness Reality

Harness is **stateful**. It provides a single pane of glass showing exactly what artifact version is running in every environment across K8s, Serverless, and legacy VMs.

**Built-in environment matrix dashboard out of the box:**

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
# Integration Maintenance: 0 hours
```

---

## Gap 2: The Verification Gap ("Deploy and Pray")

### The Real Problem

A successful deployment just means **the container started**. It doesn't mean **the application is healthy**.

Modern enterprises run diverse infrastructure. While Argo Rollouts handles Kubernetes beautifully with automated verification, 30-50% of your footprint consists of **AWS Lambdas, ECS Containers, and legacy EC2 VMs.**

There is no "Argo Rollouts for Lambda." GitHub Actions is just a CI runner, meaning it has zero native understanding of cloud-specific deployment verification strategies.

### The GHA Workaround: Custom Bash Scripts Around Terraform

Your engineers write custom bash scripts inside GitHub Actions to curl your Datadog or New Relic APIs, wait 5 minutes, and **guess** if the error rate spike is related to the deployment. You are hard-coding thresholds and fighting false positives.

Mature teams don't use raw bash scripts to deploy; they use Infrastructure as Code (Terraform or AWS CDK). But **Terraform is declarative state, not a release orchestrator.**

If you want a safe Canary rollout for an AWS Lambda (Deploy 10% → Wait 5 mins → Check Datadog → Deploy 100% OR Rollback), Terraform cannot do that natively. You still have to write custom GitHub Actions scripts to loop, wait, and orchestrate the Terraform applies:

```yaml
# .github/workflows/deploy-lambda-canary.yml
- name: Execute Orchestrated Canary
  run: |
    # 1. Apply Terraform with 10% Canary Weight
    terraform apply -var="canary_weight=0.1" -auto-approve

    # 2. Wait for metrics to populate
    sleep 300

    # 3. Custom verification: Query CloudWatch for error rate
    ERROR_RATE=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/Lambda --metric-name Errors \
      --dimensions Name=FunctionName,Value=user-service \
      --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
      --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum \
      --query 'Datapoints[0].Sum' --output text)

    # 4. Hard-coded threshold check & Manual Rollback
    if [ "$ERROR_RATE" -gt 5 ]; then
      echo "Canary failed. Executing rollback..."
      terraform apply -var="canary_weight=0.0" -auto-approve
      exit 1
    fi

    # 5. Complete the rollout
    terraform apply -var="canary_weight=1.0" -auto-approve
```

**The structural flaws of this approach:**

- **You are building a custom CD orchestrator:** You are manually scripting the wait states and metric polling around your IaC.
- **Hard-coded thresholds:** 5 errors might be normal during peak traffic, resulting in false-positive rollbacks.
- **Highly Fragile:** This orchestration pattern must be rebuilt from scratch for ECS, for EC2, and for databases.

### The Harness Reality: Continuous Verification

**Continuous Verification**: Harness natively connects to your observability tools. It uses **Machine Learning** to analyze logs and metrics during a canary or blue/green rollout. If it detects a **baseline anomaly**, it automatically halts the pipeline and initiates a safe rollback procedure.

Harness treats K8s, Serverless, and VMs as first-class citizens. You get Canary, Blue/Green, and ML-driven Verification natively across **all** of them, orchestrating your IaC without writing a single line of bash.

```yaml
# Advanced deployment + Verification requires NO custom scripting
stages:
  - stage:
      name: Deploy Lambda
      type: Deployment
      spec:
        infrastructure: aws-lambda
        strategy:
          canary:  # Native Lambda Canary
            steps:
              - step: 10%  # Harness handles the traffic shift

              - step:
                  type: Verify
                  spec:
                    type: CloudWatch  # Native integration
                    sensitivity: Medium  # ML-based anomaly vs historical baseline
                    duration: 5m
                    # ✅ Harness orchestrates the wait and check
                    # ✅ ML compares to baseline automatically
                    # ✅ Auto-rollback on anomaly

              - step: 100% # Full rollout
```

---

## Gap 3: The Heterogeneous Infrastructure Tax

### The Real Problem

GitOps (ArgoCD + GHA) is fantastic **if your enterprise is 100% modern Kubernetes**. Very few enterprises are.

**The Reality**: A typical enterprise runs 40% Kubernetes, 30% Serverless/ECS, 20% EC2/VMs, and 10% managed databases.

Smart teams use **GitHub Reusable Workflows** to centralize deployment logic across this heterogeneous infrastructure.

**But your platform team is now on the hook for maintaining that centralized deployment API forever.**

### The GHA Workaround: Reusable Workflows + Terraform Modules

You have a clean ArgoCD setup for K8s, but you rely on a complex web of centralized **GitHub Reusable Workflows**, **Terraform modules**, and **AWS CLI wrappers** to deploy to everything else.

Let's say you have a beautifully centralized Reusable Workflow for deploying to AWS Lambda. All 200 Lambda services call it.

**Every time AWS deprecates a runtime, or Helm updates a version, your team has to update and test internal tooling.**

**Scenario: AWS deprecates the Python 3.8 runtime** (happens every 2 years)

- **The GHA Burden:** Your platform team must update the reusable workflow, test the new packaging logic across all Lambda configurations, coordinate the rollout across 200 services, and handle edge cases.
- **Engineering cost:** 2-3 weeks of toil.

---

**Scenario: AWS changes the Lambda versioning API**

- **The GHA Burden:** Deployments suddenly fail. Your team must debug the AWS CLI output, patch the reusable workflow, and coordinate an emergency rollout.
- **Business impact:** Deployment pipeline blocked; 1 week of emergency work.

---

### The Vendor Lock-In Paradox

When confronted with this, engineers often say: *"I don't want Harness because I don't want to wait for their product roadmap when AWS releases a new feature. Reusable Workflows give me control."*

This is the ultimate Buy vs. Build trap. Yes, relying on a vendor means you move at the speed of their roadmap for niche cloud features. **But control is expensive.** Is getting day-zero access to a new AWS sub-feature worth $150,000/year in engineer maintenance toil?

### The Harness Reality: Vendor-Maintained Integration Templates

Harness provides **native, standardized deployment templates** for K8s, Helm, Serverless, Tanzu, traditional VMs, and databases. The integration maintenance burden is shifted to the vendor.

**When AWS deprecates an API:**
- ✅ Harness updates their native integrations on the backend.
- ✅ Your pipeline YAML remains unchanged.
- ✅ Your platform team does zero emergency work.

| Event | GitHub Actions (Your Team) | Harness CD (The Vendor) |
|-------|----------------------------|-------------------------|
| **AWS/GCP/Azure API changes** | Update reusable workflow | Harness updates integration |
| **New security/compliance rules** | Implement in custom bash scripts | Configure in Native OPA YAML |
| **Annual maintenance burden** | 80-120 hours/year | ~10 hours/year (config updates) |

---

## The Honest Assessment

**GitHub Actions + ArgoCD is excellent if:**
- You have **< 50 services**.
- **90%+ of your infrastructure is modern Kubernetes**.
- Your platform team has the **bandwidth to build Backstage plugins** and orchestrate Terraform via custom scripts.

**Harness makes sense if:**
- You have **100+ services** across heterogeneous infrastructure.
- You need **cross-environment visibility without maintaining an IDP data pipeline**.
- You want **automated, ML-driven verification for Lambda/ECS/VMs** (not just K8s).
- **You'd rather your platform team build revenue-generating features than maintain deployment integrations.**

---

**[← Back to README](../README.md)**
