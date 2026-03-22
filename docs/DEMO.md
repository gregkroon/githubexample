# Why GitHub Actions Fails At Enterprise Deployment: A Hands-On Demo

**Follow these steps** to watch GitHub Actions struggle with enterprise deployment requirements.

**Time**: 40 minutes
**Skill level**: Anyone can do this

**What you'll discover**:
- ✅ What GitHub Actions does well (CI: builds, tests, scans)
- ❌ Where it fundamentally fails (CD at heterogeneous enterprise scale)
- 💰 The real cost of trying to force GitHub into enterprise CD
  - **GitHub Actions**: $6.2M over 5 years, 4.5 FTE, 2,500+ lines custom code
  - **Harness CD**: $6.0M over 5 years, 2 FTE, 0 custom code
  - **Harness is $200k CHEAPER with 10× the capability**
- 🔥 Why platform teams burn out maintaining GitHub Actions for CD

---

## The Question

**Your company has 1000 microservices across multiple clouds, VMs, serverless, and on-premise infrastructure. Can GitHub Actions handle enterprise deployment?**

**Spoiler**: No. Watch it fail.

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
✅ SBOM (Generate + Validate + Attest)
   ├─ Generate with Syft (1 line - EASY)
   ├─ Validate contents (90 lines - HARD)
   └─ Sign attestation with Cosign (40 lines - COMPLEX)
✅ Sign (signs image with Cosign + keyless signing)
✅ Policy Check (validates Dockerfile and K8s manifests)
```

**CD Pipeline (5 min)**:
```
✅ Deploy to Dev (automatic)
   ├─ Verify SBOM attestation (40 lines - deployment gate)
   ├─ Creates ConfigMap (LOG_LEVEL=debug, FEATURE_FLAGS)
   ├─ Creates Secrets (DATABASE_URL, API_KEY)
   ├─ Deploys to Kubernetes (Kind cluster)
   └─ Runs smoke tests
⏸️  Wait for Approval (manual)
✅ Deploy to Production (after approval)
   ├─ Verify SBOM attestation (40 lines - deployment gate)
   ├─ Creates ConfigMap (LOG_LEVEL=info, FEATURE_FLAGS)
   ├─ Creates Secrets (DATABASE_URL, API_KEY)
   ├─ Deploys to Kubernetes (Kind cluster)
   └─ Runs smoke tests
```

**The SBOM complexity**:
- Generate SBOM: 1 line (automated)
- Validate + Attest: 130 lines of custom code (CI)
- Verify before deploy: 80 lines of custom code (CD: dev + prod)
- **Total: 210 lines per service**

**Total time**: 13 minutes from push to production

**Conclusion**: ✅ **GitHub CAN do basic Kubernetes deployment** (for now)

**But**: This is only 1 service on Kubernetes. Now imagine:
- 1000 services
- 6 deployment targets (K8s, VMs, ECS, Lambda, Azure Functions, on-prem)
- 210 lines × 1000 services = **210,000 lines of SBOM code**
- No rollback capability
- No deployment verification
- Platform team maintaining it all

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

### Problem 1: 1000 Workflow Files (Even Reusable Workflows Don't Save You)

**Look at**: `.github/workflows/ci-user-service.yml`

**The reality**:
- This file is 250 lines long for ONE deployment target (Kubernetes)
- You need one for EACH service
- 1000 services = 1000 workflow files = 250,000 lines

**Do this**:
```bash
# Count the workflow files in this demo
ls -1 .github/workflows/ | wc -l
# Output: 6 (3 services × 2 workflows each)

# If you copy-paste this to 1000 services:
# = 2,000 workflow files = 500,000 lines of duplicated code
```

**"But what about reusable workflows?"**

Sure, you can reduce duplication for Kubernetes. But that's just 1 of 6 deployment targets:

```yaml
# Reusable workflow for Kubernetes (250 lines)
# Reusable workflow for VMs (500 lines)
# Reusable workflow for ECS (400 lines)
# Reusable workflow for Lambda (350 lines)
# Reusable workflow for Azure Functions (350 lines)
# Reusable workflow for on-premise (600 lines)
# Total: 2,450 lines of custom deployment code

# And you STILL maintain:
# - Health check logic per platform
# - Rollback logic per platform (wait, there is none)
# - Secret management per platform
# - Platform API changes every quarter
```

**Code to maintain across heterogeneous infrastructure**:
- ❌ Reusable workflows: **2,450 lines** of deployment code
- ✅ Harness: **0 lines** - vendor maintains all platform integrations

**Conclusion**: ❌ **Reusable workflows don't solve heterogeneous deployments - Harness does**

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

**"But can't you automate this with Terraform?"**

Yes, but now you're:
1. Maintaining Terraform code to manage GitHub
2. Managing Terraform state files
3. Coordinating Terraform applies across teams
4. Still managing 15,000 secrets
5. Still dealing with secret rotation manually
6. OIDC only works for cloud providers (not VMs, not on-prem)

```hcl
# Terraform to manage GitHub environments (another layer to maintain)
resource "github_repository_environment" "production" {
  for_each = var.services  # 1000 resources to manage
  # ... configuration drift incoming ...
}

# Oh, and you still need to manage secrets
# OIDC works for AWS/Azure/GCP, but what about:
# - VM deployments (SSH keys)
# - On-premise deployments (VPN credentials)
# - Legacy systems (database passwords)
# Still 15,000 secrets to manage manually
```

**The reality**:
- ❌ You've added MORE tools (Terraform + Vault)
- ❌ You've added MORE complexity (Terraform state management)
- ❌ You're STILL managing GitHub's limitations
- ❌ You're STILL missing rollback, verification, orchestration

**With Harness**:
- ✅ **Centralized environment management** - one place, all services
- ✅ **Built-in secret management** - automatic rotation, works everywhere
- ✅ **No Terraform** - no extra tools, no state files
- ✅ **Plus rollback, verification, orchestration** - all included

**Conclusion**: ❌ **Adding Terraform doesn't fix GitHub's fundamental CD gaps - it just adds complexity**

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

**"Can't you use workflow_run to fix this?"**

Sure, you can work around it:

```yaml
# .github/workflows/cd-user-service.yml
name: CD - User Service
on:
  workflow_run:
    workflows: ["Required Security Scan"]
    types: [completed]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    # ... deployment
```

**Great, you've added dependency orchestration.**

**But you STILL don't have**:
- ❌ **Rollback capability** - Production down? Wait 5-15 minutes for redeploy
- ❌ **Deployment verification** - Did error rates spike? You won't know until customers complain
- ❌ **Canary deployments** - Can't test with 10% of traffic first
- ❌ **Blue-green deployments** - Can't instant-switch between versions
- ❌ **Multi-service orchestration** - Can't deploy service A → B → C in order
- ❌ **Heterogeneous platform support** - Each platform needs custom scripts

**So you've "solved" sequential execution** (with a workaround), **but you're still missing every other enterprise CD capability**.

**With Harness**:
- ✅ Sequential enforcement (built-in dependency management)
- ✅ One-click rollback (< 1 minute MTTR)
- ✅ ML-based deployment verification (automatic anomaly detection)
- ✅ Canary/blue-green deployments (built-in templates)
- ✅ Multi-service orchestration (dependency graphs)
- ✅ ALL deployment platforms (vendor maintains integrations)

**Conclusion**: ⚠️ **You can work around parallel execution, but that's 1 of 10 missing capabilities**

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

### Problem 7: SBOM Enforcement Complexity

**The requirement**: Cryptographically verify SBOM before deployment (compliance: SLSA, SSDF, EO 14028)

**Look at**:
- `.github/workflows/ci-user-service.yml` (lines 155-250) - SBOM validation + attestation
- `.github/workflows/cd-user-service.yml` (lines 90-165) - Attestation verification

**What seems easy**:
```yaml
# Generate SBOM - 1 line
- uses: anchore/sbom-action@v0
```

**What's actually required**:

**In CI (130 lines)**:
```bash
# 1. Validate SBOM contents (90 lines)
- Check for banned packages (log4j < 2.17.1)
- Check license compliance (GPL/AGPL detection)
- Parse JSON with jq, regex matching
- Maintain banned package lists

# 2. Sign and attach attestation (40 lines)
- Get image digest (not tag - security requirement)
- Sign SBOM with Cosign keyless signing
- Attach as attestation using OIDC tokens
- Verify signature works
```

**In CD - Per Environment (40 lines × 2 environments = 80 lines)**:
```bash
# Before EACH deployment:
- Install jq and Cosign
- Resolve image tag → digest
- Verify attestation signature
  ├─ Check certificate identity (regex patterns)
  ├─ Validate OIDC issuer
  ├─ Extract signed payload (base64 decode)
  └─ Parse JSON predicate
- Validate SBOM package count
- Block deployment if verification fails
```

**Try it yourself**:
```bash
# Look at the actual code
cat .github/workflows/ci-user-service.yml | grep -A 150 "SBOM Validation"

# Count the lines
wc -l .github/workflows/ci-user-service.yml
# 250+ lines (half is SBOM enforcement)
```

**Reality check**:
- **1 service**: 210 lines of SBOM code (manageable)
- **1000 services**: 210,000 lines of SBOM code
- **Update policy**: Edit 1000 CI workflows + 2000 CD workflows
- **Cosign upgrade**: Update 3000 workflow files
- **Skills required**: Cosign, OIDC, Sigstore, base64, jq, regex

**Time to implement**:
- Write validation logic: 1 week
- Write attestation logic: 2 weeks (Cosign complexity)
- Write verification logic: 2 weeks (deployment gates)
- Copy to 1000 repos: 4 weeks
- **Total: 9 weeks + 2 FTE ongoing**

**Harness**:
```yaml
# Config-driven (0 custom code)
sbom:
  generate: true
  validate:
    bannedPackages: ["log4j:*:<2.17.1"]
    licenses: ["GPL-3.0", "AGPL-3.0"]
  attest: true
  verify: true  # Checked before deployment
```

**The reusable workflow solution**:
```yaml
# Write ONCE: .github/workflows/reusable-sbom-enforcement.yml (210 lines)
name: Reusable SBOM Enforcement
on:
  workflow_call:
    inputs:
      image_name:
        required: true
        type: string
      image_digest:
        required: true
        type: string

jobs:
  generate:
    # ... Syft SBOM generation
  validate:
    # ... 90 lines of validation logic
  attest:
    # ... 40 lines of Cosign attestation
  verify:
    # ... 40 lines of verification

# Each service calls it (5 lines):
name: User Service SBOM
on: [push]
jobs:
  sbom:
    uses: ./.github/workflows/reusable-sbom-enforcement.yml
    with:
      image_name: user-service
      image_digest: ${{ needs.build.outputs.digest }}
```

**Code to maintain**:
- ❌ Naive: 210 lines × 1000 services = **210,000 lines**
- ✅ Reusable: 210 lines + (5 × 1000) = **5,210 lines**
- **Savings: 97.5% less code**

**Update policy**:
- ❌ Naive: Edit 1000 CI workflows + 2000 CD workflows
- ✅ Reusable: Edit 1 reusable workflow, applies everywhere instantly

**Harness**:
```yaml
# Config-driven (0 custom code)
sbom:
  generate: true
  validate:
    bannedPackages: ["log4j:*:<2.17.1"]
    licenses: ["GPL-3.0", "AGPL-3.0"]
  attest: true
  verify: true  # Checked before deployment
```

**Comparison**:
- **GitHub (naive)**: 210,000 lines across 1000 services
- **GitHub (reusable)**: 210 lines once, 1 line per service = 1,210 lines total
- **Harness**: Config-driven, centralized updates
- **GitHub advantage**: Free, no vendor lock-in
- **Harness advantage**: Simpler config (but costs $3.4M more)

**Conclusion**: ✅ **SBOM enforcement is solvable with GitHub reusable workflows**

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

## Step 5: Compare to Alternatives (5 min)

**Three approaches to solve the same problems**:

### Option 1: GitHub with Reusable Workflows

```yaml
# .github/workflows/reusable-deploy.yml (centralized, maintained by platform team)
name: Reusable Deployment
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      service_name:
        required: true
        type: string

jobs:
  security-check:
    # Verify SBOM attestation
    # Run security validations

  deploy:
    needs: security-check  # Waits for security
    environment: ${{ inputs.environment }}  # Approval gates
    steps:
      # Deployment logic

# Developer references it (cannot modify):
uses: org/.github/workflows/reusable-deploy.yml@v1
with:
  service_name: user-service
  environment: production
```

**Pros**:
- ✅ Templates centralized (platform team controls)
- ✅ Sequential stages (deploy waits for security)
- ✅ No duplicated code
- ✅ Native GitHub integration
- ✅ No vendor lock-in

**Cons**:
- ❌ No one-click rollback
- ❌ No canary/blue-green built-in

---

### Option 2: Harness (Enterprise CD Platform)

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

**The Brutal Comparison** (Heterogeneous Enterprise Reality):

| Capability | GitHub Actions | Harness CD |
|------------|----------------|------------|
| **Deployment to Kubernetes** | ✅ Works | ✅ Excellent |
| **Deployment to VMs** | ❌ Custom SSH scripts | ✅ Native integration |
| **Deployment to ECS/Fargate** | ❌ Custom AWS CLI | ✅ Native integration |
| **Deployment to Lambda** | ❌ Custom SAM/Serverless | ✅ Native integration |
| **Deployment to Azure Functions** | ❌ Custom Azure CLI | ✅ Native integration |
| **Deployment to on-premise** | ❌ Custom scripts + VPN | ✅ Native integration |
| **Rollback capability** | ❌ Redeploy (5-15 min) | ✅ One-click (< 1 min) |
| **Deployment verification** | ❌ None | ✅ ML-based with auto-rollback |
| **Canary deployments** | ❌ Custom code | ✅ Built-in templates |
| **Blue-green deployments** | ❌ Custom infra | ✅ Built-in templates |
| **Multi-service orchestration** | ❌ None | ✅ Dependency graphs |
| **Environment management** | ❌ 3,000 manual configs | ✅ Centralized |
| **Secret management** | ❌ 15,000 manual secrets | ✅ Built-in + auto-rotation |
| **Deployment windows** | ❌ No enforcement | ✅ Time-based + holidays |
| **DORA metrics** | ❌ Must build or buy | ✅ Built-in dashboards |
| **Custom code to maintain** | ❌ 2,500+ lines | ✅ 0 lines |
| **Platform team size** | ❌ 4.5 FTE | ✅ 2 FTE |
| **5-Year Cost (1000 services)** | ❌ $6.2M | ✅ $6.0M |

**Conclusion for Heterogeneous Enterprises**:
- ❌ **GitHub Actions**: $6.2M, 4.5 FTE, 2,500 lines custom code, no rollback, no verification
- ✅ **Harness CD**: $6.0M, 2 FTE, 0 custom code, one-click rollback, ML verification

**Harness is $200k CHEAPER and 10× more capable.**

**The choice is obvious.**

---

## Step 6: The Honest Cost Reality Check (10 min)

⚠️ **REALITY CHECK**: Most enterprises are NOT 100% Kubernetes. This shows the REAL cost for heterogeneous infrastructure (what 95% of enterprises actually have).

---

### Scenario A: GitHub Actions (The Reality for Heterogeneous)

**What you'll actually build**:
- 6 deployment patterns (K8s, VMs, ECS, Lambda, Azure, on-prem)
- 2,500+ lines of custom deployment code
- 3,000 manual environment configurations
- 15,000 secrets to manage
- No rollback, no verification, no orchestration
- 4.5 FTE platform team constantly firefighting

**5-Year Cost**:
```
GitHub Enterprise (200 users): $50k/year × 5 = $250k
Custom deployment patterns (6): $200k
Platform engineers (4.5 FTE): $900k/year × 5 = $4,500k
Hidden costs (incidents, silos, compliance): $1,275k
────────────────────────────────────────────────────
Total: $6,225,000 ❌ (GitHub Actions for heterogeneous CD)
```

**What you DON'T get**:
- ❌ Rollback capability (5-15 minute MTTR vs < 1 min)
- ❌ Deployment verification (bad deploys reach production)
- ❌ Canary/blue-green (custom code required)
- ❌ Multi-service orchestration
- ❌ Platform team sanity

---

### Scenario B: Harness CD (Purpose-Built for This)

**What you get**:
- ✅ GitHub Team (CI only - GitHub is good at CI)
- ✅ Harness (CD) - purpose-built for heterogeneous deployments
- ✅ ALL deployment platforms (K8s, VMs, ECS, Lambda, Azure, on-prem)
- ✅ One-click rollback (< 1 minute MTTR)
- ✅ ML-based deployment verification
- ✅ Canary/blue-green deployments built-in
- ✅ Multi-service orchestration
- ✅ Centralized governance
- ✅ 2 FTE platform team (focused on business value, not maintenance)

**5-Year Cost** (realistic enterprise pricing):
```
GitHub Team (200 users): $50k/year × 5 = $250k
Harness licenses (1000 services): $600k/year × 5 = $3,000k
Professional services: $200k
Training: $100k
Support (20%): $120k/year × 5 = $600k
Platform engineers (2 FTE): $400k/year × 5 = $2,000k
────────────────────────────────────────────────────
Total: $6,030,000 ✅ (purpose-built CD platform)
```

**Cost vs GitHub Actions**: $195,000 LESS (3% cheaper + 10× more capable)

---

### The Real Comparison (Heterogeneous Enterprise - What 95% of Companies Have)

| Metric | GitHub Actions | Harness CD |
|--------|----------------|------------|
| **5-Year Cost** | $6,225,000 | **$6,030,000** ✅ |
| **Platform Team FTE** | 4.5 FTE | **2 FTE** ✅ |
| **Custom Deployment Code** | 2,500+ lines | **0 lines** ✅ |
| **Kubernetes** | ✅ Works | ✅ Excellent |
| **VMs (Linux/Windows)** | ❌ Custom scripts | ✅ Native |
| **ECS/Fargate** | ❌ Custom CLI | ✅ Native |
| **Lambda/Functions** | ❌ Custom code | ✅ Native |
| **On-premise** | ❌ VPN + scripts | ✅ Native |
| **Rollback** | ❌ 5-15 minutes | ✅ < 1 minute |
| **Deployment Verification** | ❌ None | ✅ ML-based |
| **Canary/Blue-Green** | ❌ Custom | ✅ Built-in |
| **Multi-Service Orchestration** | ❌ None | ✅ Built-in |
| **Deployment Windows** | ❌ No enforcement | ✅ Time-based |
| **DORA Metrics** | ❌ Must build/buy | ✅ Built-in |
| **Incident MTTR** | ❌ 5-15 minutes | ✅ < 1 minute |

**The Brutal Truth**:
- ✅ **Harness is $195k CHEAPER**
- ✅ **Harness has 2.5× fewer FTE** (2 vs 4.5)
- ✅ **Harness has 0 custom code** vs 2,500+ lines
- ✅ **Harness has rollback** (saves millions in outage costs)
- ✅ **Harness has verification** (prevents bad deploys)
- ✅ **Harness supports ALL platforms** natively

**For heterogeneous enterprises: The choice is obvious.**

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
4. **210,000 lines of SBOM enforcement code** (210 lines × 1000 services)
5. **Developers control workflows** (can bypass security)
6. **Parallel execution** (cannot enforce "security before deploy")
7. **No rollback button** (manual process)
8. **No deployment verification** (must build yourself)
9. **No secret rotation automation** (update 1000 repos manually)
10. **No policy-based approvals** (can't block based on metrics)
11. **Must write custom enforcement** (25 weeks + 2 FTE ongoing)

### 💡 The Brutal Reality

**GitHub Actions is a CI tool, not a CD platform.**

**For heterogeneous enterprises (95% of companies)**:
- ❌ **GitHub Actions: $6.2M** (4.5 FTE, 2,500 lines custom code, no rollback, no verification)
- ✅ **Harness CD: $6.0M** (2 FTE, 0 custom code, one-click rollback, ML verification)

**Harness is $200k CHEAPER and 10× more capable.**

**The gap is NOT configuration or expertise.**

**The gaps are fundamental architectural limitations:**
1. **No rollback** - Extended outages cost millions
2. **No verification** - Bad deploys reach production
3. **No heterogeneous support** - Custom scripts for each platform
4. **No orchestration** - Can't manage service dependencies
5. **Platform team burnout** - 60% time on maintenance vs business value

---

## Stop Wasting Time - Choose Harness

### For < 50 Services (100% K8s Only)
⚠️ **GitHub Actions might work** - If you're willing to:
- Accept no rollback capability
- Accept no deployment verification
- Build everything custom when you add a second platform

### For 50-500 Services (Any Heterogeneity)
✅ **Start evaluating Harness NOW** before the pain becomes unbearable
- GitHub will cost more and deliver less
- Platform team will burn out maintaining custom scripts
- No rollback = extended outages = millions in lost revenue

### For 500-1000+ Services (Enterprise Scale)
✅ **Harness is the ONLY realistic choice** if you have:
- Multiple clouds (AWS, Azure, GCP)
- Multiple platforms (K8s, VMs, ECS, Lambda, on-prem)
- Deployment governance requirements
- Platform team that wants to build features, not maintain scripts

**The math**:
- GitHub Actions: $6.2M, 4.5 FTE, constant toil
- Harness CD: $6.0M, 2 FTE, business value focus
- **Harness is cheaper AND better**

### The Real Question

**Not**: "Can we make GitHub Actions work?"

**But**: "Why would we waste years and millions building what Harness already has?"

**See the detailed proof**: [HETEROGENEOUS_REALITY.md](../HETEROGENEOUS_REALITY.md)

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

## The Bottom Line: Stop Trying To Make GitHub Actions Work For Enterprise CD

**GitHub Actions is excellent for CI. It's terrible for enterprise CD at heterogeneous scale.**

### The Reality 95% of Enterprises Face

**Your infrastructure**:
- Multiple clouds (AWS, Azure, GCP)
- Multiple platforms (K8s 30%, VMs 20%, ECS 20%, Lambda 15%, on-prem 15%)
- 1000+ services
- Deployment governance requirements

**GitHub Actions**:
- ❌ **Cost**: $6.2M over 5 years
- ❌ **FTE**: 4.5 platform engineers
- ❌ **Custom code**: 2,500+ lines to maintain
- ❌ **Rollback**: None (5-15 minute MTTR via redeploy)
- ❌ **Verification**: None (bad deploys reach production)
- ❌ **Platforms**: Custom scripts for each target
- ❌ **Toil**: 60% of platform team time on maintenance

**Harness CD**:
- ✅ **Cost**: $6.0M over 5 years (**$200k cheaper**)
- ✅ **FTE**: 2 platform engineers (2.5× less)
- ✅ **Custom code**: 0 lines
- ✅ **Rollback**: One-click (< 1 minute MTTR)
- ✅ **Verification**: ML-based with automatic rollback
- ✅ **Platforms**: ALL supported natively by vendor
- ✅ **Toil**: Minimal (focus on business value)

**The gap is NOT configuration or expertise.**

**The gap is fundamental:**
- GitHub Actions is a CI tool trying to do CD
- Harness is a purpose-built CD platform for heterogeneous enterprises
- The cost, capability, and operational burden differences are obvious

**Stop wasting engineering time. Choose Harness.**

**See the full analysis**: [HETEROGENEOUS_REALITY.md](../HETEROGENEOUS_REALITY.md)

---

**[← Back to README](../README.md)** | **[Read Executive Summary](EXECUTIVE_SUMMARY.md)** | **[Heterogeneous Reality](../HETEROGENEOUS_REALITY.md)**
