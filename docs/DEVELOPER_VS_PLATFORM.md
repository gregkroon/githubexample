# Developer vs Platform Team: Can Developers Bypass Security?

**TL;DR: In GitHub, YES. Workflows are just files. Developers can edit them.**

This document demonstrates the **critical governance gap** between what **Platform Teams want to enforce** and what **Developers can actually bypass** in GitHub.

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

**GitHub Enterprise feature** (November 2022):

```yaml
# .github/workflows/required-security.yml
# In a central organization repo
name: Required Security Checks

on:
  pull_request:
  push:

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - name: Run security scan
        run: echo "This runs on ALL repos"
```

**Platform team defines this ONCE, runs on ALL repos.**

**This is closer to the solution**, but:

**Limitations**:
- ❌ Requires GitHub Enterprise (not available on Free/Team/Cloud)
- ❌ Only triggers on push/PR (not on workflow_dispatch)
- ❌ Can't access service-specific context easily
- ❌ Developers can't customize (too rigid)
- ❌ Still runs as separate workflow (can't block their workflow)

**Most importantly**:
- ❌ Developer's workflow can still deploy WITHOUT waiting for required workflow
- ❌ No way to make deployment depend on required workflow completion

---

### 4. GitHub Rulesets (New, Beta) ⚠️ Partial Solution

**Successor to Branch Protection**, more powerful:

```yaml
# Organization-level ruleset
rules:
  - type: pull_request
    parameters:
      required_approving_review_count: 2
      require_code_owner_review: true
  - type: required_status_checks
    parameters:
      strict_required_status_checks_policy: true
      required_status_checks:
        - context: security-scan
        - context: sbom-generation
        - context: image-signing
```

**This enforces that specific status checks MUST pass.**

**But the problem remains**:
- ❌ Status checks come from the workflow
- ❌ Developer can modify workflow to remove the job
- ❌ If job doesn't run, status check is never created
- ❌ Ruleset can't enforce what doesn't exist

**Example**:
1. Ruleset requires `security-scan` status check
2. Developer removes `security-scan` job from workflow
3. Workflow runs, never creates `security-scan` status
4. **What happens?** GitHub waits indefinitely? Auto-fails? Depends on configuration.
5. If configured to allow missing checks, **bypass succeeds**

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
