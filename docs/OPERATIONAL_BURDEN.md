# Operational Burden: The Brutal Truth

## Executive Summary

Building enterprise-grade CI/CD using GitHub-native tooling at scale (1000+ repositories) requires:

- **15+ tools** that must be integrated and maintained
- **4-6 custom services** that we must build and operate
- **Estimated 6-12 months** to build initial implementation
- **2-4 FTE platform engineers** to maintain ongoing operations

**This document exposes every point of friction, operational overhead, and hidden complexity.**

---

## Tool Inventory & Integration Matrix

### Required Tools

| # | Tool | Purpose | Operational Burden | Cost |
|---|------|---------|-------------------|------|
| 1 | **GitHub Actions** | CI/CD orchestration | 🟡 Medium | Included |
| 2 | **GitHub Container Registry** | Artifact storage | 🟡 Medium | Storage costs |
| 3 | **GitHub Advanced Security** | CodeQL SAST, Dependabot | 🟢 Low | $$$ (per committer) |
| 4 | **Semgrep** | Additional SAST | 🟡 Medium | Free/Paid tiers |
| 5 | **Trivy** | Container scanning | 🟡 Medium | Free |
| 6 | **Grype** | Alternative scanning | 🟡 Medium | Free |
| 7 | **Syft** | SBOM generation | 🟢 Low | Free |
| 8 | **Cosign** | Artifact signing | 🟡 Medium | Free |
| 9 | **Conftest/OPA** | Policy enforcement | 🔴 High | Free (ops burden) |
| 10 | **ArgoCD** | GitOps controller | 🔴 High | Free (ops burden) |
| 11 | **Argo Rollouts** | Progressive delivery | 🔴 High | Free (ops burden) |
| 12 | **Istio/Nginx** | Service mesh/ingress | 🔴 High | Free (ops burden) |
| 13 | **Prometheus** | Metrics collection | 🔴 High | Free (ops burden) |
| 14 | **Grafana** | Dashboards | 🟡 Medium | Free (ops burden) |
| 15 | **Kubernetes** | Container orchestration | 🔴 **CRITICAL** | Cloud costs |

### Custom Services We Must Build

| # | Service | Purpose | Effort | Ongoing Burden |
|---|---------|---------|--------|----------------|
| 1 | **Deployment Gate Webhook** | Environment approval logic | 4 weeks | 🔴 Critical path |
| 2 | **DORA Metrics Collector** | Metrics aggregation | 3 weeks | 🟡 Medium |
| 3 | **Workflow Update Bot** | Reusable workflow rollout | 2 weeks | 🟡 Medium |
| 4 | **Policy Enforcement Service** | Centralized policy validation | 3 weeks | 🔴 High |
| 5 | **Environment Setup Automation** | Configure 3000 environments | 2 weeks | 🟡 Medium |
| 6 | **Compliance Reporting** | Audit logs + compliance reports | 3 weeks | 🟡 Medium |

**Total Custom Engineering**: **17 weeks** (4+ months) for initial build

---

## Integration Complexity

### Integration Points Map

```
GitHub Actions Workflow (service repo)
  │
  ├─→ Reusable Workflow (platform repo) ─────────┐
  │                                                │
  ├─→ GitHub Container Registry ──────────────────┼─→ Trivy scan
  │                                                │
  ├─→ CodeQL (GitHub Advanced Security)           │
  │                                                │
  ├─→ Semgrep Cloud ──────────────────────────────┤
  │                                                │
  ├─→ Conftest (pulls OPA policies from repo) ────┤
  │                                                │
  ├─→ Cosign (keyless signing via OIDC) ──────────┤
  │                                                │
  └─→ GitHub Environment (with protections) ──────┤
        │                                          │
        ├─→ Custom Webhook (Deployment Gate) ─────┼─→ Prometheus (metrics check)
        │     │                                    │
        │     ├─→ PagerDuty (incident check) ─────┤
        │     └─→ PostgreSQL (state)              │
        │                                          │
        └─→ OIDC Auth (GCP/AWS/Azure) ────────────┼─→ Kubernetes cluster
              │                                    │
              └─→ kubectl/helm ───────────────────┼─→ ArgoCD (GitOps model)
                    │                              │
                    └─→ GitOps Repo ───────────────┼─→ Argo Rollouts
                          │                        │
                          └────────────────────────┼─→ Istio VirtualService
                                                   │
                                                   └─→ Prometheus (analysis queries)
```

**Total Integration Points**: **20+**

**Failure Domains**: If ANY component fails, deployments stop.

---

## Day-in-the-Life: Platform Engineer

### Daily Operations

#### Morning (8 AM - 12 PM)

**Check dashboards**:
- GitHub Actions status (any org-wide failures?)
- GHCR storage usage (approaching quota?)
- ArgoCD sync status (any stuck applications?)
- Deployment gate service uptime
- Policy violations from previous day

**Triage alerts**:
- Reusable workflow failures across repos
- Policy enforcement failures
- Deployment gate rejections
- OIDC authentication errors
- ArgoCD out-of-sync applications

**Developer support**:
- "Why did my deployment fail?" (check 15 different places)
- "How do I add a new service?" (walk through onboarding)
- "Can you approve my policy exception?" (review + update OPA policy)
- "My workflow is slow" (investigate Actions runner queue)

#### Afternoon (1 PM - 5 PM)

**Platform maintenance**:
- Update reusable workflows
  - Create PR to platform repo
  - Test with pilot services
  - Plan rollout strategy
  - Update documentation
  - Announce to teams

- Rotate OIDC configurations (monthly)
  - Update workload identity bindings
  - Test authentication
  - Monitor for failures

- Update base images in approved list
  - Scan new images for vulnerabilities
  - Update OPA policy
  - Notify teams of new versions

**Incident response**:
- Deployment gate service is down → ALL deployments blocked
- GHCR experiencing issues → Builds failing
- ArgoCD not syncing → Deployments stuck
- Policy check failing incorrectly → Emergency bypass needed

### Weekly Operations

**Monday**: Planning
- Review DORA metrics
- Identify bottlenecks
- Plan improvements
- Prioritize developer requests

**Tuesday-Thursday**: Development
- Improve reusable workflows
- Fix bugs in custom services
- Add new security checks
- Optimize performance

**Friday**: Maintenance
- Update dependencies in reusable workflows
- Review security scan results
- Update policies based on new threats
- Clean up old container images (storage costs)

### Monthly Operations

- **Rotate secrets/credentials** (even with OIDC, some secrets remain)
- **Update base images** across all approved images
- **Review and update OPA policies**
- **Audit GitHub Environment configurations** (drift detection)
- **Capacity planning** (Actions runner minutes, GHCR storage)
- **Cost review** (GitHub Advanced Security per-committer costs)

### Quarterly Operations

- **Major reusable workflow updates** (breaking changes)
  - Coordinate with all teams
  - Staggered rollout across 1000 repos
  - Handle upgrade issues

- **Platform deprecations**
  - Remove old workflow versions
  - Force migrations

- **Compliance audits**
  - Generate reports
  - Address findings
  - Update policies

---

## What Breaks (Real Scenarios)

### Scenario 1: Reusable Workflow Bug

**Problem**: Bug in `ci-build-scan.yml@v2.3.0` causes all builds to fail

**Impact**: 1000 repositories cannot deploy

**Detection Time**: 5-30 minutes (depends on monitoring)

**Resolution**:
1. Identify bug (30 min - 2 hours)
2. Fix and publish `v2.3.1` (15 min - 1 hour)
3. Notify all teams to update (immediate)
4. Teams update their workflows (1-7 days)
   - Teams on vacation: stuck on broken version
   - Teams with frozen releases: can't update

**Mitigation**:
- Canary testing with pilot repos (adds process overhead)
- Automated rollback strategy (requires tooling)
- Version pinning prevents auto-updates (creates lag)

**Time to Full Recovery**: **1-7 days** for all repos to update

---

### Scenario 2: Deployment Gate Service Outage

**Problem**: Webhook service crashes, database is down, or network partition

**Impact**: ALL production deployments blocked (webhook times out → deployment fails)

**Detection Time**: Immediate (deployments start failing)

**Resolution Options**:

**Option A: Fix service** (1-4 hours)
- Restart service
- Fix database
- Restore from backup

**Option B: Emergency bypass** (15 minutes, but risky)
- Temporarily remove webhook from all environments
- Requires manual API calls × 1000 repos × 3 environments
- Security risk: deployments proceed without validation

**Option C: Manual approvals** (slow)
- Platform engineers manually approve each deployment
- Doesn't scale

**Mitigation**:
- Multi-region redundancy (doubles infrastructure cost)
- Fallback approval mechanism (adds complexity)
- Circuit breaker pattern (requires implementation)

---

### Scenario 3: OIDC Configuration Expires

**Problem**: Cloud provider workload identity binding expires or is misconfigured

**Impact**: All deployments fail with authentication errors

**Detection**: Deployments start failing with "403 Forbidden"

**Debugging**:
1. Check GitHub Actions logs → vague error
2. Check cloud provider IAM logs → rate limited
3. Realize OIDC token expired
4. Find which service account
5. Renew/recreate binding
6. Wait for propagation (5-15 minutes)
7. Retry failed deployments

**Time to Resolve**: 30 minutes - 2 hours

**Occurs**: Every 90 days (typical OIDC rotation) × number of cloud projects

---

### Scenario 4: Policy False Positive

**Problem**: OPA policy incorrectly rejects valid deployment

**Scenario**: New Node.js version released (`node:21-alpine`), not yet in approved list

**Impact**: Developers cannot deploy updates using new version

**Resolution**:
1. Developer reports issue (Slack/ticket)
2. Platform team investigates
3. Validate new base image is secure
4. Update OPA policy with new approved image
5. Merge policy update
6. Developer retries workflow

**Time to Resolve**: 2 hours - 2 days (depends on urgency)

**Frequency**: Every time dependencies update (monthly)

---

### Scenario 5: GitHub Actions Outage

**Problem**: GitHub Actions is down (happens 1-2x per year)

**Impact**: COMPLETE CI/CD STOPPAGE

**Mitigation**: **NONE** (fully dependent on GitHub SLA)

**Workaround**:
- Manual deployments via kubectl (bypasses all gates)
- Use backup CD system (requires maintaining parallel system)

**Business Impact**: Cannot deploy hotfixes during outage

---

### Scenario 6: ArgoCD Sync Failure

**Problem**: ArgoCD fails to sync GitOps repo

**Causes**:
- Invalid YAML in GitOps repo
- ArgoCD server crashes
- Kubernetes API server slow/unavailable
- Git repository authentication fails

**Impact**: Deployments stuck "pending ArgoCD sync"

**Debugging**:
1. Check ArgoCD UI (if accessible)
2. Check ArgoCD logs
3. Check Kubernetes cluster health
4. Check GitOps repo for syntax errors
5. Manually trigger sync
6. If fails, manual kubectl apply (bypass ArgoCD)

**Time to Resolve**: 15 minutes - 4 hours

---

### Scenario 7: Container Image Exceeds GHCR Rate Limit

**Problem**: Too many image pulls hit GHCR rate limit

**Impact**: Kubernetes pods fail to start, deployments fail

**Occurs**: During high-traffic deployments or cluster scale-up

**Resolution**:
- Wait for rate limit reset (1 hour)
- Use image pull secrets with authenticated access (better limits)
- Implement image caching in cluster

**Prevention**: Requires capacity planning and monitoring

---

### Scenario 8: Secret Sprawl Nightmare

**Problem**: Service needs new secret added to all environments

**Impact**: 1000 repos × 3 environments = **3000 manual secret additions** (or API calls)

**Time**: 5 minutes per secret × 3000 = **250 hours** if done manually

**Solution**: Script it
```bash
for repo in $(gh api /orgs/myorg/repos --paginate --jq '.[].name'); do
  for env in dev staging production; do
    gh secret set MY_SECRET --repo myorg/$repo --env $env --body "$VALUE"
  done
done
```

**But**:
- GitHub API rate limits
- Error handling
- Audit logging
- Verification

---

## Scalability Bottlenecks

### 1. GitHub Actions Concurrency

**Limit**: Varies by plan
- Free: 20 concurrent jobs
- Team: 60 concurrent jobs
- Enterprise: Negotiable

**At Scale**:
- 1000 repos
- Mass PR merge (e.g., Dependabot updates)
- All trigger CI pipelines simultaneously

**Result**: Job queueing, delayed deployments

**Solution**: Enterprise plan + pay for additional runners ($$$)

---

### 2. GitHub API Rate Limits

**Limit**: 5000 requests/hour (authenticated)

**Automation needs**:
- Environment setup script: 10 requests per repo
- Secret management: 3 requests per secret per repo
- Metrics collection: 100s of requests per hour

**At 1000 repos**: Easy to hit limits

**Solution**:
- Request higher limits (Enterprise only)
- Implement caching
- Use GraphQL (fewer requests)
- Parallelize across multiple tokens

---

### 3. GHCR Storage Costs

**Calculation**:
- 1000 services
- 3 environments × 10 versions retained = 30 images per service
- Average image size: 500 MB

**Total storage**: 1000 × 30 × 0.5 GB = **15 TB**

**Cost**: GitHub Packages pricing is $0.25/GB/month after free tier

**Annual cost**: 15,000 GB × $0.25 × 12 = **$45,000/year**

**Mitigation**:
- Aggressive image retention policies
- Multi-architecture images increase this further
- Use external registry (adds another system)

---

### 4. Workflow Runtime Costs

**GitHub Actions pricing** (after free tier):
- Linux runners: $0.008/minute
- macOS runners: $0.08/minute

**Example**:
- CI pipeline: 10 minutes
- CD pipeline: 5 minutes
- 1000 repos × 5 deploys/day = 5000 deploys/day

**Daily cost**: 5000 × 15 min × $0.008 = **$600/day**

**Annual cost**: **$219,000/year**

**This does NOT include**:
- Larger runners (2x-4x cost)
- Self-hosted runner infrastructure
- Network egress costs

---

## Comparison: GitHub vs Dedicated CD Platform

| Capability | GitHub-Native | Harness/Spinnaker | Gap |
|------------|---------------|-------------------|-----|
| **Initial Setup** | 4-6 months custom engineering | 2-4 weeks configuration | ⚠️ **HUGE** |
| **Deployment Gates** | Custom webhook service | Built-in policy engine | ⚠️ Major |
| **Progressive Delivery** | ArgoCD + Argo Rollouts + Istio | Native canary/blue-green | ⚠️ Major |
| **Metrics Integration** | Custom DORA collector | Built-in metrics + integrations | ⚠️ Major |
| **Rollback** | Manual workflow trigger | One-click rollback | ⚠️ Moderate |
| **Environment Management** | Per-repo API/Terraform | Centralized configuration | ⚠️ **HUGE** |
| **Secret Management** | GitHub Secrets + OIDC | Native secret managers | ⚠️ Moderate |
| **Audit Trail** | GitHub audit log | Purpose-built audit UI | ⚠️ Minor |
| **Multi-Cloud** | Requires OIDC per provider | Native connectors | ⚠️ Moderate |
| **Deployment Verification** | Custom Prometheus queries | Native verification | ⚠️ Major |
| **Approval Workflows** | GitHub Environments | Advanced approval policies | ⚠️ Moderate |
| **Dashboard** | Custom Grafana | Built-in dashboards | ⚠️ Major |
| **RBAC** | GitHub teams + branch protection | Fine-grained deployment RBAC | ⚠️ Moderate |
| **Policy as Code** | OPA (we run it) | Native policy engine | ⚠️ Moderate |
| **Operational Burden** | **2-4 FTE** | **0.5-1 FTE** | ⚠️ **HUGE** |

---

## Total Cost of Ownership (TCO) Analysis

### GitHub-Native Approach

**Year 1** (Build + Operate):
- Platform engineering team: 4 FTE × $180k = **$720k**
- GitHub Enterprise: $21/user/month × 500 users × 12 = **$126k**
- GitHub Advanced Security: $49/committer × 200 = **$9,800/month** = **$117.6k/year**
- GitHub Actions compute: **$219k/year**
- GHCR storage: **$45k/year**
- Infrastructure (webhook services, DBs, Prometheus, Grafana, ArgoCD): **$50k/year**

**Year 1 Total**: **$1,277,600**

**Year 2+** (Operate):
- Platform engineering team: 2-3 FTE × $180k = **$360-540k**
- GitHub costs: **$492k/year**
- Infrastructure: **$50k/year**

**Year 2+ Annual**: **$902k - $1,082k**

---

### Dedicated CD Platform (e.g., Harness)

**Year 1** (Implement):
- Harness Enterprise: ~$150k-250k/year (depends on scale)
- Platform engineering: 2 FTE × $180k = **$360k**
- GitHub (still needed for CI): **$365k/year**

**Year 1 Total**: **$875k - $975k**

**Year 2+** (Operate):
- Harness Enterprise: **$150-250k/year**
- Platform engineering: 1 FTE × $180k = **$180k**
- GitHub: **$365k/year**

**Year 2+ Annual**: **$695k - $795k**

---

### TCO Comparison (5 Years)

**GitHub-Native**:
- Year 1: $1,277k
- Years 2-5: $992k × 4 = $3,968k
- **Total**: **$5,245,000**

**Dedicated Platform**:
- Year 1: $925k
- Years 2-5: $745k × 4 = $2,980k
- **Total**: **$3,905,000**

**Savings with Dedicated Platform**: **$1,340,000 over 5 years**

---

## Things That Are Harder Than Expected

### 1. Workflow Versioning Strategy

**Problem**: How do we update workflows across 1000 repos?

**Options**:
- **Branch pinning** (`@main`): Auto-updates, but breaks everything if main has bug
- **Tag pinning** (`@v2.3.0`): Safe, but requires updating 1000 repos
- **SHA pinning** (`@abc123`): Most secure, but impossible to update

**Reality**: No good answer. Each approach has major tradeoffs.

---

### 2. Policy Enforcement Security

**Problem**: OPA policies run IN the workflow, so developers can modify workflow to skip

**Options**:
- Required status checks (can be bypassed by admin)
- External policy service (adds latency + complexity)
- Workflow pulled from protected external repo (complicates development)

**Reality**: Cannot achieve true mandatory enforcement without external system.

---

### 3. Cross-Repo Dependencies

**Problem**: Service A depends on Service B, both deploying simultaneously

**GitHub Actions**: No native dependency management across repos

**Solutions**:
- Manual coordination
- Repository dispatch events (complex)
- External orchestration layer (defeats purpose)

**Reality**: Multi-service deployments require custom orchestration.

---

### 4. Environment Parity

**Problem**: Keeping dev/staging/prod configurations in sync

**Reality**:
- Different resource limits
- Different secrets
- Different integrations
- Configuration drift inevitable

**Solution**: Requires constant vigilance + tooling.

---

## Final Verdict

### Can You Build Enterprise CI/CD with GitHub-Native Tooling?

**Answer**: Yes, but...

✅ **Technically Possible**
✅ **Works for small-medium scale** (10-100 repos)
✅ **Tight integration with GitHub features**
✅ **No vendor lock-in to CD platform**

❌ **Requires significant custom engineering**
❌ **Operational burden scales linearly with repos**
❌ **Missing critical features (progressive delivery, deployment verification)**
❌ **Higher TCO than dedicated platform at scale**
❌ **Platform engineering team becomes bottleneck**
❌ **Incident response is complex** (too many integration points)

---

### When Does GitHub-Native Make Sense?

✅ **Startup/Small Org** (< 50 repos)
✅ **Simple deployment patterns** (no canary/blue-green needed)
✅ **Strong platform engineering team** (can build custom tooling)
✅ **GitHub-first culture** (want everything in GitHub)
✅ **Cost-sensitive** (in year 1 only)

---

### When Should You Use a Dedicated Platform?

✅ **Enterprise scale** (500+ repos)
✅ **Regulated industry** (need comprehensive audit trails)
✅ **Complex deployment patterns** (progressive delivery, multi-region)
✅ **Limited platform engineering capacity**
✅ **Multi-cloud deployments**
✅ **Business-critical SLAs** (need vendor support)

---

## Recommendation

For an organization with **1000+ repositories**:

**Use GitHub for CI** (build, test, security scanning)
- GitHub Actions is excellent for this
- Tight integration with GitHub features
- Good developer experience

**Use dedicated platform for CD** (deployment, verification, rollback)
- Harness, Spinnaker, or Argo CD (full platform, not just GitOps)
- Centralized configuration
- Built-in progressive delivery
- Comprehensive audit and compliance features
- Lower operational burden

**Hybrid approach provides**:
- ✅ Best developer experience (GitHub for daily work)
- ✅ Least operational burden (dedicated platform for complex deployments)
- ✅ Flexibility (can migrate between CD platforms without changing CI)

---

**The goal wasn't to prove GitHub can't do it.**

**The goal was to expose what it truly costs to make it work at scale.**

**And that cost is higher than most organizations expect.**
