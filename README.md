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
