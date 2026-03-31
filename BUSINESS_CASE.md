# GitHub Actions vs Harness CD: Build vs Buy

A decision-maker's guide to evaluating the true cost of scaling GitHub Actions for enterprise Continuous Delivery.

For the hands-on technical evidence behind these claims, see the [README](./README.md).

---

## The Verdict

GitHub Actions is the industry standard for Continuous Integration. Extending it into enterprise CD works — but the operational cost of that extension is what this analysis is about.

| Capability | GitHub Actions CD Stack | Harness CD |
|---|---|---|
| **Architecture** | GHA + Terraform + ArgoCD + Bash + custom services | Single purpose-built control plane |
| **Platform team focus** | 1.4 FTE/yr maintaining integration glue | 0.3 FTE/yr on config and onboarding |
| **Progressive delivery** | Argo Rollouts (K8s only); CodeDeploy, Lambda aliases, slot swaps per platform — no unified model | Native canary/blue-green across K8s, ECS, Lambda, Azure, and GCP |
| **Post-merge governance** | Pre-merge checks; post-merge deployment execution is bypassable | OPA evaluated at deployment execution time, independent of trigger method |
| **Database deployments** | Flyway/Liquibase run separately — different approvals, different audit trail, no coordinated rollback | First-class governed pipeline step alongside application deployment |
| **Release orchestration** | Coordination via Slack, Jira, ServiceNow; no single auditable release record | Complex releases exist as one platform record with automatic audit trail |
| **Post-deploy verification** | Custom bash scripts polling observability APIs; thresholds defined and maintained per service | ML-driven learned-baseline anomaly detection with automatic rollback |
| **Rollback** | Manual workflow_dispatch, requires SHA, 11+ minutes; no rollback for Lambda/ECS/DB | One-click, platform-aware rollback for every supported target |
| **Deployment access control** | Environment protection rules per-environment; auto-created environments have no rules | Centralised RBAC/ABAC — deploy, approve, and connector permissions scoped at platform level |
| **DORA metrics** | Requires custom data engineering to define and maintain a defensible deployment model | Native dashboard calculated from pipeline outcomes — Deployment Frequency, Lead Time, CFR, MTTR |
| **Deployment domain model** | Deployment logic in each service's YAML; infrastructure changes require updates across every pipeline file | Service, Environment, and Infrastructure Definition as platform objects — one update propagates everywhere |
| **Templates & standardisation** | Reusable workflows; teams control the `uses:` reference and can substitute or remove it post-merge | Locked templates with centrally-controlled rollout; consuming teams cannot remove governance steps |
| **Secrets management** | Separate Marketplace Action per vault provider; each with its own auth setup and maintenance | Native connectors to HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, GCP — configured once |
| **Deployment freezes** | Script loops across every environment before each blackout window; auto-created environments missed | Calendar-based org-wide freeze — one rule, no gaps, no recurring manual operation |
| **Unified audit trail** | Each tool (Terraform, Argo, Vault, Flyway, Snyk, ServiceNow) produces a separate audit record | Every deployment step is a child of one platform execution record — no cross-system reconstruction |
| **Platform as code** | GitHub Terraform provider covers repos and access; each additional tool (Argo, Vault, Datadog) requires its own provider and state | Single Harness Terraform provider provisions the complete delivery platform — services, environments, pipelines, RBAC, OPA, freeze windows |

---

## The 13-Capability Gap Analysis

The XLS accompanying this repository (`Harness CD vs GitHub Actions CD  Build vs Buy V2.xlsx`) provides a detailed breakdown of 13 capability areas, each with:
- What Harness provides natively
- What GitHub Actions provides natively (and what must be built)
- The operational cost your team absorbs for each capability
- Evidence from GitHub's own documentation

Key findings from that analysis:

### Capabilities Where GitHub Has No Native Solution

- **Rollback** — No unified rollback primitive. Community discussion confirms this is an unresolved gap with no native platform answer.
- **AI/ML Verification** — Verification in GitHub is threshold-based per service. No post-deploy learned-baseline comparison; thresholds go stale as services change.
- **Database Deployments** — Flyway and Liquibase run inside GitHub Actions but are governed separately from application deployments. No coordinated rollback.
- **DORA Metrics** — GitHub is not a deployment system of record. Metrics require custom data engineering to define, produce, and defend.
- **Heterogeneous Release Orchestration** — No release as a first-class platform record. Coordination lives in Slack, Jira, and pipeline logs.
- **Progressive Delivery** — Argo Rollouts addresses K8s. ECS, Lambda, Azure, and GCP each require a separate tool with separate configuration and operational ownership.
- **Unified Deployment Audit Trail** — Each tool in the delivery estate (Terraform, Argo, Vault, Flyway, Snyk, ServiceNow) produces a separate audit record. No native linkage.
- **Platform as Code Onboarding** — The GitHub Terraform provider covers repos and access. The rest of the delivery estate (Argo, Vault, Datadog, OPA) requires a separate provider per tool with no shared state.

### Capabilities Where GitHub Has Partial Coverage

- **Post-Merge Deployment Governance** — Environment protection rules are real but per-environment only. Auto-created environments have no rules applied. Post-merge deployment execution is bypassable.
- **Deployment Access Control** — Environment protection rules work for configured environments. Auto-created environments have no protection; no ABAC equivalent to apply SoD rules automatically to new environments by attribute.
- **Templates & Pipeline Standardisation** — Reusable workflows distribute standards; the `uses:` reference is a YAML line the team controls and can substitute post-merge.
- **Secrets Management** — OIDC federation is strong for cloud credentials. Each enterprise vault provider requires a separate Marketplace Action with its own auth setup and maintenance.
- **Deployment Freezes** — Per-environment locking is scriptable but requires a manual looping operation before each blackout window. Auto-created environments are missed.

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

## The Build Cost: AUD Estimates by Capability

Based on the detailed estimates in the V2 XLS (AUD 231,720/yr fully-loaded platform engineer, 30% reuse discount applied):

| Capability | What is built | Build cost (AUD) | Annual maintenance | 3-year total (AUD) |
|---|---|---|---|---|
| Progressive Delivery | Argo Rollouts, CodeDeploy, Lambda alias scripts, Azure slot swap | 182,479 | 46,344/yr | 321,511 |
| Post-Merge Deployment Governance | OPA policy library, per-team pipeline wiring, coverage audit tooling | 121,652 | 46,344/yr | 260,684 |
| Database Deployments | Flyway/Liquibase per DB engine, rollback scripts, approval gate wiring | 121,652 | 34,758/yr | 225,926 |
| Heterogeneous Release Orchestration | Cross-repo orchestration, release calendar integration, status dashboard | 121,652 | 27,806/yr | 205,070 |
| AI-Driven Continuous Verification | APM API integration per target, threshold config per service, conditional rollback | 54,068 | 27,806/yr | 137,486 |
| Rollback Depth & Speed | Rollback scripts per target, trigger logic, health signal integration | 54,068 | 23,172/yr | 123,584 |
| Deployment Access Control (RBAC/ABAC) | Per-environment protection rules, approval routing, OIDC role mappings, SoD enforcement | 30,412 | 23,172/yr | 99,928 |
| Unified Deployment Audit Trail | Cross-system audit correlation, pipeline-to-vault linkage, DB migration linkage, SIEM integration | 30,412 | 23,172/yr | 99,928 |
| DORA Metrics & BI Dashboarding | Deployment event instrumentation, incident signals, data pipeline to analytics | 30,412 | 18,537/yr | 86,023 |
| Deployment Domain Model | Service-to-infra conventions, YAML mass-update tooling, drift detection | 30,412 | 18,537/yr | 86,023 |
| Templates & Pipeline Standardisation | Reusable workflow library, per-team adoption tracking, post-merge drift scanning | 30,412 | 18,537/yr | 86,023 |
| Secrets Management | Vault connectors (HashiCorp/AWS/Azure/GCP), log sanitisation, cross-pipeline audit trail | 13,517 | 18,537/yr | 69,128 |
| Deployment Freezes | GitHub API scripts for env rule updates, calendar integration, bypass detection | 6,758 | 9,268/yr | 34,562 |
| **TOTAL — 13 capabilities** | | **AUD 827,906** | **AUD 335,990/yr** | **AUD 1,835,876** |

Maintenance = 1.4 FTE/yr. Same 1–2 person platform team across all capabilities — not separate headcount per row.

These are build costs. They don't include opportunity cost (1.4 FTE not building product), additional tooling licences (Argo Rollouts, Datadog, OPA), or Actions minutes and runner infrastructure.

---

## TCO Comparison: Harness vs GitHub Full Build

Harness pricing: USD 720/developer/yr = AUD 1,138/developer/yr (at 1.58 exchange rate). Implementation: AUD 57,930 one-time. Admin: AUD 69,516/yr (0.3 FTE — not zero).

| Team size | Harness 3-year total | GitHub full build (3yr) | Saving |
|---|---|---|---|
| 50 developers | AUD 437,118 | AUD 1,835,876 | AUD 1,398,758 — Harness cheaper |
| 100 developers | AUD 607,758 | AUD 1,835,876 | AUD 1,228,118 — Harness cheaper |
| 150 developers | AUD 778,398 | AUD 1,835,876 | AUD 1,057,478 — Harness cheaper |
| 200 developers | AUD 949,038 | AUD 1,835,876 | AUD 886,838 — Harness cheaper |
| 300 developers | AUD 1,290,318 | AUD 1,835,876 | AUD 545,558 — Harness cheaper |
| 500 developers | AUD 1,972,878 | AUD 1,835,876 | (AUD 137,002) — GitHub cheaper on cash |
| 750 developers | AUD 2,826,078 | AUD 1,835,876 | (AUD 990,202) — GitHub cheaper on cash |

**Cash break-even: ~460 developers. Including opportunity cost: ~755 developers.**

---

## Scenario B: Partial Build

Most teams build the highest-visibility capabilities first and skip the rest. If a team builds the top 5 capabilities (AUD 601,503 build + AUD 1,150,677 three-year total) and skips the remaining 8, the unbuilt capabilities carry residual risk:

| Skipped capability | Failure mode | Illustrative risk range (AUD) |
|---|---|---|
| Rollback Depth & Speed | Manual recovery during incidents — no automated rollback | 15k – 150k |
| Deployment Access Control | Developer self-approves production deployment — SoD audit finding | 30k – 400k |
| Unified Deployment Audit Trail | Cannot produce complete deployment audit record — regulatory finding | 50k – 600k |
| DORA Metrics | No defensible deployment performance data for leadership | 10k – 100k |
| Deployment Domain Model | Infrastructure change breaks hundreds of pipeline files | 15k – 150k |
| Templates & Pipeline Std. | Governance drift found at audit — pipelines missing required gates | 30k – 300k |
| Secrets Management | Supply chain compromise — cannot scope credential exposure | 80k – 800k |
| Deployment Freezes | Freeze bypassed during regulatory blackout window | 10k – 120k |

Scenario B total (5-cap build + mid-range risk): **AUD 2,060,677**.

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
