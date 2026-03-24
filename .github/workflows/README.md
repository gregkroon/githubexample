---

# 🧠 Extension: What Happens When You Scale This Pattern

## The “Frankenstein Architecture” Tax

The workflows in this demo are intentionally real.

They show what happens when you extend GitHub Actions beyond CI into full CD.

---

## ⚠️ The Reality at Scale

You don’t just use GitHub Actions.

You end up building this:

GitHub Actions (CI + orchestration trigger)
↓
Terraform (infrastructure provisioning)
↓
Argo CD (Kubernetes deployments)
↓
Custom Scripts (Lambda, ECS, VMs)
↓
Custom Verification Logic (monitoring APIs)
↓
Custom Approval Systems (Slack / PR / scripts)
↓
Custom State Tracking (or manual inspection)


---

## 💥 Result

> Your platform team becomes an integration team

---

# The 3 Enterprise Gaps (Proven by This Demo)

These are not theoretical.

They are visible in the workflows you just saw.

---

## 1. 🧾 The State & Visibility Gap

### What you see in this demo

- CD workflows:
  - resolve image tags → digests  
  - verify attestations  
  - deploy  

But after deployment…

👉 There is **no system of record**

---

### The Problem

GitHub Actions is:

> Stateless and ephemeral

Each run:
- executes  
- completes  
- disappears  

---

### So the question becomes:

> “What is currently running in production?”

---

### GitHub Reality

You must:

- inspect workflow logs  
- check Kubernetes state  
- verify deployment manually  

⏱ 10–15 minutes  

---

### At scale

Across:
- Kubernetes  
- Lambda  
- ECS  
- VMs  

👉 There is **no single answer**

---

### Harness Contrast

- Persistent deployment state  
- Queryable environments  
- Single view across all infrastructure  

⏱ Seconds  

---

## 2. 🔍 The Verification Gap (“Deploy and Pray”)

### What you saw in this demo

Verification =

- smoke tests  
- curl checks  
- scripted validation  

---

### The Problem

A successful deploy only means:

> “The container started”

It does NOT mean:

- latency is acceptable  
- error rates are stable  
- downstream dependencies are healthy  

---

### GitHub Workaround

You must build:

- API polling scripts  
- threshold logic  
- wait timers  
- failure handling  

---

### Reality

- hard-coded thresholds  
- noisy signals  
- manual tuning  
- inconsistent across services  

---

### Harness Contrast

- Native observability integration  
- Automated anomaly detection  
- deployment-aware verification  
- automatic rollback on failure  

---

## 3. 🏗️ The Heterogeneous Infrastructure Problem

### The strongest counter-argument you’ll hear:

> “Just use GitHub + Argo CD (GitOps)”

---

### That works well for:

✅ Kubernetes  

---

### But enterprises actually run:

- EC2 / VMs  
- AWS Lambda  
- ECS / Fargate  
- Azure / GCP services  
- databases  
- legacy workloads  

---

## ❗ Critical Insight

> Argo solves Kubernetes CD only

---

### Everything else becomes:

- Terraform orchestration  
- CLI wrappers  
- bash / Python scripts  
- more GitHub workflows  

---

### Result

👉 Multiple deployment patterns:

| Workload     | Deployment Method        |
|--------------|------------------------|
| Kubernetes   | Argo CD                |
| Lambda       | Custom scripts         |
| ECS          | Terraform / CLI        |
| VMs          | SSH / config mgmt      |

---

### This leads to:

- inconsistent processes  
- fragmented governance  
- duplicated effort  
- higher failure rates  

---

### Harness Contrast

Single deployment model across:

- Kubernetes  
- Serverless  
- ECS  
- VMs  
- databases  

---

# 📊 What This Means for Your Platform Team

## With GitHub + Argo + Terraform

Your team owns:

- integration between tools  
- workflow maintenance  
- security enforcement logic  
- deployment scripting  
- rollback design  
- debugging across systems  

---

## With Harness

Your team focuses on:

- developer productivity  
- platform capabilities  
- higher-level abstractions  

---

# ⚖️ The Real Trade-Off

| Approach                    | Outcome                                      |
|----------------------------|----------------------------------------------|
| GitHub + Toolchain         | Maximum control, maximum integration cost    |
| Harness Platform           | Standardization, reduced operational burden  |

---

# 🎯 Bringing It Back to This Demo

Everything you saw:

- SBOM validation  
- signing + verification  
- deployment orchestration  
- rollback process  

👉 was built manually

---

## This is the key takeaway

> This demo is not showing a limitation of GitHub

---

> It is showing the **cost of turning GitHub into a platform**

---

# 🧪 Run the Demo Yourself

## 1. Make a Change

```bash
echo "console.log('Test deployment');" >> services/user-service/src/index.js

git add .
git commit -m "Test real CI/CD"
git push origin main
