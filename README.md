# GitHub Actions CD: Hands-On Discovery

This repo is a working GitHub Actions CI/CD stack built to the standards you'd actually implement in production — supply chain security, OPA policy enforcement, SBOM attestation, multi-environment promotion, manual rollback. It runs. Fork it, push a change, watch it go.

The point is not to show GitHub Actions failing. It's to show what "done right" looks like — and let you observe what's still missing from first principles.

---

## Who This Is For

Platform engineers, DevOps practitioners, and SREs evaluating whether GitHub Actions is the right long-term CD platform for their environment. No slides. No vendor claims. Just code you can run and examine.

---

## Repo Structure

```
.github/workflows/
  ci-user-service.yml          # Build → test → SBOM → scan → sign → push
  ci-payment-service.yml
  ci-notification-service.yml
  cd-user-service.yml          # Deploy dev → approval gate → deploy prod → smoke tests
  cd-payment-service.yml
  cd-notification-service.yml
  rollback-manual.yml          # Manual rollback via workflow_dispatch

services/
  user-service/                # Node.js Express app (the demo target)
  payment-service/
  notification-service/

platform/
  .github/actions/
    scan-and-sign/             # Reusable: Trivy + Grype + Cosign
    validate-policies/         # Reusable: OPA/Rego policy evaluation
  policies/
    docker/dockerfile.rego     # 15 Dockerfile security rules
    kubernetes/security.rego   # 18 Pod Security Standards rules
    sbom/vulnerabilities.rego  # SBOM vulnerability + license checks
  rulesets/README.md           # What GitHub Rulesets can (and can't) enforce

gitops/apps/prod/user-service/
  rollout.yaml                 # Argo Rollouts progressive delivery config

governance/metrics-collector/
  dora-metrics-design.md       # DORA metrics design (note: it's a design doc, not running code)
```

---

## Setup (5 minutes)

**1. Fork this repo** to your own GitHub account.

**2. Create environments** — Settings → Environments → New environment:
- `dev`
- `production`

**3. Add a required reviewer to production** — click into the `production` environment → Required reviewers → add yourself. This creates the manual approval gate.

**4. Trigger the pipeline** by pushing a change:

```bash
echo "// $(date)" >> services/user-service/src/index.js
git add services/user-service/src/index.js
git commit -m "Trigger CI/CD demo"
git push origin main
```

Watch Actions → you'll see CI run, then CD pick it up via `workflow_run`. Production will pause for your approval.

---

## Tracing the Gaps

For each gap below: here's where to look in the code, here's what you'll observe, here's what you'd need to build to close it.

---

### Gap 1: There Is No Deployment State

**Where to look:** After `cd-user-service.yml` completes successfully, ask this question:

> "What version of user-service is running in production right now?"

There is no API to call. There is no dashboard. The runner that deployed it is gone.

**What actually exists:**
- GitHub's environment page shows the last workflow run that targeted `production`
- That run's SHA is visible — if you can navigate to the right environment page

**What's missing for real operations:**
- No queryable "what's deployed where" across all services
- No unified view spanning K8s, Lambda, ECS, and VMs
- Answering the question at 2am requires: find the right environment page → trace the SHA → cross-reference ArgoCD for K8s state → manually check Lambda versions for serverless → `kubectl get pods` for anything else

**What you'd need to build:** A custom deployment state service that captures artifact version + environment + timestamp on every CD run, exposes a query API, and stays in sync when deployments happen outside the workflow (hotfixes, manual kubectl applies, Terraform runs).

---

### Gap 2: Verification Ends When the Container Starts

**Where to look:** [`cd-user-service.yml` lines 214–245](./cd-user-service.yml#L214)

```yaml
- name: Run smoke tests
  run: |
    kubectl port-forward -n user-service-dev svc/user-service 3000:3000 &
    sleep 5
    curl -f http://localhost:3000/health || exit 1
    curl -f http://localhost:3000/api/users || exit 1
```

**What this proves:** The container started and the health endpoint responded. That's it.

**What it doesn't prove:**
- Error rate vs pre-deployment baseline
- p99 latency is acceptable
- Database connection pool is healthy under load
- Downstream services haven't degraded
- The canary population behaves the same as the stable population

**What a real production incident looks like:** Deployment passes smoke tests. Error rate climbs 2% over the next 8 minutes. On-call engineer gets paged. They look at Datadog, trace it to this deployment, manually trigger the rollback workflow (see Gap 4). Elapsed time: 20–35 minutes of user impact.

**What you'd need to build per service:** Custom bash scripts that call your observability API (Datadog, New Relic, Dynatrace), capture pre-deployment metric baselines, poll post-deployment metrics for a configurable window, compare against threshold with statistical noise filtering, and trigger rollback on breach. Per service. Maintained by your team.

---

### Gap 3: Governance Is Pre-Merge Only

**Where to look:** [`platform/policies/`](./platform/policies/) and [`platform/rulesets/README.md`](./platform/rulesets/README.md)

The OPA policies here are real. The Dockerfile rules, K8s Pod Security rules, and SBOM checks are well-written and would catch violations in CI.

**The boundary these policies operate at:** They run inside a workflow step. They enforce what they enforce when the workflow runs.

**The bypass surface — all documented by GitHub:**

1. **`workflow_dispatch`** — any user with write access can trigger a deployment workflow manually, skipping any upstream gates
2. **Admin bypass** — repository admins can force-push to main and bypass required status checks
3. **`GITHUB_TOKEN` self-approval** — a workflow can approve its own deployment to a protected environment using the built-in token; GitHub accepted and paid out a bug bounty on this mechanism
4. **Direct `kubectl apply`** — nothing in GitHub Actions stops a developer with cluster credentials from deploying directly, leaving no workflow audit trail
5. **Workflow file changes** — a PR can modify the workflow file itself; the policy applies to the version running, not the version being merged

**What you'd need to build:** A post-merge governance layer that enforces policies at deployment execution time independent of how the deployment was triggered. This is the difference between pre-merge checks (GitHub does this well) and deployment-time enforcement (requires an external execution engine with its own RBAC).

---

### Gap 4: Rollback Takes 11+ Minutes and Requires the SHA

**Where to look:** [`rollback-manual.yml`](./.github/workflows/rollback-manual.yml)

```yaml
on:
  workflow_dispatch:
    inputs:
      target_sha:
        description: 'Git SHA to rollback to (previous good commit)'
        required: true
```

**The rollback process:**
1. You know something is wrong
2. You find the last known-good commit SHA from git log
3. You go to Actions → Run workflow → paste the SHA
4. The workflow creates a revert commit and pushes it
5. CI triggers (~7 min) → CD triggers (~4 min) → approval gate → production deploy

**Total time from "something is wrong" to "rollback complete": 11–15 minutes**, assuming you approve prod immediately and nothing in CI fails.

**What this workflow cannot roll back:**
- Lambda function versions
- ECS task definitions
- Infrastructure changes made by Terraform in the same pipeline
- Database schema migrations (there's no rollback for those here at all)

**What's visible in the workflow comments (line 98):**
```
echo "**Total rollback time: ~11+ minutes**"
```

The workflow documents its own limitation.

---

### Gap 5: Supply Chain Security Code Scales Linearly With Services

**Where to look:** [`cd-user-service.yml` lines 70–168](./cd-user-service.yml#L70) — the SBOM attestation verification block.

That block is **~100 lines of bash** handling: image tag → digest resolution (because tags are mutable), Cosign installation, attestation verification with certificate identity matching, base64 payload extraction, SBOM package count validation, and error handling for verification failures.

This code is **duplicated in full** in the prod deploy job (lines 328–434). It will be duplicated again for payment-service and notification-service.

**The workflow even counts it for you (line 424):**
```
echo "- CI: 50 lines (capture digest + sign + attach attestation)"
echo "- CD Dev: 50 lines (resolve digest + verify attestation)"
echo "- CD Prod: 50 lines (resolve digest + verify attestation)"
echo "- Total: 150 lines just for attestation"
```

The composite action in `platform/.github/actions/scan-and-sign/` partially addresses this. Read [`platform/.github/actions/README.md`](./platform/.github/actions/README.md) for an honest assessment of what composite actions can and can't solve — particularly around versioning, secrets access, and centralized policy updates.

---

## What's Intentionally Absent

These capabilities have no implementation in this repo. They aren't hidden somewhere. They don't exist.

| Capability | What it would take to build |
|---|---|
| **Deployment freeze windows** | A service that blocks workflow execution based on a calendar, with org-wide scope and RBAC. GitHub environment protection rules are per-environment only, with no calendar primitive. Build cost: AUD 6,758. Annual maintenance: AUD 9,268/yr. |
| **DORA metrics** | A data pipeline collecting deployment frequency, lead time, change failure rate, and MTTR from workflow events, cross-referenced with incident data. GitHub is not a deployment system of record — your team defines what counts as a deployment, a failure, and a rollback, then maintains that model indefinitely. The `governance/metrics-collector/dora-metrics-design.md` file in this repo is a design document — not running code. Build cost: AUD 30,412. Annual maintenance: AUD 18,537/yr. |
| **Database deployments** | Flyway or Liquibase wired into the pipeline with migration state tracking, approval gates for schema changes, and a rollback strategy for failed migrations. The database change and the application deployment are governed separately — different approvals, different audit records, no coordinated rollback. Nothing in this repo. Build cost: AUD 121,652. Annual maintenance: AUD 34,758/yr. |
| **Progressive delivery for non-K8s targets** | The `gitops/apps/prod/user-service/rollout.yaml` defines an Argo Rollout for K8s. Canary/blue-green for Lambda, ECS, Azure Web Apps, and GCP Cloud Run requires a separate tool per platform — CodeDeploy, Lambda aliases, slot swaps — each with its own configuration model, upgrade cycle, and failure behaviour. Build cost: AUD 182,479. Annual maintenance: AUD 46,344/yr. |
| **Deployment domain model** | Services, environments, and infrastructure definitions as reusable platform entities. What GitHub provides: environment labels with shared protection rules. The mapping between a service, its infrastructure, and its deployment configuration lives in each repo's YAML. When infrastructure changes, every pipeline file that references the old values needs updating across every service. Build cost: AUD 30,412. Annual maintenance: AUD 18,537/yr. |
| **Unified deployment audit trail** | A correlation layer that links the GitHub workflow run to the Vault access log, Terraform state, database migration history, Argo Rollouts events, and Snyk scan results into one auditable deployment record. Every tool added to the delivery estate adds another silo. Build cost: AUD 30,412. Annual maintenance: AUD 23,172/yr. |
| **Platform as code onboarding** | The GitHub Terraform provider provisions repositories, teams, branch protection, environments, and rulesets. The delivery platform itself — Argo Rollouts, HashiCorp Vault, Datadog, OPA — each requires its own Terraform provider, its own state file, and its own ownership. Onboarding a new service means coordinating across all of them. Build cost: not modelled separately (covered in upstream capabilities). |

---

## The Build Question

Everything working in this repo — the OPA policies, the SBOM attestation, the multi-environment promotion, the smoke tests — was built and is owned by your platform team.

Everything absent from this repo also has to be built and owned by your platform team.

For the business case on what that build costs and how it compares to a purpose-built CD platform, see the [Build vs Buy comparison](./Harness%20CD%20vs%20GitHub%20Actions%20CD%20%20Build%20vs%20Buy%20V2.xlsx).
