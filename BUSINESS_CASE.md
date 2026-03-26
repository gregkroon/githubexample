# GitHub Actions vs Harness CD: Build vs Buy

A decision-maker's guide to evaluating the true cost of scaling GitHub Actions for enterprise Continuous Delivery.

For the hands-on technical evidence behind these claims, see the [README](./README.md).

---

## The Verdict

GitHub Actions is the industry standard for Continuous Integration. Extending it into enterprise CD works — but the operational cost of that extension is what this analysis is about.

| Capability | GitHub Actions CD Stack | Harness CD |
|---|---|---|
| **Architecture** | GHA + Terraform + ArgoCD + Bash + custom services | Single purpose-built control plane |
| **Platform team focus** | 6 engineers at 60%+ maintaining integration glue | 2 engineers at 10% on config, 90% on features |
| **Deployment state** | None — stateless ephemeral runners, no system of record | Persistent, queryable, auditable across all targets |
| **Post-deploy verification** | Custom bash scripts polling observability APIs | ML-driven anomaly detection with automatic rollback |
| **Rollback** | Manual workflow_dispatch, requires SHA, 11+ minutes | One-click, platform-aware, under 60 seconds |
| **Governance enforcement** | Pre-merge checks; post-merge deployment execution is bypassable | OPA at deployment execution time, independent of trigger method |
| **ITSM integration** | Requires custom GitHub App + REST API maintenance | Native ServiceNow/Jira bidirectional integration |
| **Deployment freezes** | Per-environment protection rules only, no calendar primitive | Calendar-based org-wide freeze with RBAC scoping |
| **Database deployments** | Not native; requires Flyway/Liquibase integration | First-class governed pipeline step |
| **DORA metrics** | Not native; requires multi-month data engineering project | Native dashboard — Deployment Frequency, Lead Time, CFR, MTTR |
| **Artifact promotion** | Re-tagging by convention | Immutable artifacts registered at build, promoted as platform action |
| **Progressive delivery** | K8s via Argo Rollouts; Lambda/ECS/VMs require separate custom implementations | Native canary/blue-green across K8s, ECS, Lambda, and VMs |
| **Secrets management** | GitHub OIDC (strong for cloud auth); no native enterprise vault integration | Native HashiCorp Vault, AWS Secrets Manager, Azure Key Vault integration |

---

## The 15-Capability Gap Analysis

The XLS accompanying this repository (`Harness CD vs GitHub Actions Build vs Buy V1.xlsx`) provides a detailed breakdown of 15 capability areas, each with:
- What Harness provides natively
- What GitHub Actions provides natively (and what must be built)
- Business impact with engineering effort estimates
- Evidence from GitHub's own documentation

Key findings from that analysis:

### Capabilities Where GitHub Has No Native Solution

- **Change Management** — No native ServiceNow or Jira integration. GitHub's docs confirm ITSM requires a third-party App "at its discretion."
- **Rollback** — No rollback primitive documented in GitHub Actions CD docs.
- **AI/ML Verification** — Verification in GitHub docs means pre-deploy test execution only. No post-deploy ML baseline comparison documented.
- **Database Deployments** — Not mentioned in GitHub Actions CD documentation.
- **DORA Metrics** — GitHub's Q1 2026 public roadmap contains zero DORA capabilities.
- **Artifact Promotion** — CD documentation describes workflow-triggered deployments only; no promotion model.
- **Progressive Delivery** — No progressive delivery primitives in GitHub. Argo Rollouts addresses K8s only.
- **Release Orchestration** — No cross-system release calendar or orchestration module.

### Capabilities Where GitHub Has Partial Coverage

- **Deployment Freezes** — Per-environment protection rules exist, but no org-wide calendar freeze.
- **Post-Merge Governance** — Workflow file restrictions exist pre-merge; post-merge deployment execution has documented bypass mechanisms.
- **Templates/Pipeline Standardisation** — Repository Rulesets (Enterprise Cloud) enforce which workflows run; they don't govern workflow contents.
- **Secrets Management** — OIDC federation is strong for cloud credentials; no native enterprise vault integration.
- **Supply Chain Security** — GitHub Artifact Attestations cover the build-time half; the deployment-time verification gate requires custom implementation.

---

## The Governance Gap: A Specific Note

The post-merge governance gap is worth calling out because it's often misunderstood.

The common assumption: "We require PR review on the workflow file, so the governance is enforced."

**The bypass mechanisms that exist even with that protection:**

1. `workflow_dispatch` — write-access users can trigger deployment workflows manually, bypassing upstream gates
2. Admin repository access bypasses required status checks
3. `GITHUB_TOKEN` self-approval — GitHub accepted and paid a bug bounty on this mechanism; a workflow can approve its own environment deployment
4. Direct infrastructure access (kubectl, AWS CLI) creates deployments with no workflow audit trail
5. Workflow file modifications take effect at merge; the policy runs on the version executing, not the version under review

Harness evaluates OPA policies at deployment execution time, independent of how the deployment was triggered.

---

## The Build Cost: Engineering Months by Capability

Based on the detailed estimates in the XLS:

| Capability | Estimated Build Time |
|---|---|
| Change management integration (ServiceNow/Jira) | 6–12 months |
| Deployment freeze (org-wide, tamper-proof) | 2–4 months |
| Progressive delivery (K8s + ECS + Lambda) | 12–18 months |
| AI/ML post-deploy verification | 6–12 months |
| Database deployments (governed, multi-platform) | 3–6 months |
| DORA metrics dashboard | 3–6 months |
| Artifact promotion model | 1–3 months |
| Rollback (all target types) | 3–6 months |

These are build costs. They don't include ongoing maintenance as AWS deprecates runtimes, Helm updates, Terraform provider changes, and ITSM API updates break integrations.

---

## When GitHub Actions CD Is the Right Choice

- Fewer than 50 microservices
- Infrastructure is primarily or entirely Kubernetes (ArgoCD handles this well)
- No ITSM/change management requirements
- No cross-platform progressive delivery requirements (Lambda, ECS, VMs)
- Platform team has bandwidth to build and own deployment tooling indefinitely

---

## When the Build Cost Exceeds the Buy Cost

- 100+ services across heterogeneous infrastructure (K8s, VMs, Serverless, databases)
- ITSM/change management gate required by compliance or process
- Post-deploy verification and automatic rollback required (not "deploy and pray")
- DORA metrics required for engineering leadership reporting
- Platform team should be building developer productivity features, not maintaining deployment glue

---

## The Strategic Question

Your most expensive platform engineers are finite. The question is what you want them spending that time on:

- **GitHub Actions CD**: Building and maintaining the integration layer (state tracking, verification scripts, rollback logic, ITSM integration, DORA data pipelines, deployment freeze logic)
- **Harness CD**: Configuring a platform that ships those capabilities, and using freed capacity to build internal developer portals, golden paths, and productivity tooling

The code in this repository is the integration layer. Read it, run it, and decide whether owning that indefinitely is the right use of your platform team.
