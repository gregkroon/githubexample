# GitHub Actions vs Harness CD: The Enterprise Reality

**Can GitHub Actions replace a purpose-built CD platform?**

**No. GitHub costs MORE ($9M vs $5.5M) and delivers FAR LESS.**

---

## The Verdict

| | GitHub Actions | Harness CD |
|---|---|---|
| **5-Year Cost** | $9.0M | $5.5M |
| **Team Size** | 6.4 people firefighting | 2 people building features |
| **Custom Code** | 202,500 lines to maintain | 0 lines |
| **Rollback Time** | 5-15 minutes (redeploy everything) | < 1 minute (one click) |
| **Bad Deploy Detection** | None - hope for the best | Automatic with ML |
| **Supply Chain Risk** | 15,000 external dependencies | Zero marketplace exposure |

**Result**: Harness saves $3.5M (39%) with 10× better capabilities.

---

## The Core Problem

### GitHub Actions Is Built for CI, Not CD

**What it's good at**:
- ✅ Building code
- ✅ Running tests
- ✅ Security scanning

**What it fails at**:
- ❌ **Deployment state tracking** - Doesn't remember what's deployed where
- ❌ **Coordinated rollback** - Can't undo multi-service deployments
- ❌ **Deployment verification** - Can't detect when deployments go bad
- ❌ **Multi-platform support** - Must write custom scripts for every deployment target

### Real-World Impact: The 30-Minute Disaster

**Scenario**: Deploy breaks production at 5:30pm Friday

**With GitHub Actions**:
1. Discover deployment is broken (5-10 min)
2. Find what went wrong (5-10 min)
3. Revert code and redeploy EVERYTHING (10-15 min)
4. **Total: 30+ minutes of downtime**
5. **Cost**: $2.5M revenue loss (at $5M/hour)

**With Harness**:
1. Platform detects anomaly automatically
2. One-click rollback to previous version
3. **Total: < 1 minute**
4. **Cost**: $83k revenue loss

**Savings per incident**: $2.4M

---

## What You Must Build (If You Choose GitHub)

To make GitHub Actions work like a real CD platform, you must custom-build:

| What You Need | Build Time | Ongoing Work | Why You Need It |
|---------------|------------|--------------|-----------------|
| **Rollback System** | 8 weeks | 8 hrs/week | GitHub has no rollback - must rebuild from scratch |
| **State Tracker** | 8 weeks | 8 hrs/week | Track what's deployed where (GitHub forgets) |
| **Health Checks** | 6 weeks | 6 hrs/week | Detect bad deployments (GitHub is blind) |
| **Multi-Service Coordinator** | 12 weeks | 10 hrs/week | Deploy services in correct order |
| **Database Manager** | 4 weeks | 4 hrs/week | Coordinate DB + app deployments |
| **Release Calendar** | 10 weeks | 8 hrs/week | Prevent Friday 5pm disasters |
| **Supply Chain Security** | 6 weeks | Full-time | Review 15,000 dependency updates |

**Total**: 54 weeks + 6.4 people = **You're building Harness from scratch**

---

## The Security Problem

### GitHub's Marketplace Risk

**The Vulnerability**:
- Your workflows use 15,000 external marketplace actions
- These dependencies have mutable tags (can be force-pushed)
- **Aqua Trivy breach (2024)**: Attacker pushed credential stealer to trusted tag
- Your CI runners have ALL your production credentials (AWS, Kubernetes, databases)

**The Risk**:
- One compromised action = AWS keys stolen
- One compromised action = Database access
- One compromised action = $50M+ breach

**Harness Approach**:
- Internal template library only (50 templates, not 15,000 marketplace actions)
- Security team vets every template
- Zero external marketplace exposure

---

## The Cost Reality

### GitHub Actions (5 Years)
```
Platform team:     $6.4M  (6.4 people × 5 years)
Custom code:       $1.1M  (Building all the features)
Licenses:          $0.25M (GitHub Enterprise)
Security reviews:  $0.28M (Reviewing dependencies)
Hidden costs:      $1.0M  (Incidents, compliance, firefighting)
─────────────────────────
TOTAL:            $9.03M
```

### Harness CD (5 Years)
```
Platform team:     $2.0M  (2 people × 5 years)
Harness licenses:  $3.0M  (Enterprise platform)
Setup:             $0.3M  (Year 1 only)
GitHub (CI only):  $0.25M (Keep for build/test)
─────────────────────────
TOTAL:            $5.53M
```

**Harness saves $3.5M (39%) with far better capabilities.**

---

## When to Use What

### ✅ Use GitHub Actions (CI + CD) If:
- < 50 services
- 100% Kubernetes only
- Can accept 30-minute rollback time
- Have unlimited engineering time
- Can accept production outages

**Risk**: First multi-cloud mandate = rebuild everything

---

### ✅ Use Harness CD If:
- 200+ services
- Any mix of Kubernetes, VMs, Lambda, databases, on-prem
- Need < 1 minute rollback
- Need automatic failure detection
- Limited platform engineering capacity
- Can't accept Friday 5pm disasters

**Benefit**: $3.5M cheaper + 10× more capable

---

## Live Proof

**This repository has working CI/CD pipelines**:

```bash
# Fork and watch them run
gh repo fork gregkroon/githubexperiment
cd githubexperiment
echo "test" >> README.md && git commit -am "trigger" && git push
gh run watch
```

**Then try**:
1. Break a deployment and try to roll back (you can't)
2. Try to see deployment history (it's not tracked)
3. Try to coordinate a multi-service deploy (requires custom code)

**[See detailed walkthrough →](docs/DEMO.md)**

---

## The Honest Conclusion

**For most enterprises**:

**GitHub Actions** = $9M + 6 people firefighting + 202,500 lines of custom code + no rollback

**Harness** = $5.5M + 2 people managing + zero custom code + instant rollback

**Use the right tool**:
- ✅ GitHub Actions for CI (build, test, scan)
- ✅ Harness CD for deployment (rollout, verify, rollback)

One production outage pays for 3 years of Harness.

**[See technical proof →](docs/DEMO.md)**

---

## Quick Facts

- **$3.5M saved** over 5 years with Harness
- **4.4 fewer people** needed
- **25× faster** incident recovery (< 1 min vs 30 min)
- **Zero** custom deployment code vs 202,500 lines
- **Zero** marketplace security risk vs 15,000 dependencies

---

## Documentation

| File | What It Shows | Time |
|------|---------------|------|
| **README.md** | Business case, cost comparison | 5 min |
| **[DEMO.md](docs/DEMO.md)** | Technical proof, live failures | 15 min |

---

## License

MIT - Use this to make informed decisions for your organization
