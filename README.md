# GitHub Actions vs Harness CD: The Frankenstein Architecture Tax

**The brutal truth about scaling GitHub Actions for enterprise Continuous Delivery**

---

## The Verdict

GitHub Actions is the industry standard for **Continuous Integration (CI)**. But forcing a CI tool to handle enterprise **Continuous Delivery (CD)** creates an expensive, fragmented Frankenstein architecture of open-source tools and custom glue code.

| Feature | GitHub Actions "CD" Stack | Harness CD |
|---------|---------------------------|------------|
| **Architecture** | GHA + Terraform + ArgoCD + Bash + Python | Single Purpose-Built Control Plane |
| **Platform Team Focus** | 6 engineers (spending 60%+ time maintaining glue code) | 2 engineers (spending 10% on config, 90% on features) |
| **Deployment State** | None (stateless ephemeral runners) | Persistent, queryable, and auditable |
| **Verification** | Manual review or custom API polling scripts | Automated ML-driven anomaly detection |
| **Governance** | Centralized templates wrapping disparate scripts | Native RBAC and OPA policy enforcement |

**Result**: Harness frees your most expensive platform engineers to build features instead of maintaining internal deployment tools, while cutting incident recovery time by 85%.

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
└─────────────────────────────────────────────────────────┘

= Your platform engineering team becomes a full-time
  integration maintenance team.
```

---

## The 3 Critical Enterprise Gaps

These aren't theoretical gaps. They are the exact reasons your platform team is constantly firefighting.

### 1. The State & Visibility Gap (Stateless Runners)

GitHub Actions runners are **stateless, ephemeral VMs**. They run a job and die. They have no memory of what they deployed, what version is currently running in production, or how to roll it back.

**The GHA Workaround**: You implement ArgoCD for your Kubernetes workloads. But what about your AWS Lambdas, your EC2 instances, and your legacy databases? You have to build a **custom internal state-tracking service** or grep through 90 days of fragmented GitHub logs.

**The Harness Reality**: Harness is **stateful**. It provides a single pane of glass showing exactly what artifact version is running in every environment across K8s, Serverless, and legacy VMs.

**Real-world impact**:
- **Question**: "What version of user-service is deployed in production right now?"
- **GHA Answer**: Grep GitHub logs → check ArgoCD → SSH to prod → inspect manually (**10-15 minutes**).
- **Harness Answer**: Query dashboard API (**5 seconds**).

---

### 2. The Verification Gap ("Deploy and Pray")

A successful deployment just means **the container started**. It doesn't mean **the application is healthy**.

**The GHA Workaround**: Your engineers write custom bash scripts inside your GitHub Actions to curl your Datadog or New Relic APIs, wait 5 minutes, and **guess** if the error rate spike is related to the deployment. You are hard-coding thresholds and fighting false positives.

**The Harness Reality**: **Continuous Verification**. Harness natively connects to your observability tools. It uses **Machine Learning** to analyze logs and metrics during a canary or blue/green rollout. If it detects a **baseline anomaly**, it automatically halts the pipeline and initiates a safe rollback procedure.

---

### 3. The Heterogeneous Infrastructure Tax

GitOps (ArgoCD + GHA) is fantastic **if your enterprise is 100% modern Kubernetes**. Very few enterprises are.

**The Reality**: A typical enterprise runs 40% Kubernetes, 30% Serverless/ECS, 20% EC2/VMs, and 10% managed databases.

**The GHA Workaround**: You have a clean ArgoCD setup for K8s, but you rely on a complex web of centralized Terraform modules, AWS CLI wrappers, and bash scripts to deploy to everything else. Every time AWS deprecates a runtime, or Helm updates a version, your team has to update and test internal tooling.

**The Harness Reality**: Harness provides **native, standardized deployment templates** for K8s, Helm, Serverless, Tanzu, traditional VMs, and databases. The integration maintenance burden is shifted to the vendor.

---

## FAQ: The Engineer's Reality Check

If you are a Platform Engineer or DevOps Architect reading this, let's address the elephant in the room:

### "We use GitHub Reusable Workflows. We don't have configuration sprawl."

**Reality**: Reusable workflows are a massive improvement for CI. But for CD, they only solve the **templating problem**, not the **capabilities problem**. Yes, you have one centralized `deploy.yml`. But inside that YAML, your team is still writing and maintaining the custom Datadog polling scripts, the complex rollback logic, and the manual approval API calls. You are **centralizing your custom glue code**, not eliminating it.

---

### "ArgoCD + GitHub Actions is the CNCF industry standard. Why buy a monolith?"

**Reality**: GitOps is the standard for **Kubernetes**. But the moment you need to orchestrate a complex release train (e.g., "Deploy K8s microservice A, update RDS database schema, then deploy Lambda B, wait for manual QA approval, then update the API Gateway"), **ArgoCD cannot coordinate that across different infrastructure types**. Harness handles multi-service pipeline orchestration natively.

---

### "A git revert is instant. Harness can't make Kubernetes roll back faster."

**Reality**: You are absolutely right—the **execution** of pulling an old container image is fast in both systems. But the delay in a custom CD stack isn't execution; it's the **human detection and decision time**.

**Manual timeline**: Errors appear (2m) → PagerDuty fires (5m) → Engineer opens laptop & investigates (12m) → Decision to revert (18m) → git revert pushed & synced (20m).

**Harness ML timeline**: Errors appear (2m) → ML detects anomaly vs baseline (3m) → Auto-rollback triggered and synced (5m).

**At $100k/hour of downtime, saving 15 minutes per incident pays for the platform.**

---

### "We don't want vendor lock-in with Harness."

**Reality**: Lock-in is unavoidable; you just get to choose your flavor. **Option A** is locking into a commercial CD platform that abstracts the deployment logic and maintains the integrations for you. **Option B** is locking into your own **Internal Technical Debt**—relying on a web of custom bash, Python, and YAML scripts that tie your deployment logic directly to GitHub's specific runner environment and APIs. One of these options allows your engineers to build product features; the other forces them to maintain internal tooling.

---

## When to Use What

### ✅ Use GitHub Actions (CI + GitOps CD) If:

- You have **< 50 microservices**.
- Your infrastructure is nearly **100% Kubernetes** (ArgoCD handles this beautifully).
- Your platform team has the **bandwidth to build and maintain internal deployment tooling**.
- You do not have strict, heterogeneous compliance and audit requirements.

---

### ✅ Use Harness CD If:

- You manage **100+ services** across heterogeneous infrastructure (K8s, VMs, Serverless, DBs).
- You require **automated, ML-driven deployment verification** and rollback orchestration.
- You need centralized, strict governance (**OPA policies, RBAC, single-click audit trails**).
- You want your expensive Platform Engineers **building developer portals and productivity tools**, not debugging internal deployment scripts.

---

## The Strategic Question

Do you want your platform engineers:
- **Maintaining deployment glue code** (GitHub Actions CD)
- **Building internal developer productivity features** (Harness CD)

---

## Where to Go Next

**For Technical Proof**: Read [DEMO.md](docs/DEMO.md) for hands-on demonstration of all 3 enterprise gaps with real code examples.

---

## License

MIT - Use this to make informed platform decisions

