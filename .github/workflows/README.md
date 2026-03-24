# Real CI/CD Demo on GitHub Actions
## Three services. Real workflows. Real toil.

This repository demonstrates a **working CI/CD implementation on GitHub Actions** for three services:

- User Service (Node.js)
- Payment Service (Go)
- Notification Service (Python)

These pipelines are not mock examples. They run on **every push to `main`** and perform real build, security, signing, verification, deployment, and smoke testing steps.

---

# What this demo is really showing

This demo proves two things at the same time:

1. **GitHub Actions can be made to deliver real CI/CD**
2. **To make GitHub Actions behave like an enterprise delivery platform, you end up building and maintaining a lot of platform logic yourself**

That second point is the real purpose of this repo.

This is not a “GitHub Actions does nothing” argument.  
It is a **build vs buy** argument.

GitHub Actions gives you a flexible workflow engine.

But once you need:

- vulnerability scanning
- SBOM generation
- SBOM validation
- image signing
- attestation verification
- policy-as-code checks
- environment promotion
- manual approvals
- deployment orchestration
- rollback controls

…your platform team becomes responsible for stitching those capabilities together across YAML, shell scripts, third-party actions, CLIs, and repository-by-repository workflow wiring.

That is the operational tax this demo is designed to expose.

---

# Why this becomes platform-team toil

In this repo, the workflows do all of the following:

## CI responsibilities
- test the application
- build container images
- push to GitHub Container Registry
- run Trivy and Grype scans
- generate an SBOM with Syft
- validate SBOM content with custom `jq` logic
- check for banned packages
- check for license compliance
- sign images with Cosign
- attach signed SBOM attestations
- verify signatures and attestations
- validate Dockerfile and Kubernetes policy with Conftest / OPA

## CD responsibilities
- chain deployment from CI using `workflow_run`
- create Kubernetes clusters with Kind
- create namespaces
- resolve image tag to immutable digest
- verify SBOM attestations before deployment
- create environment-specific ConfigMaps and Secrets
- mutate manifests with the correct image reference
- deploy to Kubernetes
- wait for rollout
- run smoke tests
- gather logs on failure

This works.

But it also means the platform team owns:
- the tooling integration
- the glue code
- the policy code
- the rollout logic
- the debugging
- the lifecycle of all of it

At small scale, this is manageable.

At enterprise scale, this becomes a significant FTE burden.

---

# The core GitHub Actions limitations this demo highlights

## 1. GitHub Actions is a workflow engine, not a native delivery platform
To securely promote an artifact, the workflows must:
- build and push the image
- capture the digest
- pass that information between workflows
- rediscover the artifact later
- resolve tag to digest
- verify Cosign attestations
- decode and inspect signed payloads
- enforce deployment gates in shell logic

That is a lot of custom engineering to answer:
**“Is this the exact signed artifact we approved for deployment?”**

## 2. Governance is assembled, not centrally enforced
Policy enforcement here is implemented through:
- Conftest
- Rego policies
- bash scripts
- `jq` parsing
- workflow conditions
- environment settings

That means governance is spread across workflow files and scripts rather than expressed once in a central runtime policy model.

## 3. Secure software supply chain requires specialist code
SBOM generation is easy.

SBOM enforcement is not.

This repo shows the difference clearly:
- generate SBOM
- upload artifact
- download artifact
- parse package lists
- inspect licenses
- inspect banned packages
- attach signed attestation
- verify attestation in deployment

That is all real work the platform team must build and maintain.

## 4. Deployment orchestration is procedural
Deployments here are implemented as scripts:
- create cluster
- create namespace
- inject config
- patch manifests
- deploy
- wait
- port-forward
- curl endpoints
- handle failures manually

That is functional, but not the same as having a deployment platform with first-class rollout, verification, promotion, and rollback primitives.

## 5. Rollback is not first-class
Rollback in GitHub Actions is typically another workflow and another process.

In this demo, rollback is manual and slow:
- trigger workflow manually
- specify prior commit
- create rollback commit
- wait for CI to rerun
- wait for CD to rerun

This is very different from a platform with native rollback based on deployment history.

## 6. Reusable workflows reduce duplication but do not remove repo sprawl
Even with reusable workflows, every repo still needs:
- workflow files
- triggers
- permissions
- inputs
- path filters
- service-specific logic
- version coordination

You still have distributed pipeline surface area to manage.

---

# Build vs Buy: the real decision

## Build on GitHub Actions when:
- you want a programmable automation engine
- you have a strong platform team
- you are comfortable building and maintaining delivery controls yourself
- you accept repository-level workflow sprawl
- you are willing to own the operational complexity long term

## Buy Harness when:
- you want CI/CD capabilities as platform features instead of custom YAML and scripts
- you want built-in deployment orchestration
- you want native rollback
- you want stronger runtime governance
- you want policy enforcement without embedding it everywhere
- you want to reduce platform-team toil and FTE drag
- you want to move from “workflow automation” to “software delivery platform”

## The practical business case
The issue is not whether GitHub Actions can work.

It can.

The issue is how much **platform engineering effort** is required to make it behave like a secure, governed, enterprise-grade delivery platform.

That effort grows with every:
- new service
- new environment
- new compliance rule
- new security gate
- new deployment pattern
- new exception
- new rollback requirement

That is the build-vs-buy threshold.

---

# What is in this repo

## Real workflows that actually run

### User Service (Node.js)

#### `ci-user-service.yml`
Runs on push to `main`

Performs:
- Node.js test execution
- Docker build and push to GHCR
- vulnerability scanning with Trivy and Grype
- SBOM generation with Syft
- SBOM validation with custom logic
- image signing with Cosign
- policy validation with Conftest

Typical runtime:
- ~5–7 minutes

#### `cd-user-service.yml`
Runs after CI succeeds

Performs:
- Kind cluster creation
- image digest resolution
- SBOM attestation verification
- environment config and secret creation
- Kubernetes deployment
- rollout verification
- smoke tests

Typical runtime:
- ~3–4 minutes

---

### Payment Service (Go)

#### `ci-payment-service.yml`
Runs on push to `main`

Performs:
- Go test execution
- Docker build and push to GHCR
- vulnerability scanning
- SBOM generation
- signing
- policy validation

Typical runtime:
- ~5–7 minutes

#### `cd-payment-service.yml`
Runs after CI succeeds

Performs:
- Kind cluster creation
- deployment
- smoke tests

Typical runtime:
- ~3–4 minutes

---

### Notification Service (Python)

#### `ci-notification-service.yml`
Runs on push to `main`

Performs:
- pytest execution
- Docker build and push to GHCR
- vulnerability scanning
- SBOM generation
- signing
- policy validation

Typical runtime:
- ~5–7 minutes

#### `cd-notification-service.yml`
Runs after CI succeeds

Performs:
- Kind cluster creation
- deployment
- smoke tests

Typical runtime:
- ~3–4 minutes

---

### Manual Rollback

#### `rollback-manual.yml`
Manual trigger only

Demonstrates the rollback process in GitHub Actions:
- identify previous commit
- trigger rollback workflow
- create rollback commit
- rerun CI
- rerun CD

Typical runtime:
- 11+ minutes total

### Compare to Harness
With Harness, rollback is a native deployment action and is typically measured in seconds, not a full workflow rebuild cycle.

---

# What makes this demo useful

This repo is intentionally designed to show the difference between:

## “Can GitHub Actions do it?”
Yes.

## “What does it cost operationally to own it?”
That is the real question.

This demo shows the hidden cost in:
- YAML complexity
- shell scripting
- security tooling integration
- policy distribution
- deployment orchestration
- rollback design
- repo-by-repo maintenance

---

# What is real vs what is reference

| Location | Status | Purpose |
|----------|--------|---------|
| `/.github/workflows/` | ✅ Real | Actual workflows that run on push and deployment events |
| `/platform/.github/workflows/` | 📚 Reference | Reusable workflow examples and patterns for scaling |

The workflows under `/.github/workflows/` prove this implementation works.

The `/platform/` content shows what a platform team would need to standardize and maintain at scale.

---

# Check the workflows running

Go to the Actions tab for this repository:

`https://github.com/gregkroon/githubexample/actions`

You should see workflows such as:
- CI - User Service
- CD - User Service
- CI - Payment Service
- CD - Payment Service
- CI - Notification Service
- CD - Notification Service
- Manual Rollback

This is the important scaling point:

**3 services = 6 active workflows**

At scale:

**1000 services = thousands of workflow definitions, triggers, policy integrations, and deployment variants to manage**

Even with reuse, the platform team still owns the rollout and support burden.

---

# Try it yourself

## 1. Fork the repo
Fork this repository to your own GitHub account.

## 2. Make a change
Example:

```bash
echo "console.log('Test deployment');" >> services/user-service/src/index.js

git add .
git commit -m "Test real CI/CD"
git push origin main











