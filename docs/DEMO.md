# Step-by-Step Demo: GitHub vs Harness

**Follow these steps** to see exactly what works and what doesn't at enterprise scale.

**Time**: 30 minutes
**Skill level**: Anyone can do this

---

## The Question

**Your company has 1000 microservices. Can you build enterprise CI/CD with GitHub?**

Let's find out by actually trying it.

---

## Step 1: Watch It Run (5 min)

**Do this**:
1. Go to: https://github.com/gregkroon/githubexample/actions
2. Click on any recent workflow run
3. Expand the jobs to see what happens

**What you'll see**:
```
✅ Test (runs unit tests)
✅ Build (creates Docker image)
✅ Security Scan (checks for vulnerabilities)
✅ SBOM (creates software bill of materials)
✅ Sign (signs image with Cosign)
✅ Policy Check (validates security policies)
✅ Deploy (deploys to Kubernetes)
✅ Smoke Tests (verifies endpoints work)
```

**Takes**: 8-10 minutes from push to deployed

**Conclusion**: ✅ **GitHub CAN do enterprise CI/CD**

---

## Step 2: Fork and Run Your Own (10 min)

**Do this**:
```bash
# 1. Fork the repository (click Fork button on GitHub)

# 2. Clone your fork
git clone https://github.com/YOUR-USERNAME/githubexperiment
cd githubexperiment

# 3. Make a tiny change
echo "// Test" >> services/user-service/src/index.js

# 4. Push it
git add .
git commit -m "test: trigger pipeline"
git push origin main

# 5. Watch it run
# Go to: https://github.com/YOUR-USERNAME/githubexperiment/actions
# Click "CI - User Service" workflow
# Watch each job execute
```

**What you'll experience**:
- ✅ Everything runs automatically
- ✅ Security scanning works
- ✅ Image gets signed
- ✅ Deploys to Kubernetes (Kind cluster)

**Time**: 8-10 minutes waiting for pipeline

**Conclusion**: ✅ **It actually works!**

---

## Step 3: See What Breaks at Scale (5 min)

**Now imagine you have 1000 services like this.**

### Problem 1: 1000 Workflow Files

**Look at**: `.github/workflows/ci-user-service.yml`

**The problem**:
- This file is 180 lines long
- You need one for EACH service
- 1000 services = 1000 workflow files
- Update something? Change 1000 files

**Do this**:
```bash
# Count the workflow files
ls -1 .github/workflows/ | wc -l
# Output: 6 (3 services × 2 workflows each)

# Imagine this × 333
# = 2,000 workflow files to manage
```

**Conclusion**: ❌ **Configuration sprawl**

---

### Problem 2: 3,000 Environment Configs

**Look at**: Repository Settings → Environments (in GitHub UI)

**The problem**:
- Each service needs environments (staging, production)
- Each environment needs:
  - Approval team configuration
  - Secrets configuration (AWS, database, etc.)
  - Protection rules
- 1000 services × 3 environments = **3,000 configurations**

**Do this**: Try to create an environment in GitHub UI
1. Go to Settings → Environments
2. Click "New environment"
3. Name it "staging"
4. Add required reviewers
5. Add secrets

**Time**: 15 minutes per service × 1000 services = **250 hours**

**Conclusion**: ❌ **Manual configuration hell**

---

### Problem 3: Developers Can Edit Workflows

**Look at**: `.github/workflows/ci-user-service.yml` (lines 45-50)

**The problem**: This file lives IN the developer's repo.

**Developers can**:
```yaml
# Option 1: Comment out security
# jobs:
#   security-scan:
#     ...

# Option 2: Make it never fail
jobs:
  security-scan:
    continue-on-error: true  # ← Security never blocks

# Option 3: Skip conditionally
jobs:
  security-scan:
    if: "!contains(github.event.head_commit.message, 'skip')"
```

**Try it yourself**:
```bash
# Edit the workflow
code .github/workflows/ci-user-service.yml

# Add this to security-scan job:
#   continue-on-error: true

# Push it
git add .
git commit -m "bypass security"
git push origin main

# Watch: Security scan finds vulnerabilities but doesn't block deployment
```

**Conclusion**: ❌ **Developers control security**

---

### Problem 4: The Critical Gap (Parallel Execution)

**This is the big one.**

**Look at**: Two workflow files
- `platform/.github/workflows/required-security-scan.yml` (platform team)
- `.github/workflows/ci-user-service.yml` (developer)

**What happens**:
```
t=0:   You push code to main

t=0:   Required Workflow starts
       ├─ Platform team's security scan
       └─ Scans source code with Trivy

t=0:   Developer Workflow starts
       ├─ Build Docker image
       ├─ Push to registry
       └─ Deploy to Kubernetes

t=3m:  Developer workflow finishes ✅
       └─ Your code is IN PRODUCTION

t=5m:  Required workflow finishes ❌
       └─ Found critical CVE in dependency
       └─ Too late - already deployed!
```

**Try it yourself**:
```bash
# Push a change
echo "// Trigger both workflows" >> services/user-service/src/index.js
git add . && git commit -m "test parallel execution" && git push origin main

# Watch both workflows in Actions tab:
# - Required Security Scan
# - CI - User Service
# Both start at the same time!
```

**The problem**: No way to make developer workflow wait for required workflow.

**Why**: GitHub Actions has no cross-workflow dependencies.

**Conclusion**: ❌ **Cannot enforce "deploy ONLY IF security passes"**

---

### Problem 5: No Rollback Button

**Scenario**: You deployed a bug. Production is down.

**With GitHub, you must**:
```bash
# Option 1: Revert and redeploy (slow)
git revert HEAD
git push origin main
# Wait 8-10 minutes for full pipeline...

# Option 2: Manual kubectl (risky)
kubectl rollout undo deployment/user-service
# No audit trail, manual, error-prone
```

**Try it yourself**:
```bash
# Introduce a bug
sed -i '' 's/3000/9999/' services/user-service/src/index.js
git add . && git commit -m "break it" && git push origin main
# Wait for deployment...

# Now try to rollback
# (You'll realize there's no button)
```

**Time to rollback**: 5-15 minutes

**Conclusion**: ❌ **No one-click rollback**

---

### Problem 6: No Deployment Verification

**Look at**: `.github/workflows/cd-user-service.yml` (lines 60-65)

**What we check after deployment**:
```yaml
- name: Smoke tests
  run: |
    curl -f http://localhost:3000/health
    curl -f http://localhost:3000/api/users
```

**What we DON'T check**:
- Error rate (is it higher than normal?)
- Response time (is it slower than baseline?)
- CPU usage (is it spiking?)
- Memory usage (is it leaking?)

**What SHOULD happen**:
1. Deploy to 10% of traffic
2. Monitor error rate for 15 minutes
3. If error rate > 5% → automatic rollback
4. If healthy → continue to 50%, then 100%

**With GitHub**: You must build this yourself (4 weeks of engineering)

**Conclusion**: ❌ **Must build deployment verification**

---

## Step 4: See the GitHub Enterprise "Solutions" (5 min)

**GitHub Enterprise has features to help. Do they work?**

### Solution 1: CODEOWNERS

**Look at**: `.github/CODEOWNERS`

```bash
# Platform team must approve workflow changes
/.github/workflows/ @platform-team @security-team
```

**What this provides**:
- Platform team reviews workflow changes
- Blocks obvious bypasses

**What this DOESN'T solve**:
- At 1000 repos: 10-20 PRs/day to review
- Reviewers miss subtle bypasses
- Manual review doesn't scale

**Try it**: Create a PR that changes a workflow
- Platform team must approve
- But if reviewer approves `continue-on-error: true`, security is bypassed

**Conclusion**: ⚠️ **Helps, but doesn't scale**

---

### Solution 2: Required Workflows

**Look at**: `platform/.github/workflows/required-security-scan.yml`

This runs on ALL 1000 repos automatically.

**What this provides**:
- Org-wide security scanning
- Developers cannot disable
- Runs automatically

**What this DOESN'T solve**:
- Runs in PARALLEL (see Problem 4 above)
- Scans source code, NOT Docker images
- Cannot block deployment

**Conclusion**: ⚠️ **Better, but architectural limitation remains**

---

### Solution 3: Organization Rulesets

**Look at**: `platform/rulesets/organization-production-ruleset.json`

Centralized policies across all repos.

**What this provides**:
- Requires 2 approvals
- Requires code owner review
- Enforces required status checks

**What this DOESN'T solve**:
- Pre-merge checks only (not deployment-time)
- Cannot prevent parallel execution
- Cannot enforce "deploy ONLY IF security passes"

**Conclusion**: ⚠️ **Good for code review, not for deployment governance**

---

## Step 5: Compare to Harness (5 min)

**The key difference**: Templates live OUTSIDE developer repos.

### Harness Template (Platform Team Controls)

```yaml
# Lives in platform repo - developers CANNOT edit
template:
  name: Production Deployment
  stages:
    - stage:
        name: Security
        locked: true  # ← Developers CANNOT modify
        spec:
          imageScan:
            tool: Trivy
            scanImage: true  # ← Scans Docker image (not just source)
            failOnCVE: true
            waitForResults: true  # ← BLOCKS next stage

    - stage:
        name: Deploy
        dependsOn: [Security]  # ← WAITS for Security to pass
        locked: true
        spec:
          verification:
            errorRate: < 5%  # ← Automatic verification
            duration: 15min
          rollback:
            automatic: true  # ← One-click rollback
```

### Developer's Reference

```yaml
# Developer repo - just references template
pipeline:
  template: Production Deployment  # ← Cannot modify
  variables:
    service: user-service
```

**Key differences**:

| Problem | GitHub | Harness |
|---------|--------|---------|
| Workflow files | 1000 files | 0 files |
| Developers can bypass | Yes | No (locked templates) |
| Sequential enforcement | No | Yes (stages wait) |
| Scans Docker images | No | Yes |
| Deployment verification | Must build | Built-in |
| Rollback | Manual | One-click |
| Environment configs | 3,000 | 1 centralized |

**Conclusion**: ✅ **Harness solves governance architecturally**

---

## Step 6: The Cost Reality Check (5 min)

### What It Takes (GitHub-Native at 1000 Repos)

**Custom services you must build**:
1. Deployment gate service (metrics verification) - 4 weeks
2. DORA metrics collector - 3 weeks
3. Policy validation service - 3 weeks
4. Multi-service orchestrator - 6 weeks

**Total**: 17 weeks of engineering

**Operational burden**:
- 2-4 platform engineers full-time
- 16-24 hours/week handling failures and drift
- 24 tools that must work together

**5-Year Total Cost**:
```
GitHub Enterprise: $400k/year × 5 = $2,000k
Custom services: $200k build + $400k maintenance = $600k
Platform engineers (2-4 FTE): $600k/year × 5 = $3,000k
────────────────────────────────────────────────────
Total: $5,600,000
```

### Hybrid Approach (GitHub CI + Harness CD)

**What you get**:
- GitHub Actions for CI (excellent)
- Harness for CD (purpose-built)
- Locked templates (developers can't bypass)
- Sequential enforcement (security before deploy)
- One-click rollback
- Built-in verification
- Centralized configuration

**5-Year Total Cost**:
```
GitHub Team (CI only): $92k/year × 5 = $460k
Harness CD: $400k/year × 5 = $2,000k
Platform engineers (0.5-1 FTE): $250k/year × 5 = $1,250k
────────────────────────────────────────────────────
Total: $3,710,000

💰 Savings: $1,890,000 (34%)
```

**Conclusion**: ✅ **Lower cost, better governance**

---

## What You Just Learned

### ✅ What Works (GitHub)
- CI/CD automation is excellent
- Security scanning is comprehensive
- Integration with GitHub ecosystem
- Good developer experience
- Reusable workflows help

### ❌ What Breaks at Scale (1000+ Repos)
1. **1,000 workflow files** to maintain
2. **3,000 environment configs** (no centralization)
3. **Developers control workflows** (can bypass security)
4. **Parallel execution** (cannot enforce "security before deploy")
5. **No rollback button** (manual process)
6. **No deployment verification** (must build yourself)
7. **Must build 6 custom services** (17 weeks)

### 💡 The Key Insight

**GitHub CAN do enterprise CI/CD.**

**But at 1000+ repos:**
- Building workarounds costs MORE than using a purpose-built platform
- Operational burden requires 2-4 FTE vs 0.5-1 FTE
- $1.9M more expensive over 5 years

**The gap is operational efficiency, not functionality.**

---

## Recommendations

### For < 50 Repos
✅ **GitHub-native works** - Operational burden is manageable

### For 50-500 Repos
⚠️ **Depends on your resources** - Can you afford 2-4 FTE?

### For 1000+ Repos
✅ **Hybrid recommended**:
- **CI**: GitHub Actions (keep it)
- **CD**: Harness (purpose-built for scale)

**Why**: Lower cost, less toil, better governance

---

## Try It Yourself

**Now that you understand the gaps, try**:

1. **Add a feature**: Edit `services/user-service/src/index.js`
   - Add a new endpoint
   - Push and watch the pipeline
   - Experience the 8-10 minute wait

2. **Break security**: Edit `.github/workflows/ci-user-service.yml`
   - Add `continue-on-error: true` to security job
   - See how easy it is to bypass

3. **Onboard a service**: Copy workflows to a new service
   - See how repetitive it is
   - Multiply by 1000

4. **Try to rollback**: Break something and deploy
   - Realize there's no button
   - Experience the manual process

---

## The Bottom Line

**You can build it with GitHub.**

**But you'll spend $1.9M more to make it work at scale.**

**Use the right tool for the job.**

---

**[← Back to README](../README.md)** | **[Read Executive Summary](EXECUTIVE_SUMMARY.md)**
