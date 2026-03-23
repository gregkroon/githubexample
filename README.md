# GitHub Actions vs Harness CD: The Frankenstein Architecture

**The brutal truth about scaling GitHub Actions for enterprise Continuous Delivery**

---

## The Verdict

GitHub Actions is excellent for CI. Using it for enterprise CD creates an expensive, fragmented Frankenstein architecture.

| What You're Choosing | GitHub Actions CD | Harness CD |
|----------------------|-------------------|------------|
| **Architecture** | GHA + Terraform + ArgoCD + Bash + Glue Code | Single Control Plane |
| **5-Year Cost** | $8.9M | $5.6M |
| **Platform Team** | 6 engineers (80% maintaining glue) | 2 engineers (10% configuring) |
| **Incident Recovery** | 30-40 min manual coordination | < 2 min automatic rollback |
| **Governance** | 3,000 workflow files (config drift) | 1 centralized policy |

**Result**: Harness saves **$3.3M (37%)** and frees **4 engineers** to build features.

**[See detailed financial analysis →](docs/EXECUTIVE_SUMMARY.md)**

---

## The 5 Critical Shortcomings

These aren't theoretical gaps. **[DEMO.md](docs/DEMO.md)** shows you exactly how they fail in real deployments.

### 1. Stateless Runners (No Deployment Memory)

**The Problem**:
```yaml
# GitHub Actions workflow
jobs:
  deploy:
    runs-on: ubuntu-latest  # ← Ephemeral VM
    steps:
      - run: kubectl apply -f k8s/deployment.yaml
      # ✅ Deployment succeeds
      # ❌ Runner destroyed immediately
      # ❌ No record of what was deployed
      # ❌ No rollback capability
```

**What happens after**:
- Runner VM is destroyed
- No persistent state
- Can't answer: "What version is in production?"

**The Frankenstein solution**:
- Add ArgoCD (Kubernetes state only)
- Build custom state tracker service
- Integrate with Datadog/New Relic for deployment markers
- **You're maintaining 3 systems for basic "what's deployed where?" visibility**

**[See it fail in DEMO →](docs/DEMO.md#problem-1-the-stateless-runner-problem)**

---

### 2. No Coordinated Rollback (Multi-Service Chaos)

**The Problem**:

Real-world deployment: Database → API → Frontend

```yaml
# 3 separate workflows, no coordination

# Workflow 1: database migration ✅ SUCCESS
# Workflow 2: backend API ✅ SUCCESS
# Workflow 3: frontend ❌ FAILS

# Current state:
# ✅ Database has new schema
# ✅ API expects new schema
# ❌ Frontend missing
# 💥 Production broken
```

**Manual rollback**:
1. Notice failure (5 min)
2. Coordinate across 3 repos (10 min)
3. Revert backend (6 min CI/CD)
4. Revert database (risk data loss)
5. Verify everything (5 min)
6. **Total: 20-30 minutes**

**Impact**: $2.5M revenue loss per incident *(at $5M/hour)*

**[See it fail in DEMO →](docs/DEMO.md#problem-2-the-rollback-coordination-nightmare)**

---

### 3. Configuration Sprawl (3,000 Workflow Files)

**The Problem**:
- 1,000 microservices
- 3 environments each
- **= 3,000 workflow files to govern**

**Policy enforcement**:
```yaml
# You WANT this enforced everywhere:
- Production requires manual approval
- Block deployments: Fri 4pm - Mon 8am
- Wait 1 hour in staging
- Block if P1 incidents active

# Reality:
# ❌ Must implement in 3,000 separate files
# ❌ Teams copy-paste different versions
# ❌ Configuration drift over time
# ❌ Compliance audits = 40-80 hours
```

**Harness**: 1 centralized policy file, automatic enforcement

**[See it fail in DEMO →](docs/DEMO.md#problem-3-the-governance-nightmare)**

---

### 4. Platform Team Burden (80% Firefighting)

**Where the time goes**:

| Activity | Hours/Week | What It Costs |
|----------|------------|---------------|
| Debug ArgoCD sync failures | 4 hrs | $120k/year |
| Fix Terraform state drift | 4 hrs | $120k/year |
| Coordinate multi-service rollbacks | 6 hrs | $180k/year |
| Investigate "what's deployed where?" | 4 hrs | $120k/year |
| Standardize across 1,000 repos | 5 hrs | $144k/year |
| **TOTAL: Glue Code Maintenance** | **36 hrs/week** | **$960k/year** |
| Feature development | 4 hrs/week | $240k/year |

**6 engineers spending 80% time maintaining deployment infrastructure instead of building features.**

**With Harness**: 2 engineers, 10% time on platform, 90% on features

**[See it fail in DEMO →](docs/DEMO.md#problem-4-the-platform-team-burden)**

---

### 5. Heterogeneous Infrastructure (Custom Scripts Everywhere)

**Your actual infrastructure**:
```
1000 services:
  ├─ 300 Kubernetes pods (30%)
  ├─ 200 AWS Lambda (20%)
  ├─ 180 ECS containers (18%)
  ├─ 150 EC2 VMs (15%)
  ├─ 100 RDS databases (10%)
  └─ 50 on-premise VMs (5%)
```

**GitHub Actions approach**:
- Custom kubectl scripts for K8s (~100 lines × 300 services)
- Custom AWS CLI for Lambda (~100 lines × 200 services)
- Custom bash for VMs (~200 lines × 150 services)
- Custom Flyway for databases (~130 lines × 100 services)
- **= 118,000 lines of deployment code to maintain**

**Every platform change**:
- Kubernetes upgrades kubectl → update 300 workflows
- AWS deprecates runtime → update 200 workflows
- Migration to new platform → rewrite workflows

**Harness**: Native integrations for all platforms, 0 custom code

**[See it fail in DEMO →](docs/DEMO.md#problem-5-the-heterogeneous-infrastructure-reality)**

---

## The Frankenstein Architecture

When you choose GitHub Actions for CD at scale, you don't just use GHA. You build:

```
┌─────────────────────────────────────────────────┐
│  GitHub Actions (stateless runners)             │
│  ├─ Build, test, scan ✅                        │
│  └─ Deploy? ❌ No state, rollback, verification │
└─────────────────────────────────────────────────┘
                    ↓
         "We need CD capabilities"
                    ↓
┌─────────────────────────────────────────────────┐
│  The Frankenstein Stack                         │
│  ├─ GitHub Actions (build + test)               │
│  ├─ Terraform (infrastructure)                  │
│  ├─ ArgoCD (Kubernetes deployments)             │
│  ├─ Custom state tracker                        │
│  ├─ Custom rollback coordinator                 │
│  ├─ Custom health checks                        │
│  ├─ Custom policy enforcer                      │
│  └─ Custom multi-service orchestrator           │
└─────────────────────────────────────────────────┘

= 6 engineers maintaining glue code full-time
```

**This is what "GitHub Actions CD" actually means at enterprise scale.**

**[See detailed financial analysis →](docs/EXECUTIVE_SUMMARY.md)**

---

## FAQ: The Engineer's Reality Check

### "We use GitHub Reusable Workflows. We don't maintain 3,000 separate files."

**Reality**: Reusable workflows solve **templating**, not **state**.

You're still writing custom verification scripts:
```yaml
- name: Verify deployment
  run: |
    # ❌ Still custom code, just centralized
    ERROR_RATE=$(curl -H "DD-API-KEY: ${{ secrets.DD }}" ...)
    if [ "$ERROR_RATE" -gt "5" ]; then exit 1; fi
```

Harness has ML-based verification built-in. You're centralizing custom code, not eliminating it.

---

### "ArgoCD + GitHub Actions is the CNCF GitOps standard."

**Reality**: Perfect for **100% Kubernetes**. But you're not 100% Kubernetes.

You have:
- 30% Kubernetes (ArgoCD handles)
- 70% Lambda + ECS + VMs + databases (custom scripts)

**You're back to the Frankenstein architecture.**

---

### "A git revert is instant. Harness can't make Kubernetes roll back faster."

**Reality**: The 30-minute delay isn't **execution**, it's **human detection time**.

Manual process:
1. Error appears (2 min)
2. Alert fires (5 min)
3. Engineer investigates (10 min)
4. Engineer decides to rollback (3 min)
5. git revert + CI/CD runs (15 min)
6. **Total: 35 minutes**

Harness ML:
1. Error appears (2 min)
2. ML detects anomaly (1 min)
3. Auto-rollback (3 min)
4. **Total: 6 minutes**

**Saves $2.3M per incident** (at $5M/hour revenue)

---

### "Harness Delegates are complex to manage."

**Reality**: One-time setup, then auto-upgrade.

Would you rather:
- **Option A**: 2 weeks deploying Delegates via Helm (one-time)
- **Option B**: 5 years debugging custom AWS parsing scripts

Choose wisely.

---

### "We don't want vendor lock-in."

**Reality**: You're already locked in.

You've built:
- Custom state tracker
- Custom rollback coordinator
- Custom health checks
- 118,000 lines of deployment code

**You're locked into your own technical debt.**

Migration cost:
- Off GitHub: Rewrite custom services + retrain team + migrate 3,000 workflows
- Off Harness: Update pipeline YAML

**Lock-in to vendor platform > lock-in to unmaintainable custom code**

---

## When to Use What

### ✅ Use GitHub Actions for CI + CD If:

- **< 50 services** (Frankenstein hasn't metastasized)
- **100% Kubernetes on single cluster** (ArgoCD works)
- **< 5 rollbacks/year** (manual recovery tolerable)
- **Platform team has unlimited capacity** (glue maintenance is free)
- **No compliance requirements** (audits optional)

**Risk**: First multi-cloud mandate = rebuild everything

---

### ✅ Use Harness CD If:

- **200+ services** (Frankenstein becomes unmaintainable)
- **Heterogeneous infrastructure** (K8s + VMs + Lambda + databases)
- **Need < 2 min rollback** (revenue impact high)
- **Limited platform capacity** (can't afford 6 people on glue)
- **Compliance requirements** (SOC2, PCI-DSS, HIPAA)
- **Multi-team organization** (centralized governance needed)

**Benefit**: $3.3M cheaper + 4 engineers freed

---

## The Honest Conclusion

**GitHub Actions is the best CI platform.** Use it for build, test, scan.

**GitHub Actions is not a CD platform.** Using it for enterprise CD forces you to build a Frankenstein architecture that costs MORE than a purpose-built platform.

**The real cost**: 6 engineers spending 80% time maintaining deployment glue instead of building features.

### The Strategic Question

Do you want your platform team:
- **Maintaining deployment glue code** (GitHub Actions CD)
- **Building developer productivity features** (Harness CD)

**One production outage pays for 1.5 years of Harness.**

---

## Live Proof

This repository has working CI/CD pipelines. Fork it and watch them run:

```bash
gh repo fork gregkroon/githubexperiment
cd githubexperiment
echo "test" >> README.md && git commit -am "trigger" && git push
gh run watch
```

**Then experience the shortcomings**:
1. ❌ Deploy broken code and try to rollback (you'll manually revert + redeploy)
2. ❌ Check deployment history (you'll grep through logs)
3. ❌ Coordinate multi-service deploy (you'll write custom scripts)

**[See detailed technical walkthrough →](docs/DEMO.md)**

---

## Where to Go Next

| Document | What It Shows | Time |
|----------|---------------|------|
| **[EXECUTIVE_SUMMARY.md](docs/EXECUTIVE_SUMMARY.md)** | Complete TCO analysis with math & sources | 10 min |
| **[DEMO.md](docs/DEMO.md)** | Hands-on proof of all 5 shortcomings | 20 min |
| **[EXECUTIVE_EMAIL.md](docs/EXECUTIVE_EMAIL.md)** | Email templates for CTOs/VPs + POC plan | 5 min |

**For financial decision-makers**: Start with EXECUTIVE_SUMMARY.md

**For technical leaders**: Start with DEMO.md

**For sending to executives**: Use EXECUTIVE_EMAIL.md templates

---

## License

MIT - Use this to make informed platform decisions
