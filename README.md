# GitHub Actions vs Harness CD: The Enterprise Reality

**Can GitHub Actions replace a purpose-built CD platform for heterogeneous enterprises?**

**No. GitHub costs MORE and delivers LESS.**

---

## The Verdict

**For heterogeneous enterprises** (1000+ services, multi-cloud, VMs, serverless, on-prem):

| | GitHub Actions | Harness CD |
|---|---|---|
| **5-Year Cost** | $6.5M | $6.0M |
| **Platform Team** | 4.5 FTE (firefighting) | 2 FTE (building features) |
| **Custom Code** | 2,500+ lines | 0 lines |
| **Rollback** | ❌ Redeploy (5-15 min) | ✅ One-click (< 1 min) |
| **Verification** | ❌ None | ✅ ML-based auto-rollback |
| **Multi-Platform** | ❌ Custom scripts | ✅ Native support |
| **Security Bypass** | ⚠️ One architectural gap | ✅ None (sequential stages) |

**Harness is $500k cheaper with 10× the capability.**

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
**[→ DEMO.md](docs/DEMO.md)** - Walk through actual implementation, see the 5 critical gaps

### 👔 Leadership: Business Case (5 min)
**[→ EXECUTIVE_SUMMARY.md](docs/EXECUTIVE_SUMMARY.md)** - Strategic decision framework

### 💰 Finance: Detailed Cost Analysis (25 min)
**[→ COST_ANALYSIS.md](docs/COST_ANALYSIS.md)** - Line-by-line breakdown, 16 cited sources, sensitivity analysis

### 🔒 Security Teams: Bypass Analysis (15 min)
**[→ SECURITY_ENFORCEMENT.md](docs/SECURITY_ENFORCEMENT.md)** - GitHub Enterprise features tested, what works vs what doesn't

### 🏢 Enterprise Architects: Multi-Platform Reality (10 min)
**[→ HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md)** - Why heterogeneous changes the cost equation

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

### 5. ⚠️ Parallel Execution Security Gap
**GitHub Enterprise Required Workflows** prevent most bypasses (skip scan, continue-on-error, bypass branch protection) BUT workflows run in **parallel** - deployment can complete before Required Workflow security scan finishes.

**Harness**: Sequential pipeline stages architecturally block deployment until security passes.

**[See detailed security analysis →](docs/SECURITY_ENFORCEMENT.md)**

---

## The Cost Reality

### GitHub Actions (5-Year TCO)
```
Licenses:          $250k  (GitHub Enterprise, 200 users)
Custom dev:        $800k  (Build + maintain 2,500 lines)
Platform team:    $4,500k (4.5 FTE × $200k × 5 years)
Hidden costs:      $400k  (Incidents, silos, compliance)
────────────────────────
TOTAL:           $5,950k
```

### Harness CD (5-Year TCO)
```
Licenses:        $3,230k  (GitHub Team + Harness Enterprise)
Prof services:     $300k  (Year 1 implementation)
Platform team:   $2,000k  (2 FTE × $200k × 5 years)
────────────────────────
TOTAL:           $5,530k
```

**Harness saves $420k (7%) with 10× more capability**

**[See detailed workings →](docs/COST_ANALYSIS.md)** (auditable to line-item, 16 sources)

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
Mostly yes. GitHub Enterprise prevents 4 of 5 bypass attempts (skip scan, continue-on-error, modify workflow, bypass branch protection). But ONE architectural gap remains: parallel execution allows deployment before Required Workflow completes. **[See detailed analysis →](docs/SECURITY_ENFORCEMENT.md)**

**Q: What about adding Terraform/Vault/Argo?**
Adding tools doesn't fix fundamental gaps (no rollback, no verification, parallel execution). You're now maintaining 3+ tools instead of 1.

**Q: Vendor lock-in to Harness?**
You're choosing between:
- Lock-in to 2,500+ lines custom code + 4.5 FTE tribal knowledge (GitHub)
- Lock-in to working platform with vendor support (Harness)

Migrating FROM Harness is easier than rewriting unmaintainable custom code.

**Q: Is the cost analysis realistic?**
Conservative. Real FTE cost is $250k (we used $200k). All assumptions documented with 16 cited sources. **[Audit the math →](docs/COST_ANALYSIS.md)**

**Q: What about K8s-only environments?**
GitHub can work BUT you're still missing rollback and verification. And you're one platform mandate away from needing Harness anyway. **[See K8s analysis →](HETEROGENEOUS_REALITY.md)**

---

## The Bottom Line

**For homogeneous K8s shops** (< 200 services):
GitHub might work with custom engineering (~$2M over 5 years)
**But**: Still missing rollback, verification, orchestration

**For heterogeneous enterprises** (1000+ services):
GitHub costs MORE ($6.5M vs $6.0M) with LESS capability
**Harness**: $420k cheaper + rollback + verification + orchestration

**Stop building what Harness already has.**

---

## All Documentation

| Doc | Purpose | Time | For |
|-----|---------|------|-----|
| **[DEMO.md](docs/DEMO.md)** | Hands-on walkthrough | 20 min | Engineers |
| **[EXECUTIVE_SUMMARY.md](docs/EXECUTIVE_SUMMARY.md)** | Business case | 5 min | Leadership |
| **[COST_ANALYSIS.md](docs/COST_ANALYSIS.md)** | Detailed costs | 25 min | Finance |
| **[SECURITY_ENFORCEMENT.md](docs/SECURITY_ENFORCEMENT.md)** | Bypass analysis | 15 min | Security |
| **[HETEROGENEOUS_REALITY.md](HETEROGENEOUS_REALITY.md)** | Multi-platform | 10 min | Architects |

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
- Harness is $420k cheaper
- Harness requires 2.5 fewer FTE
- Harness has rollback (< 1 min vs 5-15 min)
- Harness has verification (catches bad deploys)
- Harness has orchestration (multi-service dependencies)
- Harness has zero custom code (vs 2,500+ lines)

**Use the right tool for the job:**
- ✅ GitHub Actions for CI
- ✅ Harness CD for deployments

**[See the proof →](docs/DEMO.md)** | **[See the math →](docs/COST_ANALYSIS.md)** | **[See security analysis →](docs/SECURITY_ENFORCEMENT.md)**
