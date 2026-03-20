# Developer vs Platform Team: Can Developers Bypass Security?

**TL;DR: Even in GitHub Enterprise, YES. Workflows are just files. Developers can edit them.**

This document demonstrates the **critical governance gap** between what **Platform Teams want to enforce** and what **Developers can actually bypass** in GitHub.

> ⚠️ **IMPORTANT**: This analysis assumes **GitHub Enterprise** with ALL features enabled:
> - GitHub Advanced Security
> - Required Workflows
> - Organization Rulesets
> - CODEOWNERS enforcement
> - Branch Protection Rules
>
> **Even with GitHub's most expensive tier and all features, the architectural limitation persists.**

> 🎯 **The Enterprise Problem**: At 1000+ repos, you can't rely on trust and code review. You need **architectural enforcement**.

---

## The Two Roles

### 👨‍💻 Developer (Application Team)

**Goal**: Ship features fast
**Owns**: Application code in their service repo
**Wants**:
- Fast CI/CD pipelines
- Minimal friction
- Ability to iterate quickly

**Shouldn't be able to**:
- ❌ Skip security scanning
- ❌ Bypass approval gates
- ❌ Remove SBOM generation
- ❌ Disable policy validation
- ❌ Deploy without signed images

---

### 🛡️ Platform Team (Infrastructure/Security)

**Goal**: Enforce security and compliance across ALL 1000+ repos
**Owns**: CI/CD templates, security policies, infrastructure
**Needs to enforce**:
- ✅ Security scanning on every build
- ✅ Approval gates for production
- ✅ SBOM generation for compliance
- ✅ Policy validation (OPA/Conftest)
- ✅ Image signing (supply chain security)

**At 1000 repos**: Can't manually review every workflow change

---

## The GitHub Reality: Workflows Are Just Files

Let's look at our actual CI workflow:

```bash
# This is just a file in the developer's repo
.github/workflows/ci-user-service.yml
```

**Who controls this file?**

👨‍💻 **The developer.** It's in their repo. They can edit it.

---

## Scenario 1: Developer Bypasses Security Scanning

### What Platform Team WANTS

```yaml
# .github/workflows/ci-user-service.yml
jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    needs: build

    steps:
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.image.outputs.tag }}
          severity: 'CRITICAL,HIGH'
          exit-code: 1  # FAIL build on vulnerabilities
```

### What Developer CAN DO (Bypass)

**Option 1: Comment out the job**
```yaml
# jobs:
#   security-scan:
#     name: Security Scanning
#     ...
```

**Option 2: Change to not fail**
```yaml
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.image.outputs.tag }}
          severity: 'CRITICAL,HIGH'
          exit-code: 0  # ✅ Never fail, even with CVEs
```

**Option 3: Skip on condition**
```yaml
  security-scan:
    if: github.event.head_commit.message != 'skip-security'
```

Then commit with: `git commit -m "Quick fix skip-security"`

**Option 4: Remove `needs` dependency**
```yaml
  deploy:
    name: Deploy
    # needs: [security-scan]  # ← Removed, deploy even if scan fails
```

---

## Scenario 2: Developer Bypasses Approval Gates

### What Platform Team WANTS

```yaml
  deploy-production:
    name: Deploy to Production
    environment: production  # Requires approval
```

With GitHub Environment configured:
- Requires 2 approvals
- Only from platform-team group

### What Developer CAN DO (Bypass)

**Just remove the environment**:
```yaml
  deploy-production:
    name: Deploy to Production
    # environment: production  # ← Removed
    runs-on: ubuntu-latest
```

**Now deploys to production with ZERO approvals.**

---

## Scenario 3: Developer Skips SBOM Generation

### What Platform Team WANTS

```yaml
  sbom:
    name: Generate SBOM
    steps:
      - name: Generate SBOM with Syft
        uses: anchore/sbom-action@v0
      - name: Upload SBOM
        uses: actions/upload-artifact@v4
```

### What Developer CAN DO (Bypass)

**Delete the entire job**:
```yaml
# jobs:
#   sbom:
#     name: Generate SBOM
#     ...
```

**Why would they?** "SBOM generation is slow, and we're in a hurry."

---

## Scenario 4: Developer Skips Image Signing

### What Platform Team WANTS

```yaml
  sign:
    name: Sign Image
    steps:
      - name: Sign image with Cosign
        run: |
          cosign sign --yes ${{ steps.image.outputs.tag }}
```

### What Developer CAN DO (Bypass)

**Remove the job**:
```yaml
# jobs:
#   sign:
#     name: Sign Image
#     ...
```

**Or continue on error**:
```yaml
  sign:
    continue-on-error: true  # ✅ Keep going even if signing fails
```

---

## What GitHub Provides to PREVENT This

### 1. Branch Protection Rules ⚠️ Partial Solution

**GitHub Organization Settings → Branches → Branch Protection**

```yaml
Protection rules for 'main':
  ✅ Require pull request before merging
  ✅ Require approvals: 2
  ✅ Require status checks to pass
     - security-scan
     - sbom
     - sign
  ✅ Require code owner review
```

**This prevents direct pushes to main.**

**But it DOESN'T prevent**:
- ❌ Developer modifies workflow to skip security
- ❌ Developer commits the bypass
- ❌ Another developer (not platform team) approves the PR
- ❌ Status checks pass (because they were removed from workflow)
- ❌ **Bypass is merged**

**Why?** Because the workflow file itself defines what runs. If you remove the security-scan job, there's no status check to fail.

---

### 2. CODEOWNERS File ⚠️ Partial Solution

**Create `.github/CODEOWNERS`**:
```
# Platform team must approve workflow changes
/.github/workflows/ @platform-team
```

**This requires platform team review for workflow changes.**

**But it requires**:
- ✅ Platform team to review EVERY workflow change
- ✅ Across ALL 1000 repositories
- ✅ Platform team has capacity to review
- ✅ Platform team catches subtle bypasses

**At 1000 repos**: This doesn't scale.

**Developer can still**:
- Add `continue-on-error: true` (subtle bypass)
- Change `exit-code: 1` to `exit-code: 0` (looks innocent)
- Add `if: false` condition (easy to miss)

---

### 3. Required Workflows (GitHub Enterprise) ⚠️ Partial Solution

**GitHub Enterprise Cloud feature** (enabled in our scenario):

```yaml
# .github/workflows/required-security.yml
# In organization's .github-private repository
name: Required Security Checks

on:
  pull_request:
  push:

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - name: Run Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'CRITICAL,HIGH'
          exit-code: 1

      - name: Run SBOM generation
        uses: anchore/sbom-action@v0
        with:
          path: .
          format: spdx-json
```

**Platform team defines this ONCE, automatically runs on ALL 1000 repos.**

**This IS a significant improvement and we're assuming it's enabled.**

**However, critical limitations remain**:

**Limitation 1: Can't integrate with repo-specific workflows**
- ❌ Required workflow runs independently
- ❌ Developer's deploy workflow can run in parallel
- ❌ No way to make deploy job depend on required workflow completion
- **Result**: Developer's workflow can deploy while required workflow is still running

**Limitation 2: Can't block deployments**
```yaml
# Developer's workflow
jobs:
  deploy:
    runs-on: ubuntu-latest
    # No way to require required workflow completion
    steps:
      - name: Deploy
        run: kubectl apply -f manifests/
```
**Developer's deploy job runs regardless of required workflow status.**

**Limitation 3: Limited context access**
- ❌ Required workflow can't easily access service-specific artifacts
- ❌ Can't reference Docker images built by repo workflow
- ❌ Can't access service-specific configuration
- **Result**: Can do filesystem scans but not image scans, can't validate deployed state

**Limitation 4: All-or-nothing customization**
- ❌ Either applies to ALL repos or NONE
- ❌ Can't have different required workflows for different service types
- ❌ No way for developers to provide service-specific inputs
- **Result**: Generic checks only, can't be service-aware

**Limitation 5: Timing issues**
```
Developer pushes code
  ├─ Developer's workflow starts (builds, deploys)
  └─ Required workflow starts (security scan)

After 5 minutes:
  ├─ Developer's workflow: ✅ Deployed to production
  └─ Required workflow: ❌ Found CVE, failed

Result: Vulnerable code is ALREADY IN PRODUCTION
```

**Most importantly**:
- ❌ **Cannot block deployment in developer's workflow**
- ❌ **No dependency mechanism between workflows**
- ❌ **Runs in parallel, not as a gate**

**What you'd need to make it work**:
1. Required workflow builds image
2. Required workflow scans image
3. Required workflow approves deployment
4. Developer's workflow waits for required workflow approval
5. **Problem**: GitHub has no cross-workflow dependency mechanism

**Workaround** (doesn't scale):
```yaml
# Developer must manually add to every workflow:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Wait for required workflow
        uses: actions/github-script@v7
        with:
          script: |
            // Poll for required workflow status
            // Wait until it completes
            // Check if it succeeded
            // Only then proceed
```
**This defeats the purpose** - developers can just remove this step!

---

### 4. GitHub Rulesets (GitHub Enterprise) ⚠️ Partial Solution

**Enabled in our scenario** - successor to Branch Protection, more powerful:

```yaml
# Organization-level ruleset (applies to all 1000 repos)
name: Production Deployment Protection
target: branch
enforcement: active
conditions:
  ref_name:
    include:
      - refs/heads/main

rules:
  - type: pull_request
    parameters:
      required_approving_review_count: 2
      require_code_owner_review: true
      dismiss_stale_reviews_on_push: true

  - type: required_status_checks
    parameters:
      strict_required_status_checks_policy: true
      required_status_checks:
        - context: security-scan
          integration_id: 12345  # Required workflow
        - context: sbom-generation
          integration_id: 12345
        - context: image-signing
          integration_id: 12345

  - type: required_workflows
    parameters:
      required_workflows:
        - path: .github/workflows/required-security.yml
          repository: org/.github-private
```

**This IS powerful and we're assuming it's fully configured.**

**But the fundamental problem remains**:

**Problem 1: Status checks come from workflows developers control**
- ✅ Ruleset requires `security-scan` status check
- ❌ Developer removes `security-scan` job from their workflow
- ❌ Job doesn't run → status check never created
- **Result**: Depends on ruleset configuration

**Configuration options**:
```yaml
# Option A: Require specific checks
required_status_checks_policy:
  strict: true
  contexts: [security-scan, sbom, sign]
# Problem: If developer removes job, check never appears
# Outcome: PR blocked forever OR timeout allows bypass

# Option B: Require ANY checks to pass
required_status_checks_policy:
  strict: false
# Problem: Developer removes all security jobs
# Outcome: No checks run = no checks fail = PR allowed
```

**Problem 2: Required Workflows can't block deployments**
```yaml
# Even with required workflow configured:
# 1. Required workflow runs (scans filesystem)
# 2. Developer's workflow runs (builds image, deploys)
# 3. No dependency between them
# Result: Deploy happens regardless of required workflow outcome
```

**Problem 3: Integration ID requirements**
- ✅ Can specify integration_id for required workflow
- ❌ Developer can still run their own workflow
- ❌ Their workflow's deploy job has no dependency
- **Result**: Both workflows run, no enforcement of order

**Real-world scenario**:
```
Developer pushes to PR → Triggers workflows

Required Workflow (from ruleset):
  ├─ Filesystem scan: ✅ Pass
  └─ Status: security-scan ✅

Developer's Workflow (from repo):
  ├─ Build image: ✅ Pass
  ├─ Scan image: ❌ Skipped (developer removed job)
  ├─ Deploy: ✅ Deployed
  └─ Status: build ✅

Ruleset check:
  ✅ Required status check "security-scan" passed
  ✅ PR can be merged

Result: Image was NEVER scanned, but rulesets show green
```

**The core issue**: Rulesets can enforce that certain workflows run, but can't enforce what HAPPENS in the developer's workflow.

---

## Summary: Even with ALL GitHub Enterprise Features Enabled

**We've assumed the BEST case scenario**:
- ✅ GitHub Enterprise Cloud (most expensive tier)
- ✅ GitHub Advanced Security enabled
- ✅ Required Workflows configured organization-wide
- ✅ Organization Rulesets with strict enforcement
- ✅ CODEOWNERS in every repository
- ✅ Branch Protection Rules on all protected branches
- ✅ All security features enabled

**Total GitHub cost at 1000 repos with all Enterprise features: ~$400k/year**

### What This Gives You

**✅ Pre-merge enforcement**:
- Branch protection prevents direct pushes
- Required PR reviews
- CODEOWNERS requires platform team approval for workflow changes
- Required status checks from required workflows
- Rulesets enforce policies across organization

**✅ Organization-wide security**:
- Required workflows run on all repos automatically
- Security scanning happens (at filesystem level)
- Advanced Security features (secret scanning, dependency review)
- Code scanning with CodeQL

**✅ Centralized policy management**:
- Rulesets apply organization-wide
- Required workflows defined once
- No need to configure each repo individually

### What's STILL Missing (The Architectural Gap)

**❌ Cannot prevent deployment bypasses**:

Even with all features enabled, a developer can:

```yaml
# Developer's workflow (in their repo)
jobs:
  # Required workflow runs separately (org-level)
  # But developer's workflow is independent:

  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        run: |
          # This runs REGARDLESS of required workflow status
          kubectl apply -f manifests/
```

**Why required workflows don't prevent this**:
1. Required workflow runs in parallel (can't block)
2. No cross-workflow dependency mechanism
3. Developer's workflow doesn't wait for required workflow
4. Both workflows run independently

**❌ Cannot enforce deployment-time policies**:
```yaml
# Required workflow can scan filesystem
# But CANNOT:
# - Scan the Docker image (developer builds it)
# - Enforce approval gates (developer controls deploy job)
# - Verify deployment metrics (happens post-deploy)
# - Block bad deployments (no integration point)
```

**❌ Timing race condition**:
```
t=0: Developer pushes code
t=0: Required workflow starts (filesystem scan)
t=0: Developer's workflow starts (build + deploy)

t=3min: Developer's workflow deploys ✅
t=5min: Required workflow finds CVE ❌

Result: Vulnerable code ALREADY IN PRODUCTION
```

**❌ Cannot prevent subtle bypasses**:

Even with CODEOWNERS review, developers can:
```yaml
jobs:
  security-scan:
    runs-on: ubuntu-latest
    continue-on-error: true  # ← Subtle bypass
    # Platform reviewer might miss this in 1000 PRs
```

Or:
```yaml
jobs:
  security-scan:
    runs-on: ubuntu-latest
    if: github.event.head_commit.message != 'hotfix'
    # ← Conditional bypass, easy to miss
```

Or:
```yaml
jobs:
  deploy:
    # environment: production  # ← Commented out
    # Approval gate removed
```

**❌ Configuration still distributed**:
- Required workflows: ✅ Centralized
- Developer workflows: ❌ In 1000 repos
- GitHub Environments: ❌ Per-repo configuration (3000 configs)
- Approval policies: ❌ Per-environment (managed via API/Terraform)
- Deployment logic: ❌ In developer workflows

### The Core Architectural Issue

**GitHub Enterprise with all features gives you**:
- ✅ Organization-wide **filesystem security scanning**
- ✅ Organization-wide **pre-merge checks**
- ✅ Centralized **ruleset policies**

**But you STILL don't get**:
- ❌ **Deployment-time enforcement** (required workflows can't block deploys)
- ❌ **Template locking** (developers control their workflows)
- ❌ **Deployment orchestration** (no cross-workflow dependencies)
- ❌ **Guaranteed security** (timing issues, parallel execution)

**The fundamental problem**:
```
In GitHub: Deployment logic lives IN developer repos
In Harness: Deployment logic lives OUTSIDE developer repos
```

This architectural difference persists **regardless of which GitHub tier you use**.

### What Would Be Needed to Fix This in GitHub

**Hypothetical GitHub feature** (doesn't exist):
```yaml
# Organization-level DEPLOYMENT template
# That developers CANNOT override
template:
  name: Required Deployment Process
  enforcementLevel: LOCKED  # ← Doesn't exist in GitHub

  jobs:
    security:
      locked: true  # ← Can't skip, can't modify

    deploy:
      locked: true  # ← Can't change
      requiresApproval: true  # ← Can't remove
      waitForMetrics: true  # ← Can't skip
```

**This would require**:
- Deployment templates (not just workflow templates)
- Template locking mechanism
- Cross-workflow dependencies
- Deployment-time enforcement
- **Fundamental architectural change to GitHub Actions**

---

## What This Means at Scale

### At 3 Services (What We Have)

**Platform team can**:
- ✅ Manually review workflow changes via CODEOWNERS
- ✅ Catch obvious bypasses in code review
- ✅ Enforce through trust and process

**Operational burden**: Manageable

---

### At 1000 Services

**Platform team CANNOT**:
- ❌ Review every workflow change across 1000 repos
- ❌ Catch subtle bypasses (continue-on-error, exit-code changes)
- ❌ Prevent developers from removing environment gates
- ❌ Ensure consistent security across all services

**Operational burden**: Impossible

**What happens**:
- Some teams skip security scanning ("we're in a hurry")
- Some teams remove approval gates ("we trust our process")
- Some teams don't generate SBOMs ("compliance isn't our priority")
- **Security and compliance are compromised**

---

## How Harness Solves This Architecturally

### Harness Architecture: Templates Live OUTSIDE Repos

```
┌─────────────────────────────────────────────────────┐
│ Harness Platform (Platform Team Controls)          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Pipeline Template: "Production Deploy"            │
│  ┌───────────────────────────────────────────┐     │
│  │ Stage 1: Build                            │     │
│  │   - Run tests                             │     │
│  │   - Build Docker image                    │     │
│  ├───────────────────────────────────────────┤     │
│  │ Stage 2: Security (LOCKED BY PLATFORM)    │     │
│  │   - Trivy scan (CANNOT SKIP)              │     │
│  │   - SBOM generation (CANNOT SKIP)         │     │
│  │   - Cosign signing (CANNOT SKIP)          │     │
│  │   - Policy validation (CANNOT SKIP)       │     │
│  ├───────────────────────────────────────────┤     │
│  │ Stage 3: Deploy                           │     │
│  │   - Environment: production               │     │
│  │   - Approval: Required (2 approvers)      │     │
│  │   - Deployment verification (CANNOT SKIP) │     │
│  └───────────────────────────────────────────┘     │
│                                                     │
└─────────────────────────────────────────────────────┘
              ↓ (Developers use template)
┌─────────────────────────────────────────────────────┐
│ Developer's Service Repo                            │
├─────────────────────────────────────────────────────┤
│  - Application code                                 │
│  - NO workflow files                                │
│  - NO ability to modify pipeline                    │
│  - Harness automatically deploys using template     │
└─────────────────────────────────────────────────────┘
```

### Key Differences

| Aspect | GitHub | Harness |
|--------|--------|---------|
| **Template Location** | In developer's repo (`.github/workflows/`) | In Harness platform (outside repo) |
| **Who Controls** | Developer (it's their file) | Platform team (via Harness UI/API) |
| **Can Developer Edit** | ✅ Yes, anytime | ❌ No, read-only reference |
| **Can Developer Skip Security** | ✅ Yes (comment out, change exit code, etc.) | ❌ No, enforced by platform |
| **Can Developer Remove Approval** | ✅ Yes (remove environment line) | ❌ No, defined in template |
| **Enforcement** | Trust + Code Review + Branch Protection | **Architectural** - template is not in repo |
| **At 1000 Repos** | ❌ Manual review doesn't scale | ✅ Enforced automatically |

---

## Harness Template Example

### Platform Team Creates Template (ONCE)

```yaml
# In Harness Platform (NOT in any repo)
template:
  name: Production Deployment Pipeline
  identifier: prod_deploy_v1
  versionLabel: v1.0.0
  type: Pipeline

  stages:
    - stage:
        name: Security Scanning
        type: SecurityTests
        locked: true  # ← DEVELOPERS CANNOT MODIFY
        spec:
          tests:
            - identifier: trivy_scan
              type: ContainerVulnerability
              spec:
                scanner: Trivy
                failOnSeverity: HIGH
                skipIfFail: false  # ← CANNOT be changed to true

            - identifier: sbom_generation
              type: SBOM
              spec:
                tool: Syft
                required: true  # ← CANNOT be skipped

            - identifier: image_signing
              type: ImageSigning
              spec:
                tool: Cosign
                required: true  # ← CANNOT be skipped

    - stage:
        name: Production Deployment
        type: Deployment
        locked: true  # ← DEVELOPERS CANNOT MODIFY
        spec:
          environment: production
          approval:
            type: HarnessApproval
            spec:
              approvers:
                userGroups: [platform-team, security-team]
              minimumCount: 2
              cannotBypass: true  # ← DEVELOPERS CANNOT SKIP

          verification:
            type: Auto
            timeout: 10m
            failureStrategy:
              action: ROLLBACK  # ← CANNOT be changed
```

### Developers Reference Template (Cannot Modify)

```yaml
# In developer's repo: .harness/pipeline.yml
pipeline:
  name: User Service Pipeline
  identifier: user_service

  # Developer specifies WHICH template to use
  templateRef: prod_deploy_v1
  versionLabel: v1.0.0

  # Developer provides inputs
  inputs:
    service: user-service
    dockerfile: ./Dockerfile
    manifest: k8s/
```

**Developers CANNOT**:
- ❌ Skip security scanning (locked stage)
- ❌ Remove approval gate (locked in template)
- ❌ Skip SBOM generation (required in template)
- ❌ Change failure behavior (locked)
- ❌ Edit the template (it's in Harness, not their repo)

**Developers CAN**:
- ✅ Provide service-specific inputs
- ✅ Trigger deployments
- ✅ View deployment status
- ✅ See approval requirements

---

## Real-World Scenarios

### Scenario: Developer Tries to Bypass Security

**GitHub**:
```yaml
# Developer edits .github/workflows/ci.yml
jobs:
  security-scan:
    continue-on-error: true  # ← Bypass added
```

**Result**:
- ✅ PR created
- ⚠️ Requires CODEOWNERS review (if configured)
- ⚠️ Reviewer might miss subtle change
- ❌ **Bypass can be merged**

**Harness**:
```yaml
# Developer tries to edit .harness/pipeline.yml
pipeline:
  templateRef: prod_deploy_v1
  # No way to override locked stages
```

**Result**:
- ❌ **Architecturally impossible to bypass**
- Security stage runs regardless
- Template is in Harness platform, not repo

---

### Scenario: Platform Team Updates Security Policy

**GitHub**:
1. Platform team updates security requirements
2. Must update 1000 workflow files (or use script)
3. Create 1000 PRs
4. Wait for 1000 reviews
5. Merge 1000 PRs
6. Some repos don't update (missed, busy teams, etc.)
7. **Result**: Inconsistent security across organization

**Harness**:
1. Platform team edits template in Harness UI
2. Saves new version: `v1.1.0`
3. **All 1000 services using template get update automatically**
4. **Result**: Consistent security across ALL services instantly

---

## The Enterprise Reality

### Trust + Process Doesn't Scale

**At 10 services**:
- ✅ Code review catches bypasses
- ✅ Platform team can manually verify
- ✅ Trust-based governance works

**At 1000 services**:
- ❌ Can't review every change
- ❌ Subtle bypasses slip through
- ❌ Inconsistent enforcement
- ❌ **Security incidents happen**

### Architectural Enforcement DOES Scale

**Harness approach**:
- ✅ Template lives outside repos
- ✅ Developers reference, cannot modify
- ✅ Platform team controls centrally
- ✅ Updates apply to all services
- ✅ **Impossible to bypass**

---

## Summary: Can Developers Bypass Security?

| Question | GitHub | Harness |
|----------|--------|---------|
| Can developer skip security scanning? | ✅ Yes | ❌ No |
| Can developer remove approval gates? | ✅ Yes | ❌ No |
| Can developer skip SBOM generation? | ✅ Yes | ❌ No |
| Can developer bypass image signing? | ✅ Yes | ❌ No |
| Can platform team prevent bypasses? | ⚠️ Through process (doesn't scale) | ✅ Architecturally (scales) |
| **At 1000 repos, is security guaranteed?** | ❌ **No** | ✅ **Yes** |

---

## Try It Yourself

### See the GitHub Bypass

1. Fork this repo
2. Edit `.github/workflows/ci-user-service.yml`
3. Comment out the security-scan job:
   ```yaml
   # jobs:
   #   security-scan:
   ```
4. Commit and push
5. **Watch CI succeed WITHOUT security scanning**

### See GitHub's Protections (Partial)

1. Enable Branch Protection on `main`
2. Require status check: `security-scan`
3. Now try the same bypass
4. **Result**: You can still merge if you remove the job (no status check created)

---

## Recommendation

### For < 50 Services
⚠️ GitHub approach can work with:
- Rigorous CODEOWNERS enforcement
- Small team that reviews all changes
- Trust-based culture

### For 1000+ Services
❌ **GitHub approach fails**:
- Manual review doesn't scale
- Bypasses inevitable
- Inconsistent security

✅ **Harness (or similar) required**:
- Architectural enforcement
- Centralized control
- Guaranteed consistency

---

**The bottom line**: At enterprise scale, you can't rely on developers to "do the right thing." You need systems that make it **architecturally impossible** to bypass security.

**GitHub relies on trust. Harness enforces by design.**

---

**[← Back to GitHub Gaps](GITHUB_GAPS_REAL.md)** | **[See Why Templates Fail](WHY_GITHUB_TEMPLATES_FAIL.md)** | **[Harness Comparison](HARNESS_COMPARISON.md)**
