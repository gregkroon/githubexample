# Step-by-Step Demo: GitHub vs Harness

**Follow these steps** to see exactly what works and what doesn't at enterprise scale.

**Time**: 35 minutes
**Skill level**: Anyone can do this

**What you'll try**:
- ✅ GitHub Environments with approval gates
- ✅ Environment-specific secrets (dev vs prod)
- ✅ Full CI/CD pipeline (build, scan, sign, deploy)
- ❌ What breaks when you scale to 1000 services

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

**CI Pipeline (8 min)**:
```
✅ Test (runs unit tests)
✅ Build (creates Docker image, pushes to GHCR)
✅ Security Scan (Trivy + Grype vulnerability scanning)
✅ SBOM (creates software bill of materials)
✅ Sign (signs image with Cosign + keyless signing)
✅ Policy Check (validates Dockerfile and K8s manifests)
```

**CD Pipeline (4 min)**:
```
✅ Deploy to Dev (automatic)
   ├─ Creates ConfigMap (LOG_LEVEL=debug, FEATURE_FLAGS)
   ├─ Creates Secrets (DATABASE_URL, API_KEY)
   ├─ Deploys to Kubernetes (Kind cluster)
   └─ Runs smoke tests
✅ Deploy to Production (automatic for now)
   ├─ Creates ConfigMap (LOG_LEVEL=info, FEATURE_FLAGS)
   ├─ Creates Secrets (DATABASE_URL, API_KEY)
   ├─ Deploys to Kubernetes (Kind cluster)
   └─ Runs smoke tests
```

**Total time**: 12 minutes from push to production

**Conclusion**: ✅ **GitHub CAN do enterprise CI/CD with environments!**

---

## Step 2: Fork and Run Your Own (15 min)

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
- ✅ Deploys to **Dev** environment automatically
- ✅ Deploys to **Production** environment automatically (for now)

**Time**: 8-10 minutes waiting for pipeline

**Conclusion**: ✅ **It actually works!**

---

### Step 2a: Set Up Deployment Approval Gates (5 min)

**The CD workflow deploys to Dev then Production. Let's add an approval gate.**

**Do this**:
1. Go to your fork: `https://github.com/YOUR-USERNAME/githubexperiment/settings/environments`
2. Click **New environment**
3. Name: `production` (must match exactly)
4. Click **Configure environment**
5. Under **Deployment protection rules**:
   - ✅ Check **Required reviewers**
   - Add yourself as a reviewer
   - Require at least **1** approval
6. Click **Save protection rules**

**Optional - Add environment secrets**:
1. Still in the `production` environment settings
2. Click **Add environment secret**
3. Add these:
   - Name: `DATABASE_URL`, Value: `postgresql://prod-db.internal:5432/users_production`
   - Name: `API_KEY`, Value: `prod-api-key-YOUR-SECRET-HERE`
4. Repeat for `dev` environment:
   - `DATABASE_URL`: `postgresql://dev-db:5432/users_dev`
   - `API_KEY`: `dev-api-key-12345`

**Test the approval gate**:
```bash
# Make another change
echo "// Test approval" >> services/user-service/src/index.js
git add . && git commit -m "test approval gate" && git push origin main

# Watch the workflow in Actions tab:
# - CI runs ✅
# - Dev deploys automatically ✅
# - Production shows "Waiting for approval" ⏸️
# - You get a notification
# - Click "Review deployments" → Approve
# - Production deploys ✅
```

**What you'll see**:
```
CI Pipeline (8 min)
    ↓
Deploy to Dev (automatic, 2 min)
    ↓
⏸️  Waiting for approval...
    ↓ (you click Approve)
Deploy to Production (2 min)
```

**Conclusion**: ✅ **GitHub has basic approval gates!**

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

### Problem 2: 3,000 Environment Configs + Secrets

**Look at**: Repository Settings → Environments (in GitHub UI)

**The problem**:
- Each service needs environments (dev, staging, production)
- Each environment needs:
  - Approval team configuration
  - Secrets configuration (DATABASE_URL, API_KEY, AWS credentials)
  - Protection rules
  - Environment variables
- 1000 services × 3 environments = **3,000 configurations**

**Do this**: Create an environment with secrets (you did this in Step 2a)
1. Go to Settings → Environments → New environment
2. Name it "staging"
3. Add required reviewers (click, search, select)
4. Add secrets ONE BY ONE:
   - Click "Add environment secret"
   - Name: `DATABASE_URL`
   - Value: `postgresql://staging-db.internal:5432/users_staging`
   - Click "Add secret"
   - Repeat for `API_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, etc.
5. Repeat for EACH environment
6. Repeat for EACH service

**Reality check**:
- 5 secrets per environment
- 3 environments per service
- 1000 services
- = **15,000 secrets to configure manually via UI**

**Time per service**:
- Create 3 environments: 5 min
- Add approvers to each: 5 min
- Add 5 secrets × 3 environments: 10 min
- Total: **20 minutes per service**

**Time for 1000 services**: 20 min × 1000 = **333 hours (8 work weeks)**

**What happens when**:
- You rotate a database password? Update 1000 secrets manually
- You add a new environment? Configure 1000 repositories
- A team member leaves? Update approvers in 3000 environments

**Conclusion**: ❌ **Manual configuration hell + zero automation**

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
| Environment configs | 3,000 manual UI | 1 centralized YAML |
| Environment secrets | 15,000 manual UI | Centralized + external (Vault) |
| Approval gates | ✅ Manual reviewers | ✅ Manual + policy-based |
| Secret rotation | ❌ Update 1000 repos | ✅ One command |

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
- **Approval gates work** (manual reviewers per environment)
- **Environment-specific secrets** (isolated per env)

### ❌ What Breaks at Scale (1000+ Repos)
1. **1,000 workflow files** to maintain
2. **3,000 environment configs** (manual UI, no centralization)
3. **15,000 secrets** to configure individually via UI
4. **Developers control workflows** (can bypass security)
5. **Parallel execution** (cannot enforce "security before deploy")
6. **No rollback button** (manual process)
7. **No deployment verification** (must build yourself)
8. **No secret rotation automation** (update 1000 repos manually)
9. **No policy-based approvals** (can't block based on metrics)
10. **Must build 6 custom services** (17 weeks)

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

1. **Test the approval gate**:
   - Make a small change to user-service
   - Push and watch workflow pause at production
   - Experience the approval flow
   - See the deployment proceed after approval

2. **Configure environment secrets**:
   - Go to Settings → Environments → production
   - Add 5 different secrets (DATABASE_URL, API_KEY, etc.)
   - Time yourself: how long did it take?
   - Now imagine doing this for 1000 services

3. **Add a feature**: Edit `services/user-service/src/index.js`
   - Add a new endpoint
   - Push and watch the pipeline
   - Experience the 8-10 minute wait

4. **Break security**: Edit `.github/workflows/ci-user-service.yml`
   - Add `continue-on-error: true` to security job
   - See how easy it is to bypass

5. **Onboard a service**: Copy workflows to a new service
   - Copy CI and CD workflows
   - Create 3 environments (dev, staging, prod)
   - Add 5 secrets to each environment
   - Add approval teams
   - See how repetitive it is
   - Multiply by 1000

6. **Try to rollback**: Break something and deploy
   - Realize there's no button
   - Experience the manual process

7. **Rotate a secret**:
   - Change DATABASE_URL in production environment
   - Now imagine doing this across 1000 repositories
   - No automation, no CLI, just clicking

---

## The Bottom Line

**You can build it with GitHub.**

**But you'll spend $1.9M more to make it work at scale.**

**Use the right tool for the job.**

---

**[← Back to README](../README.md)** | **[Read Executive Summary](EXECUTIVE_SUMMARY.md)**
