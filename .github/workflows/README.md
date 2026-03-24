# 🚀 Real CI/CD Demo — What It Actually Takes to Build This on GitHub

## ALL 3 SERVICES ARE RUNNING. THIS IS NOT A TOY.

This repository demonstrates a **working CI/CD implementation on GitHub Actions**:

- 3 real services (Node, Go, Python)
- Full supply chain security (SBOM, signing, verification)
- Real deployments to Kubernetes
- Real rollback process

Every push to `main`:

👉 builds  
👉 scans  
👉 signs  
👉 verifies  
👉 deploys  

---

# 🔍 What This Demo Is (and Is NOT)

This is **NOT**:
> “GitHub Actions can’t do CI/CD”

It clearly can.

---

This **IS**:
> A build vs buy demonstration of what it takes to turn GitHub into a **secure, governed delivery platform**

---

# ⚠️ Critical Observation

> These workflow files MUST exist in every repository

Even with:
- reusable workflows  
- templates  
- composite actions  

You still need:

- workflow entry points  
- triggers  
- permissions  
- service-specific configuration  

👉 This does NOT go away

---

# ✅ What’s Running (REAL Pipelines)

## 🧱 User Service (Node.js)

### CI (`ci-user-service.yml`)
- Build Docker image → GHCR  
- Trivy + Grype scans  
- SBOM generation (Syft)  
- SBOM validation (custom logic)  
- Cosign signing + attestation  
- Conftest policy validation  

⏱ ~5–7 minutes  

---

### CD (`cd-user-service.yml`)
- Resolve tag → digest  
- Verify signed SBOM before deploy  
- Create cluster (Kind)  
- Inject config + secrets  
- Deploy to Kubernetes  
- Wait for rollout  
- Run smoke tests  

⏱ ~3–4 minutes  

---

## 💳 Payment Service (Go)

Same pattern:
- test → build → scan → SBOM → sign → verify → deploy  

⏱ ~8–11 minutes  

---

## 🔔 Notification Service (Python)

Same pattern:
- pytest → build → scan → SBOM → sign → verify → deploy  

⏱ ~8–11 minutes  

---

## 🔁 Manual Rollback

### `rollback-manual.yml`

Process:
1. Manually trigger workflow  
2. Provide commit SHA  
3. Create rollback commit  
4. Re-run CI  
5. Re-run CD  

⏱ **11+ minutes**

---

## ⚡ Compare

| Capability | GitHub (This Demo) | Harness |
|----------|-------------------|--------|
| Deploy | ~11 minutes | Minutes |
| Rollback | 11–30+ minutes | < 60 seconds |
| Governance | Scripted | Built-in |
| Security Enforcement | Workflow logic | Runtime enforced |

---

# 🧠 The “Perfect Architecture” Argument (And Its Gap)

A strong platform engineer will say:

> “You shouldn’t use GitHub for CD.  
> Use GitHub + Argo CD + Terraform (GitOps).”

---

## That is TRUE… but incomplete

That architecture looks like:

- GitHub Actions → CI  
- Argo CD → Kubernetes CD  
- Terraform → Infrastructure  
- Sigstore → Signing  
- OPA → Policy  
- Monitoring → Verification  

---

## ⚠️ Problem 1 — Toolchain Fragmentation

You now operate:

- GitHub  
- Argo CD  
- Terraform  
- Kubernetes  
- Sigstore stack  
- Policy engines  

👉 Multiple control planes  
👉 Multiple failure modes  
👉 Multiple teams  

---

## ⚠️ Problem 2 — Kubernetes-Only CD

Argo CD works great for:

✅ Kubernetes  

---

But most enterprises run:

- EC2 / VMs  
- AWS Lambda  
- ECS / Fargate  
- Azure App Services  
- GCP Cloud Run  
- Databases  
- Legacy systems  

---

## ❗ Critical Gap

> Argo solves Kubernetes CD only

Everything else becomes:

- custom scripts  
- Terraform orchestration  
- more GitHub workflows  

👉 You now have **multiple CD patterns in the same organisation**

---

## ⚠️ Problem 3 — Ownership Explosion

Who owns:

- Argo rollout logic?  
- Terraform orchestration?  
- GitHub workflows?  
- security enforcement?  
- rollback strategy?  

👉 Platform team becomes **integration layer for everything**

---

# 🔥 Where the Toil Actually Comes From (REAL EXAMPLES)

## 1. Secure Artifact Promotion (You Built This Yourself)

This repo implements:

- digest resolution  
- SBOM generation  
- SBOM validation (jq parsing)  
- Cosign signing  
- Cosign verification  
- attestation creation  
- attestation verification  

👉 This is not native  
👉 This is platform code  

---

## 2. Governance Is Distributed

Implemented via:

- Conftest  
- Rego  
- workflow logic  
- scripts  

👉 Every repo depends on correct implementation  
👉 Drift is inevitable  

---

## 3. Deployment Is Scripted

CD pipeline is:

- create cluster  
- configure environment  
- patch manifests  
- deploy  
- test  

👉 This is scripting  
👉 Not a deployment platform  

---

## 4. Rollback Is Not First-Class

Rollback = commit + pipeline

👉 Slow  
👉 Non-deterministic  
👉 Dependent on pipeline health  

---

## 5. Security Is Explicit… but Fragile

Yes, it is visible.

But also:

- depends on workflow discipline  
- can be bypassed  
- can drift  

---

## ⚠️ The Real Risk

> Not hidden security  
> 👉 inconsistent security  

---

# 📈 The Scaling Problem

## Today

- 3 services  
- 6 workflows  

---

## At Scale

- 100 services → 200 workflows  
- 1000 services → thousands  

Each containing:

- security logic  
- deployment logic  
- policy logic  

---

## Even With Reuse

You still manage:

- versions  
- adoption  
- drift  
- exceptions  

---

# 🧾 What the Platform Team Owns

To make this work:

- workflow design  
- security integration  
- SBOM enforcement  
- signing + verification  
- deployment scripting  
- rollback processes  
- cross-tool debugging  

---

## Important Reframe

This is not bad engineering.

👉 This is **expected platform engineering**

---

## The Real Question

> “Is this where you want your platform team spending time?”

---

# 🆚 Build vs Buy

## Build (GitHub + Argo + Terraform)

You get:

- flexibility  
- control  
- transparency  

You take on:

- integration complexity  
- multiple CD systems (K8s vs everything else)  
- operational overhead  
- long-term ownership  

---

## Buy (Harness)

You get:

- unified CD across:
  - Kubernetes  
  - VMs  
  - ECS / Lambda  
  - traditional workloads  
- built-in rollback  
- centralized governance  
- runtime policy enforcement  
- consistent deployment model  

---

## The Trade-Off

| Option | Trade-Off |
|------|----------|
| Build | Control + Complexity |
| Buy | Abstraction + Consistency |

---

# 💥 The Key Insight

> GitHub + Argo gives you components  
> Harness gives you a **unified delivery platform**

---

# 🎯 Bottom Line

This demo proves:

✅ You can build enterprise CI/CD  
❌ You must assemble and operate it yourself  

---

> The more environments, services, and compliance you have  
> 👉 the more you are building your own platform  

---

# 🧠 Final Thought

> You absolutely *can* build this.

The real question is:

> **Do you want to own multiple CD systems and glue them together forever?**
