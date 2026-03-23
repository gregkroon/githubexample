# GitHub Actions vs Harness CD: The Frankenstein Architecture Tax

**The brutal truth about scaling GitHub Actions for enterprise Continuous Delivery**

---

## The Verdict

GitHub Actions is the industry standard for **Continuous Integration (CI)**. But forcing a CI tool to handle enterprise **Continuous Delivery (CD)** creates an expensive, fragmented Frankenstein architecture of open-source tools and custom glue code.

| Feature | GitHub Actions "CD" Stack | Harness CD |
|---------|---------------------------|------------|
| **Architecture** | GHA + Terraform + ArgoCD + Bash + Custom Scripts | Single Purpose-Built Control Plane |
| **5-Year TCO** | $8.9M | $5.6M |
| **Platform Team Focus** | 6 engineers (spending 60%+ time maintaining glue code) | 2 engineers (spending 10% on config, 90% on features) |
| **Deployment State** | None (stateless ephemeral runners) | Persistent, queryable, and auditable |
| **Verification** | Manual review or custom API polling scripts | Automated ML-driven anomaly detection |
| **Governance** | Centralized templates full of custom bash | Native RBAC and OPA policy enforcement |

**Result**: Harness saves **$3.3M (37%)** and frees your most expensive platform engineers to build features instead of maintaining deployment scripts.

**[See detailed financial analysis with math & sources →](docs/EXECUTIVE_SUMMARY.md)**

---

## The Core Problem: The Frankenstein Architecture

When you choose GitHub Actions for CD at scale, you don't just use GitHub Actions. You build a fragmented ecosystem:

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions (CI only)                               │
│  ├─ Build, test, security scan ✅                       │
│  └─ Deploy? ❌ Stateless, no native verification        │
└─────────────────────────────────────────────────────────┘
                          ↓
           "We need deployment capabilities"
                          ↓
┌─────────────────────────────────────────────────────────┐
│  The Frankenstein Stack                                 │
│  ├─ GitHub Actions (to trigger deployments)             │
│  ├─ ArgoCD (for Kubernetes state)                       │
│  ├─ Terraform (for infrastructure provisioning)         │
│  ├─ Custom Python/Bash (for Lambda/ECS deployments)     │
│  ├─ Custom API Polling Scripts (for health checks)      │
│  ├─ Custom Slack Bots (for manual approval gates)       │
│  └─ Custom State Tracker (to answer "what's in prod?")  │
└─────────────────────────────────────────────────────────┐

= Your platform engineering team becomes a full-time
  glue code maintenance team.
```

**[See it demonstrated in working examples →](docs/DEMO.md)**

---

## The 3 Critical Enterprise Gaps

These aren't theoretical gaps. They are the exact reasons your platform team is constantly firefighting.

### 1. The State & Visibility Gap (Stateless Runners)

GitHub Actions runners are **stateless, ephemeral VMs**. They run a job and die. They have no memory of what they deployed, what version is currently running in production, or how to roll it back.

**The GHA Workaround**: You implement ArgoCD for your Kubernetes workloads. But what about your AWS Lambdas, your EC2 instances, and your legacy databases? You have to build a **custom internal state-tracking service** or grep through 90 days of fragmented GitHub logs.

**The Harness Reality**: Harness is **stateful**. It provides a single pane of glass showing exactly what artifact version is running in every environment across K8s, Serverless, and legacy VMs.

**Real-world impact**:
- **Question**: "What version of user-service is deployed in production right now?"
- **GHA answer**: grep GitHub logs → check ArgoCD → SSH to prod → inspect manually (**10-15 minutes**)
- **Harness answer**: Query dashboard API (**5 seconds**)

**[See the state gap demonstrated →](docs/DEMO.md#problem-1-the-stateless-runner-problem)**

---

### 2. The Verification Gap ("Deploy and Pray")

A successful deployment just means **the container started**. It doesn't mean **the application is healthy**.

**The GHA Workaround**: Your engineers write custom bash scripts inside your GitHub Actions to curl your Datadog or New Relic APIs, wait 5 minutes, and **guess** if the error rate spike is related to the deployment.

Example from a real GitHub Actions workflow:
```yaml
- name: Verify deployment
  run: |
    sleep 300  # Wait 5 minutes
    ERROR_RATE=$(curl -H "DD-API-KEY: ${{ secrets.DATADOG }}" \
      "https://api.datadoghq.com/api/v1/query?query=..." | jq '.series[0].pointlist[-1][1]')
    if (( $(echo "$ERROR_RATE > 5" | bc -l) )); then
      echo "Deployment failed verification"
      exit 1
    fi
```

**Problems**:
- Hard-coded thresholds (5% error rate) - no baseline comparison
- 5-minute sleep wastes CI minutes
- False positives from unrelated traffic spikes
- No automatic rollback - just fails the workflow

**The Harness Reality**: **Continuous Verification**. Harness natively connects to your observability tools. It uses **Machine Learning** to analyze logs and metrics during a canary or blue/green rollout. If it detects a **baseline anomaly**, it automatically halts the pipeline and initiates a safe rollback procedure.

**Real-world impact**:
- **Scenario**: Deployment causes 10% error rate increase
- **GHA**: Deploy completes, errors appear, PagerDuty fires, engineer investigates, manual rollback (**30-40 minutes**)
- **Harness**: ML detects anomaly in 2 minutes, auto-rollback triggered (**< 6 minutes total**)
- **Savings**: $2.3M per incident (at $5M/hour revenue rate)

**[See verification gap demonstrated →](docs/DEMO.md#problem-2-the-rollback-coordination-nightmare)**

---

### 3. The Heterogeneous Infrastructure Tax

GitOps (ArgoCD + GHA) is fantastic **if your enterprise is 100% modern Kubernetes**. Very few enterprises are.

**The Reality**:
```
Typical Enterprise Infrastructure (1,000 services):
  ├─ 30% Kubernetes (ArgoCD works beautifully ✅)
  ├─ 20% AWS Lambda (custom scripts ❌)
  ├─ 18% ECS/Fargate (custom scripts ❌)
  ├─ 15% EC2 VMs (custom scripts ❌)
  ├─ 10% RDS databases (custom scripts ❌)
  └─ 7% Legacy on-premise (custom scripts ❌)
```

**The GHA Workaround**: You have a clean ArgoCD setup for K8s, but you rely on **thousands of lines of custom AWS CLI scripts, Terraform wrappers, and shell scripts** to deploy to ECS, serverless, and on-prem VMs.

**Code burden**:
- Kubernetes: 100 lines × 300 services = 30,000 lines
- Lambda: 100 lines × 200 services = 20,000 lines
- ECS: 140 lines × 180 services = 25,200 lines
- VMs: 200 lines × 150 services = 30,000 lines
- Databases: 130 lines × 100 services = 13,000 lines
- **Total: 118,000 lines of deployment code to maintain**

**The Harness Reality**: Harness provides **native, standardized deployment templates** for K8s, Helm, Serverless, Tanzu, traditional VMs, and databases. **One platform, regardless of the underlying infrastructure.**

Example Harness pipeline (same logic, all platforms):
```yaml
stages:
  - stage: Deploy to K8s
    type: Deployment
    spec:
      service: user-service
      infrastructure: kubernetes
      strategy: Canary  # Native support

  - stage: Deploy Lambda
    type: Deployment
    spec:
      service: user-service-lambda
      infrastructure: aws-lambda
      strategy: Canary  # Same pattern

  - stage: Deploy to VMs
    type: Deployment
    spec:
      service: user-service-vm
      infrastructure: ssh
      strategy: Rolling  # Same pattern
```

**Custom code required**: **0 lines**

**[See heterogeneous infrastructure demonstrated →](docs/DEMO.md#problem-5-the-heterogeneous-infrastructure-reality)**

---

## FAQ: The Engineer's Reality Check

If you are a Platform Engineer or DevOps Architect reading this, you probably have some objections. Let's address them directly.

### "We use GitHub Reusable Workflows. We don't have configuration sprawl."

**Reality**: Reusable workflows are a massive improvement for CI. But for CD, they only solve the **templating problem**, not the **capabilities problem**. Yes, you have one centralized `deploy.yml`. But inside that YAML, you still have to write and maintain the custom Datadog polling scripts, the complex rollback logic, and the manual approval API calls. You are **centralizing your custom glue code**, not eliminating it.

---

### "ArgoCD + GitHub Actions is the CNCF industry standard. Why buy a monolith?"

**Reality**: GitOps is the standard for **Kubernetes**. But the moment you need to orchestrate a complex release train (e.g., "Deploy K8s microservice A, update RDS database schema, then deploy Lambda B, wait for manual QA approval, then update the API Gateway"), **ArgoCD cannot coordinate that across different infrastructure types**. Harness handles complex, multi-service pipeline orchestration natively.

---

### "A git revert is instant. Harness can't make Kubernetes roll back faster."

**Reality**: The 30-minute delay isn't the **execution** of the rollback; it's the **human detection and decision time**.

Manual rollback timeline:
1. Deployment completes (0 min)
2. Errors appear in logs (2 min)
3. Error rate crosses threshold (5 min)
4. PagerDuty alert fires (7 min)
5. Engineer opens laptop (10 min)
6. Engineer investigates logs (15 min)
7. Engineer decides to rollback (20 min)
8. `git revert HEAD && git push` (21 min)
9. Full CI/CD runs again (build, test, scan, deploy) (35 min)
10. **Total: 35 minutes**

Harness automatic rollback:
1. Deployment completes (0 min)
2. Errors appear in logs (2 min)
3. Harness ML detects anomaly (3 min)
4. Automatic rollback triggered (4 min)
5. Rollback completes (6 min)
6. **Total: 6 minutes**

**Saves 29 minutes = $2.4M per incident** (at $5M/hour revenue rate)

---

### "Harness Delegates are complex to manage."

**Reality**: Deploying Harness Delegates requires an **initial architectural lift** (2 weeks of standard Terraform/Helm work). Once deployed, they **auto-upgrade** from Harness SaaS. Would you rather spend 2 weeks on standardized infrastructure, or spend the next 5 years debugging why a custom Python script failed to parse an AWS response token?

---

### "We don't want vendor lock-in with Harness."

**Reality**: **You are already locked in**. If your platform relies on custom bash, Python, and YAML scripts tying your deployment logic to GitHub's specific runner environment and APIs, you are locked into your own **Internal Technical Debt**. Commercial CD platforms abstract the deployment logic away from the CI runner, making it **easier to swap out your infrastructure or CI tools** in the future.

**Migration cost comparison**:
- **Off GitHub Actions CD**: Rewrite custom state tracker + rollback coordinator + health checks + retrain team + migrate 3,000 workflows
- **Off Harness**: Update pipeline YAML to new platform (standardized CD format)

---

## When to Use What

### ✅ Use GitHub Actions (CI + GitOps CD) If:

- You have **< 50 microservices**.
- Your infrastructure is nearly **100% Kubernetes** (ArgoCD handles this beautifully).
- Your platform team has the **bandwidth to maintain internal deployment tooling**.
- You do not have strict, heterogeneous compliance and audit requirements.

**Risk**: First multi-cloud mandate, database migration requirement, or compliance audit = rebuild everything.

---

### ✅ Use Harness CD If:

- You manage **100+ services** across heterogeneous infrastructure (K8s, VMs, Serverless, DBs).
- You require **automated, ML-driven deployment verification** and rollback orchestration.
- You need centralized, strict governance (**OPA policies, RBAC, single-click audit trails**).
- You want your expensive Platform Engineers **building developer portals and productivity tools**, not debugging deployment scripts.

**Benefit**: $3.3M saved + 4 engineers freed to build the future, not maintain the past.

---

## The Honest Conclusion

**GitHub Actions is the best CI platform.** Keep using it for build, test, and security scanning.

**GitHub Actions is not a CD platform.** Forcing it to handle enterprise deployment orchestration creates a Frankenstein architecture that costs **more than a purpose-built platform**.

**The real cost isn't the tools.** It's the **6-person platform team spending 60% of their time maintaining deployment glue** instead of building developer productivity features.

### The Strategic Question

Do you want your platform engineers:
- **Maintaining deployment glue code** (GitHub Actions CD)
- **Building internal developer portals** (Harness CD)

**One production outage pays for 1.5 years of Harness.**

---

## Live Proof

This repository has working GitHub Actions CI/CD pipelines. Fork it and experience the gaps firsthand:

```bash
gh repo fork gregkroon/githubexperiment
cd githubexperiment
echo "test" >> README.md && git commit -am "trigger deploy" && git push
gh run watch
```

**Then try**:
1. ❌ Deploy broken code and try to rollback (you'll manually revert + redeploy)
2. ❌ Check deployment history (you'll grep through logs or check ArgoCD)
3. ❌ Coordinate a multi-service deploy across K8s + Lambda + database (you'll write custom orchestration)

**[See detailed technical walkthrough →](docs/DEMO.md)**

---

## Where to Go Next

| Your Role | Start Here | Time |
|-----------|------------|------|
| **CFO, Finance VP** | [EXECUTIVE_SUMMARY.md](docs/EXECUTIVE_SUMMARY.md) - Complete TCO with math & sources | 10 min |
| **CTO, VP Engineering** | [README.md](README.md) (you are here) → [EXECUTIVE_SUMMARY.md](docs/EXECUTIVE_SUMMARY.md) | 15 min |
| **Platform Engineer** | [DEMO.md](docs/DEMO.md) - Hands-on proof of all gaps | 20 min |
| **Sending to Execs** | [EXECUTIVE_EMAIL.md](docs/EXECUTIVE_EMAIL.md) - Ready-to-send templates | 5 min |

---

## License

MIT - Use this to make informed platform decisions
