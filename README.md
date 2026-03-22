# GitHub Actions vs Harness CD: The Enterprise Reality

**Can GitHub Actions replace a purpose-built CD platform for heterogeneous enterprises?**

**No. GitHub costs MORE and delivers LESS.**

---

## The Verdict

**For heterogeneous enterprises** (1000+ services, multi-cloud, VMs, serverless, on-prem):

| | GitHub Actions | Harness CD |
|---|---|---|
| **5-Year Cost** | $9.0M | $5.5M |
| **Platform Team** | 6.4 FTE (firefighting) | 2 FTE (building features) |
| **Custom Code** | 202,500+ lines | 0 lines |
| **Rollback** | ❌ Redeploy (5-15 min) | ✅ One-click (< 1 min) |
| **Verification** | ❌ None | ✅ ML-based auto-rollback |
| **Multi-Platform** | ❌ Custom scripts | ✅ Native support |
| **Database DevOps** | ❌ Custom Liquibase/Flyway | ✅ Native with rollback |
| **Release Management** | ❌ No calendaring/orchestration | ✅ Blackout windows, manual gates |
| **Supply Chain** | ❌ 15,000 mutable dependencies | ✅ Governed templates (OPA) |
| **Security Bypass** | ⚠️ One architectural gap | ✅ None (sequential stages) |

**Harness is $3.5M cheaper with 10× the capability.**

---

## The Proof

**Live CI/CD pipelines** running on every push:
- **user-service** (Node.js)
- **payment-service** (Go)
- **notification-service** (Python)

Each with: Build → Test → Scan → SBOM → Sign → Deploy

**Watch them run**: https://github.com/gregkroon/githubexperiment/actions

---

## Read This Based on Your Role

### 👨‍💻 Engineers: Hands-On Demo (20 min)
**[→ DEMO.md](docs/DEMO.md)** - Walk through actual implementation, see the 8 critical gaps

### 👔 Leadership & Finance: Business Case (10 min)
**[→ EXECUTIVE_SUMMARY.md](docs/EXECUTIVE_SUMMARY.md)** - Strategic decision framework, detailed cost breakdown, security analysis (see appendices)

---

## What GitHub Actions CANNOT Do

### 1. ❌ No One-Click Rollback
**GitHub**: Revert code + redeploy (5-15 min MTTR)
**Harness**: Click button (< 1 min MTTR)
**Impact**: One outage = $5M+ lost revenue

### 2. ❌ No Deployment Verification
**GitHub**: Deploy and hope
**Harness**: ML-based anomaly detection, auto-rollback
**Impact**: Bad deploys reach production

### 3. ❌ Heterogeneous = 2,500+ Lines Custom Code
**GitHub**: Custom scripts for VMs, ECS, Lambda, on-prem
**Harness**: Native support, vendor-maintained
**Impact**: 4.5 FTE maintaining vs 2 FTE managing

### 4. ❌ No Multi-Service Orchestration
**GitHub**: Can't enforce deployment order across services
**Harness**: Dependency graphs built-in
**Impact**: Complex deployments fail silently

### 5. ❌ No Database DevOps
**GitHub**: Custom Liquibase/Flyway scripts, no rollback
**Harness**: Native DB schema management with rollback
**Impact**: Database changes deployed blind, no safe rollback path

### 6. ❌ No Release Management
**GitHub**: No deployment calendaring, blackout windows, or manual gates
**Harness**: Release calendars, blackout periods, manual approval integration
**Impact**: Friday 5pm deploys, no holiday freeze enforcement, no change board integration

### 7. ❌ Supply Chain Vulnerability
**GitHub**: 15,000 mutable marketplace dependencies (Aqua Trivy breach 2024)
**Harness**: Governed template library, OPA policy enforcement, zero marketplace exposure
**Impact**: $50M+ breach risk, 1.4 FTE reviewing Dependabot PRs

### 8. ⚠️ Parallel Execution Security Gap
**GitHub Enterprise Required Workflows** prevent most bypasses (skip scan, continue-on-error, bypass branch protection) BUT workflows run in **parallel** - deployment can complete before Required Workflow security scan finishes.

**Harness**: Sequential pipeline stages architecturally block deployment until security passes.

**[See detailed analysis in EXEC_SUMMARY appendix →](docs/EXECUTIVE_SUMMARY.md#appendix-security-bypass-analysis)**

---

## The Hidden Liability: Supply Chain Security & The Marketplace Threat

### GitHub Actions Marketplace: An Unmanaged Attack Surface

**The Aqua Security Trivy Breach** (2024) exposed a critical architectural flaw in GitHub Actions: **mutable marketplace dependencies create an enterprise-wide supply chain vulnerability.**

#### What Happened
```yaml
# Thousands of repos use this pattern:
- uses: aquasecurity/trivy-action@v0.24.0  # Mutable tag
```

**The Attack**:
1. Attacker compromises maintainer account
2. Force-pushes malicious code to existing `v0.24.0` tag
3. Next workflow run executes credential stealer
4. Attacker harvests AWS keys, K8s tokens, GitHub tokens from runner memory
5. **1000 repositories × $5M average breach cost = $5B exposure**

#### Why This Is Architectural

GitHub Actions workflows run with **highly privileged credentials**:
- AWS `AssumeRole` with production access
- Kubernetes service account tokens
- NPM publish tokens
- Docker registry credentials
- GitHub PATs with org-wide permissions

**A single compromised action = instant lateral movement across entire infrastructure.**

#### The "Pin to SHA" Defense Doesn't Scale

**Security teams recommend**:
```yaml
- uses: aquasecurity/trivy-action@d9cd5b1c8ee3c92e2b2c7b1c3e4f5a6b7c8d9e0f  # Immutable SHA
```

**Enterprise reality**:
- 1000 services × 15 GitHub Actions per workflow = **15,000 SHA pins to maintain**
- Each action updates monthly = **15,000 digest updates/month**
- Dependabot creates 15,000 PRs requiring security review
- **Platform team drowns in toil, updates lag, vulnerabilities persist**

#### Harness Approach: Governed Template Library

**Centralized control plane**:
```yaml
# Pipeline references governed template (not open marketplace)
- step:
    type: SecurityScan
    spec:
      template: trivy-enterprise-v2  # Internal vetted template
```

**Security advantages**:
- ✅ **Internal template library**: Platform team vets and publishes templates
- ✅ **Policy-as-Code (OPA)**: Block execution of non-approved templates
- ✅ **Immutable versioning**: Templates versioned, not mutable tags
- ✅ **SLSA L3 provenance**: Native build attestation
- ✅ **Centralized updates**: Update 1 template, propagates to 1000 services
- ✅ **No marketplace exposure**: Zero external dependency risk

#### Real-World Impact: SolarWinds-Scale Risk

**If Trivy breach had succeeded**:
- Attacker gains AWS credentials from 1000 CI runners
- Lateral movement to production Kubernetes clusters
- Data exfiltration from customer databases
- Ransomware deployment across infrastructure
- **Breach cost: $50M - $500M** (IBM 2024 Cost of Data Breach)

**GitHub Actions**: You're one force-push away from a SolarWinds-scale supply chain attack.

**Harness**: Governed templates + OPA policy enforcement architecturally prevents marketplace attacks.

#### The Executive Question

**"Can your CISO explain to the board why you're trusting 15,000 mutable marketplace dependencies with production credentials?"**

- GitHub Actions: ❌ No architectural defense, operational burden doesn't scale
- Harness: ✅ Policy-enforced template governance, centralized security control

**[See ADR-001 for technical security rationale →](docs/ADR-001-rejecting-pure-gitops-for-composite-releases.md)**

---

## The Stateless Push Trap: Why CI Runners Cannot Be CD Platforms

### GitHub Actions Is a CI Tool, Not a CD Platform

**The Fundamental Architecture Problem**: GitHub Actions is a **stateless, ephemeral task runner** designed for Continuous Integration (build, test, scan). Using it for Continuous Delivery forces imperative push-based deployments with no state management.

#### What "Stateless" Means for Deployment

**GitHub Actions runner lifecycle**:
```yaml
1. Spin up ephemeral runner (fresh Ubuntu VM)
2. Execute workflow steps sequentially
3. Runner terminates, all state discarded
4. No memory of what was deployed, where, or when
```

**Consequences**:
- ❌ No deployment state tracking
- ❌ No artifact versioning across environments
- ❌ No rollback history
- ❌ No deployment topology understanding
- ❌ Runner dies mid-deploy = permanently broken state

#### The "God-Mode" Runner Problem

Because runners are stateless and must **push** changes to production, they require **highly privileged credentials**:

```yaml
# Every deployment workflow needs:
- AWS OIDC token with production AssumeRole
- Kubernetes admin service account (cluster-wide)
- RDS admin credentials (for schema migrations)
- S3 bucket write permissions
- Lambda function update permissions
- Secrets manager read/write

# All in runner memory, all vulnerable to compromise
```

**Attack surface**:
- Compromised marketplace action = instant access to all credentials
- Runner introspection = credential harvesting
- **One malicious step = full infrastructure breach**

#### The Composite Release Nightmare

**Scenario**: Deploy 4-tier application
1. **S3** - React SPA frontend
2. **EKS** - Spring Boot API backend
3. **Lambda** - Event processor
4. **RDS** - Database schema migration (Flyway)

**GitHub Actions approach**: Imperative bash scripts
```yaml
jobs:
  deploy-composite-release:
    runs-on: ubuntu-latest
    steps:
      # Step 1: Deploy database migration
      - name: Run Flyway Migration
        run: |
          flyway migrate -url=${{ secrets.RDS_URL }}
          # ❌ No state tracking - did this succeed?
          # ❌ No automatic rollback on failure
          # ❌ If runner dies here, state unknown

      # Step 2: Deploy EKS backend
      - name: Deploy to EKS
        run: |
          kubectl apply -f k8s/deployment.yaml
          kubectl rollout status deployment/api
          # ❌ What if this fails? Database already migrated!
          # ❌ Must manually write rollback logic

      # Step 3: Deploy Lambda
      - name: Deploy Lambda
        run: |
          aws lambda update-function-code --function-name processor
          # ❌ Fails due to IAM error
          # ❌ EKS and RDS already deployed
          # ❌ No automatic rollback coordination

      # Step 4: Deploy S3 frontend
        if: success()  # ⚠️ Doesn't run because Lambda failed
        run: |
          aws s3 sync build/ s3://frontend/
```

**What actually happened**:
- ✅ Database migrated (cannot undo schema changes)
- ✅ EKS backend deployed (new version running)
- ❌ Lambda failed (IAM error)
- ❌ S3 frontend not deployed (skipped due to failure)

**System state**: **Permanently broken**
- Backend expects new schema (deployed)
- Event processor still on old version (failed)
- Frontend not updated (skipped)
- **No coordinated rollback capability**

#### The Manual Rollback Hell

**To recover, platform engineer must**:

```bash
# 1. Manually rollback EKS (hope kubectl works)
kubectl rollout undo deployment/api
kubectl rollout status deployment/api  # Poll manually

# 2. Manually rollback database (hope you have rollback script)
flyway undo -url=$RDS_URL
# ⚠️ What if undo script doesn't exist?
# ⚠️ What if schema change is irreversible (column drop)?

# 3. Fix Lambda IAM issue
aws iam attach-role-policy ...  # Debug IAM policy

# 4. Re-run entire deployment (hope it works this time)
# 5. TOTAL TIME: 30-60 minutes (production broken)
```

**With state-aware CD platform**:
```yaml
# One-click rollback to last known good state
# Platform knows:
# - What was deployed where
# - Which artifacts to rollback to
# - Correct rollback order (reverse of deploy)
# - State verification after rollback

# TOTAL TIME: < 1 minute
```

#### Why "if: failure()" Doesn't Save You

**Naive attempt at automatic rollback**:
```yaml
- name: Deploy Lambda
  id: lambda
  run: aws lambda update-function-code ...

- name: Rollback EKS if Lambda Failed
  if: failure() && steps.lambda.conclusion == 'failure'
  run: |
    kubectl rollout undo deployment/api
    # ⚠️ What if kubectl command fails?
    # ⚠️ What if network drops mid-rollback?
    # ⚠️ If this step fails, NO RETRY LOGIC
```

**Problems**:
- `if: failure()` is not transactional
- Runner can die during rollback step
- No rollback verification
- No rollback of rollback (if rollback fails)
- **Must write custom error handling for every deployment target**

**Result**: 1000 services × 6 deployment targets × custom rollback logic = **maintenance nightmare**

#### The State Management You Must Build

**To make GitHub Actions behave like a CD platform, you must**:

1. **Build deployment state store**
   ```python
   # Custom service to track:
   - What version deployed to which environment
   - When it was deployed
   - Who approved it
   - Current rollback target for each service
   # Build time: 4-6 weeks
   # Maintenance: 6 hrs/week
   ```

2. **Build coordinated rollback orchestrator**
   ```python
   # Custom service to:
   - Understand service dependencies
   - Rollback in reverse order
   - Verify each rollback step
   - Handle partial rollback failures
   # Build time: 12 weeks
   # Maintenance: 10 hrs/week
   ```

3. **Build deployment verification**
   ```python
   # Custom service to:
   - Query Prometheus/DataDog after deploy
   - Detect anomalies (error rate spike)
   - Trigger automatic rollback
   # Build time: 6 weeks
   # Maintenance: 6 hrs/week
   ```

**Total**: 22 weeks build + 22 hrs/week maintenance = **You're building a CD platform from scratch**

#### Harness: State-Aware CD Control Plane

**Architecture**:
```
┌─────────────────────────────────────────────────┐
│  Harness Control Plane (SaaS)                   │
│  ├─ Deployment State Store (Persistent)         │
│  ├─ Artifact Version Tracking                   │
│  ├─ Rollback History (Last 50 deployments)      │
│  ├─ Service Dependency Graph                    │
│  └─ Policy Engine (OPA)                         │
└─────────────────────────────────────────────────┘
         │
         │ Outbound HTTPS (poll-based)
         ▼
┌─────────────────────────────────────────────────┐
│  Harness Delegate (In VPC)                      │
│  ├─ No inbound connections                      │
│  ├─ Polls control plane for tasks               │
│  ├─ Executes with least-privilege IAM           │
│  └─ Reports state back to control plane         │
└─────────────────────────────────────────────────┘
```

**Composite release with state management**:
```yaml
pipeline:
  stages:
    - stage:
        name: Database Migration
        spec:
          service: rds-schema
          execution:
            - step: FlywayMigrate
              rollbackSteps:  # Native rollback
                - FlywayUndo

    - stage:
        name: Backend API
        dependencies: [Database Migration]  # Enforced order
        spec:
          service: spring-api
          execution:
            - step: K8sRollingDeploy
              rollbackSteps:  # Native rollback
                - K8sRollback

    - stage:
        name: Event Processor
        dependencies: [Backend API]
        spec:
          service: lambda-processor
          execution:
            - step: LambdaDeploy
              # Fails here
              rollbackSteps:  # Never executes

# Harness detects failure, automatically rolls back:
# 1. Backend API (kubectl rollout undo)
# 2. Database Migration (flyway undo)
# 3. All in reverse dependency order
# 4. Verifies each rollback step
# 5. Reports final state to control plane

# TOTAL TIME: < 1 minute
# STATE: Rolled back to last known good
```

**Security advantages**:
- ✅ **Delegates poll outbound** (no inbound attack surface)
- ✅ **Least-privilege IAM** (scoped per delegate, not god-mode)
- ✅ **Credentials never in runner memory** (stored in secrets manager, injected per-step)
- ✅ **Governed templates** (no marketplace exposure)
- ✅ **Policy enforcement** (OPA blocks unapproved deployments)

#### The Executive Reality

**"Can you afford 30-60 minute MTTR because GitHub Actions has no deployment state?"**

| Outage Cost | GitHub Actions MTTR | Harness MTTR | Cost Difference |
|-------------|---------------------|--------------|-----------------|
| $5M/hour | 30 min = $2.5M | 1 min = $83k | **$2.42M per incident** |
| 99.99% SLA | 30 min = 58% of annual budget | 1 min = 2% of budget | **29× improvement** |

**One production incident pays for Harness.**

**[See ADR-001: Imperative Rollback Nightmare →](docs/ADR-001-the-imperative-rollback-nightmare.md)**
**[See ADR-002: God-Mode Runners & Supply Chain →](docs/ADR-002-supply-chain-and-god-mode-runners.md)**

---

## The Cost Reality

### GitHub Actions (5-Year TCO)
```
Licenses:          $250k  (GitHub Enterprise, 200 users)
Custom dev:      $1,100k  (Build + maintain 202,500 lines)
Platform team:   $6,400k  (6.4 FTE × $200k × 5 years)
Security review:   $280k  (1.4 FTE × $200k × 1 year - Dependabot PRs)
Hidden costs:    $1,000k  (Incidents, silos, compliance, DB failures, Friday 5pm disasters)
────────────────────────
TOTAL:           $9,030k
```

### Harness CD (5-Year TCO)
```
Licenses:        $3,230k  (GitHub Team + Harness Enterprise)
Prof services:     $300k  (Year 1 implementation)
Platform team:   $2,000k  (2 FTE × $200k × 5 years)
────────────────────────
TOTAL:           $5,530k
```

**Harness saves $3,500k (39%) with 10× more capability**

**[See detailed workings in EXEC_SUMMARY →](docs/EXECUTIVE_SUMMARY.md#appendix-cost-calculations)**

---

## The Right Architecture

**✅ Use each tool for its strengths:**

**GitHub Actions for CI**:
- Build & test orchestration
- Security scanning (CodeQL, Trivy, Dependabot)
- SBOM generation
- Artifact publishing

**Harness CD for deployments**:
- Multi-platform deployments
- Rollback & verification
- Deployment strategies (canary, blue-green)
- Orchestration & governance
- Database DevOps (schema migrations, rollback)
- Release management (calendaring, blackout windows, manual gates)

---

## When to Use What

### Use GitHub Actions (CI + CD) If:
- ✅ < 50 services
- ✅ 100% Kubernetes in single cloud
- ✅ High trust in developers
- ✅ Can accept no rollback/verification
- ✅ Unlimited platform engineering time

**Cost**: ~$1-2M over 5 years
**Risk**: One multi-cloud mandate = complete rebuild

---

### Use Harness CD If:
- ✅ 200+ services
- ✅ ANY deployment heterogeneity (K8s + VMs/ECS/Lambda/on-prem)
- ✅ Need rollback capability
- ✅ Need deployment verification
- ✅ Limited platform engineering capacity
- ✅ Governance requirements (windows, approvals, freezes)

**Cost**: ~$5.5-6M over 5 years
**Benefit**: $420k cheaper than GitHub + 10× capability

**[See decision framework →](docs/EXECUTIVE_SUMMARY.md)**

---

## Quick Start

```bash
# Fork and run
gh repo fork gregkroon/githubexperiment
cd githubexperiment
echo "test" >> README.md && git commit -am "trigger" && git push

# Watch workflows
gh run watch
```

**Then try**:
1. Roll back a deployment (you can't)
2. Verify deployment health (no built-in way)
3. Orchestrate multi-service deploy (custom code required)

**[Full demo →](docs/DEMO.md)**

---

## FAQ

**Q: Is this GitHub bashing?**
No. GitHub Actions is **excellent for CI**. This shows it's not suitable for enterprise **CD** at heterogeneous scale.

**Q: Can't GitHub Enterprise Required Workflows prevent security bypasses?**
Mostly yes. GitHub Enterprise prevents 4 of 5 bypass attempts (skip scan, continue-on-error, modify workflow, bypass branch protection). But ONE architectural gap remains: parallel execution allows deployment before Required Workflow completes. **[See detailed analysis →](docs/EXECUTIVE_SUMMARY.md#appendix-security-bypass-analysis)**

**Q: What about adding Terraform/Vault/Argo?**
Adding tools doesn't fix fundamental gaps (no rollback, no verification, parallel execution). You're now maintaining 3+ tools instead of 1.

**Q: Vendor lock-in to Harness?**
You're choosing between:
- Lock-in to 2,500+ lines custom code + 4.5 FTE tribal knowledge (GitHub)
- Lock-in to working platform with vendor support (Harness)

Migrating FROM Harness is easier than rewriting unmaintainable custom code.

**Q: Is the cost analysis realistic?**
Conservative. Real FTE cost is $250k (we used $200k). All assumptions documented in detail. **[Audit the math →](docs/EXECUTIVE_SUMMARY.md#appendix-cost-calculations)**

**Q: What about K8s-only environments?**
GitHub can work BUT you're still missing rollback and verification. And you're one platform mandate away from needing Harness anyway. **[See heterogeneous analysis →](docs/EXECUTIVE_SUMMARY.md#appendix-heterogeneous-reality)**

---

## The Bottom Line

**For homogeneous K8s shops** (< 200 services):
GitHub might work with custom engineering (~$2M over 5 years)
**But**: Still missing rollback, verification, orchestration

**For heterogeneous enterprises** (1000+ services):
GitHub costs MORE ($9.0M vs $5.5M) with LESS capability
**Harness**: $3.5M cheaper + rollback + verification + orchestration + database DevOps + release management + supply chain security

**Stop building what Harness already has.**

---

## All Documentation

| Doc | Purpose | Time | For |
|-----|---------|------|-----|
| **[README.md](README.md)** | Overview & quick start | 5 min | Everyone |
| **[DEMO.md](docs/DEMO.md)** | Hands-on walkthrough | 20 min | Engineers |
| **[EXECUTIVE_SUMMARY.md](docs/EXECUTIVE_SUMMARY.md)** | Business case + detailed appendices | 10 min | Leadership, Finance, Security |

**EXECUTIVE_SUMMARY includes comprehensive appendices**:
- Cost calculations with FTE breakdowns
- Security bypass analysis (what GitHub Enterprise can/cannot prevent)
- Heterogeneous reality (multi-platform cost analysis)

---

## Contributing

Independent analysis. Contributions welcome:
- Cost model improvements
- Deployment scenarios
- Enterprise case studies
- Workarounds we missed

**Open an issue or PR**

---

## License

MIT - Use this however helps your organization make informed decisions

---

## The Honest Conclusion

**GitHub Actions: Excellent CI tool, poor CD platform**

**For 95% of enterprises** (heterogeneous infrastructure):
- Harness is $3.5M cheaper
- Harness requires 4.4 fewer FTE
- Harness has rollback (< 1 min vs 5-15 min)
- Harness has verification (catches bad deploys)
- Harness has orchestration (multi-service dependencies)
- Harness has database DevOps (schema migrations with rollback)
- Harness has release management (calendaring, blackout windows, manual gates)
- Harness has supply chain security (governed templates, zero marketplace exposure)
- Harness has zero custom code (vs 202,500+ lines)

**Use the right tool for the job:**
- ✅ GitHub Actions for CI
- ✅ Harness CD for deployments

**[See the proof →](docs/DEMO.md)** | **[See the math →](docs/EXECUTIVE_SUMMARY.md#appendix-cost-calculations)** | **[See security analysis →](docs/EXECUTIVE_SUMMARY.md#appendix-security-bypass-analysis)**
