# Security Enforcement: GitHub Enterprise vs Harness

**Question**: Can developers bypass security gates in GitHub Actions? Does GitHub Enterprise prevent this?

**Short Answer**: GitHub Enterprise has strong features (Required Workflows, Rulesets), but there's **one architectural limitation** that cannot be fixed: **parallel execution allows deployments before security gates complete**.

---

## Table of Contents

1. [The Claim We're Testing](#the-claim-were-testing)
2. [GitHub Enterprise Security Features](#github-enterprise-security-features)
3. [Bypass Scenarios: What Works and What Doesn't](#bypass-scenarios-what-works-and-what-doesnt)
4. [The Architectural Limitation](#the-architectural-limitation)
5. [Harness Approach](#harness-approach)
6. [Detailed Comparison](#detailed-comparison)
7. [Recommendations](#recommendations)

---

## The Claim We're Testing

**Current documentation states**:
> "Developers can bypass security gates in workflows. GitHub Enterprise can't prevent this architecturally."

**Is this accurate?** Let's test every GitHub Enterprise feature designed to prevent bypasses.

---

## GitHub Enterprise Security Features

### 1. Required Workflows

**What it is**: Organization-wide workflows that run automatically on specified events [1]

**Configuration**:
```yaml
# .github/workflows/required-security.yml (in .github repo)
name: Required Security Scan
on:
  pull_request:
  push:
    branches: [main]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Security scan (CANNOT be bypassed)
        run: |
          trivy fs . --severity CRITICAL,HIGH --exit-code 1
```

**Key properties**:
- ✅ Runs on ALL repositories in the organization
- ✅ Developers CANNOT disable or modify
- ✅ Runs automatically, no workflow file needed in target repo
- ✅ Will fail if security issues found

**Can developers bypass?** ❌ **NO** - Required Workflows cannot be bypassed

**Source**: [GitHub Docs - Required Workflows](https://docs.github.com/en/actions/using-workflows/required-workflows)

---

### 2. Organization Rulesets

**What it is**: Branch protection and deployment rules at organization level [2]

**Configuration**:
```yaml
# Organization Settings → Rulesets
Ruleset: Production Deployment Protection
  Target: All repositories
  Branch pattern: main

  Rules:
    ✅ Require status checks to pass before merging
       - required-security (from Required Workflow)
       - tests
       - build
    ✅ Require code review from CODEOWNERS
    ✅ Block force pushes
    ✅ Require signed commits
```

**Key properties**:
- ✅ Applies to all repositories (cannot be disabled per-repo)
- ✅ Status checks MUST pass before merge
- ✅ Can require specific checks by name
- ✅ Enforced at GitHub platform level

**Can developers bypass?** ❌ **NO** - Rulesets are enforced by GitHub platform

**Source**: [GitHub Docs - Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

---

### 3. CODEOWNERS

**What it is**: Require approval from specific teams for file changes [3]

**Configuration**:
```
# .github/CODEOWNERS
# Platform team must approve workflow changes
/.github/workflows/ @org/platform-team
/Dockerfile @org/platform-team
/k8s/ @org/platform-team
```

**Key properties**:
- ✅ Workflow file changes require platform team approval
- ✅ Enforced via branch protection
- ✅ Cannot merge without approval

**Can developers bypass?** ❌ **NO** - if branch protection enabled

**Limitation**: ⚠️ Platform team must manually review (doesn't scale to 1000 repos, 20 PRs/day)

---

### 4. Repository-Level Branch Protection

**What it is**: Rules on specific branches [4]

**Configuration**:
```yaml
Branch: main
  ✅ Require pull request reviews (1 approval)
  ✅ Require status checks to pass:
     - required-security
     - tests
     - build
  ✅ Require conversation resolution
  ✅ Require signed commits
  ✅ Include administrators
```

**Can developers bypass?** ❌ **NO** - enforced by GitHub

---

### 5. Composite Actions (Reusable Security Logic)

**What it is**: Centralized action code that repositories can use [5]

**Example**:
```yaml
# org/.github/actions/security-scan/action.yml
name: Security Scan
description: Centralized security scanning
runs:
  using: composite
  steps:
    - name: Trivy scan
      run: trivy fs . --exit-code 1
    - name: SBOM validation
      run: |
        # Centralized SBOM logic
        syft . -o json | grype --fail-on critical
```

**Repository usage**:
```yaml
# developer-repo/.github/workflows/ci.yml
jobs:
  security:
    steps:
      - uses: org/.github/actions/security-scan@v1
```

**Can developers bypass?** ⚠️ **YES** - developers can:
1. Not use the composite action
2. Use `continue-on-error: true`
3. Modify their workflow

**But**: If Required Workflow also runs the same scan, it will catch this

---

## Bypass Scenarios: What Works and What Doesn't

### ❌ Bypass 1: Skip Security Step (PREVENTED)

**Developer attempts**:
```yaml
# .github/workflows/ci.yml
jobs:
  security:
    steps:
      - name: Security scan
        if: false  # ← Try to skip
        run: trivy scan
```

**GitHub Enterprise defense**:
- ✅ Required Workflow runs security scan independently
- ✅ Required Workflow will fail if vulnerabilities found
- ✅ Ruleset prevents merge if Required Workflow fails

**Result**: ❌ **PREVENTED** - Required Workflow catches this

---

### ❌ Bypass 2: Continue on Error (PREVENTED)

**Developer attempts**:
```yaml
jobs:
  security:
    steps:
      - name: Security scan
        continue-on-error: true  # ← Try to ignore failures
        run: trivy scan
```

**GitHub Enterprise defense**:
- ✅ Required Workflow runs same scan without `continue-on-error`
- ✅ Required Workflow fails if vulnerabilities found
- ✅ Ruleset blocks merge

**Result**: ❌ **PREVENTED** - Required Workflow enforces failure

---

### ❌ Bypass 3: Modify Workflow File (PREVENTED)

**Developer attempts**:
```yaml
# Remove security scan entirely
jobs:
  build:
    steps:
      - run: echo "no security scan"
```

**GitHub Enterprise defense**:
- ✅ CODEOWNERS requires platform team approval for workflow changes
- ✅ Required Workflow still runs independently
- ✅ Ruleset requires Required Workflow to pass

**Result**: ❌ **PREVENTED** - Platform team reviews changes + Required Workflow runs anyway

---

### ❌ Bypass 4: Bypass Branch Protection (PREVENTED)

**Developer attempts**:
- Force push to main
- Direct commit to protected branch
- Disable branch protection (if they have admin)

**GitHub Enterprise defense**:
- ✅ Organization Ruleset overrides repository settings
- ✅ Force push blocked
- ✅ Direct commits blocked
- ✅ Admin cannot disable org-level ruleset

**Result**: ❌ **PREVENTED** - Organization Rulesets enforce rules

---

### ⚠️ Bypass 5: Parallel Execution Gap (ARCHITECTURAL LIMITATION)

**The scenario**:
```yaml
# Developer workflow (.github/workflows/ci.yml)
on: [push]
jobs:
  deploy:
    steps:
      - name: Deploy to production
        run: kubectl apply -f k8s/
        # Deploys IMMEDIATELY when triggered
```

```yaml
# Required Workflow (.github/workflows/required-security.yml)
on: [push]
jobs:
  security:
    steps:
      - name: Critical security scan
        run: trivy scan --exit-code 1
        # Runs in PARALLEL, not blocking
```

**Timeline**:
```
t=0:   Developer pushes code
t=0:   Developer workflow starts (deploy job)
t=0:   Required Workflow starts (security job)
t=3m:  Developer workflow DEPLOYS to production ✅
t=5m:  Required Workflow finds CRITICAL CVE ❌

Result: Vulnerable code ALREADY IN PRODUCTION
```

**Why this happens**:
- Both workflows triggered by same event (`push`)
- GitHub Actions runs them **in parallel**
- No way to make developer workflow **wait** for Required Workflow
- Developer workflow can deploy before security scan completes

**GitHub Enterprise defense**:
- ❌ **CANNOT PREVENT** - this is architectural
- ⚠️ Workaround: Use branch protection + PR workflow instead of push workflow
  - Require PR to merge to main
  - Require Required Workflow to pass before merge
  - Deploy only from main branch
  - **Issue**: Deployment still happens AFTER merge, not conditionally

**Result**: ⚠️ **ARCHITECTURAL LIMITATION** - Parallel execution cannot be prevented

---

## The Architectural Limitation

### What GitHub Enterprise CAN Enforce

✅ **Security scans must run** (Required Workflows)
✅ **Scans cannot be bypassed** (Organization Rulesets)
✅ **Workflow changes require approval** (CODEOWNERS)
✅ **Merge requires passing checks** (Branch Protection + Rulesets)
✅ **Organization-wide policies** (Rulesets apply to all repos)

**Conclusion**: GitHub Enterprise is **strong at preventing developers from disabling security gates**.

---

### What GitHub Enterprise CANNOT Enforce

❌ **Sequential execution** - Cannot make workflow B wait for workflow A
❌ **Conditional deployment** - Cannot prevent deployment if security fails
❌ **Cross-workflow dependencies** - Required Workflows run in parallel, not as gates

**The gap**:
```
What we need:
  Security Scan → (if pass) → Deploy

What GitHub does:
  Security Scan (parallel)
  Deploy (parallel)

  Both run simultaneously, deployment doesn't wait
```

**Why it's architectural**:
- GitHub Actions workflows are event-driven
- Same event triggers multiple workflows
- No mechanism for "wait for workflow A before running workflow B"
- `workflow_run` trigger exists but has limitations (see below)

---

### Workaround: workflow_run Trigger

**Attempt to fix**:
```yaml
# .github/workflows/security.yml
name: Security Scan
on: [push]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - run: trivy scan --exit-code 1
```

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  workflow_run:
    workflows: ["Security Scan"]
    types: [completed]
    branches: [main]

jobs:
  deploy:
    # Only run if security scan succeeded
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    steps:
      - run: kubectl apply -f k8s/
```

**Does this work?** ⚠️ **PARTIALLY**

**Pros**:
- ✅ Deploy waits for security scan
- ✅ Deploy only runs if security passes
- ✅ Sequential execution achieved

**Cons**:
- ❌ Complex to set up (every repo needs this pattern)
- ❌ Developers can remove the `if` condition or the `workflow_run` trigger
- ❌ Required to use CODEOWNERS to prevent workflow changes (manual review doesn't scale)
- ❌ No centralized enforcement (each repo configures independently)
- ❌ Debugging workflow_run triggers is difficult (opaque event data)

**Conclusion**: workflow_run is a **workaround**, not a **solution** to the architectural limitation

---

## Harness Approach

### Sequential Pipeline Stages

**How Harness enforces**:
```yaml
# Harness pipeline (not in developer repo)
pipeline:
  stages:
    - stage:
        name: Security Scan
        type: CI
        spec:
          steps:
            - step:
                name: Vulnerability Scan
                type: Run
                spec:
                  command: trivy scan --exit-code 1

        # Pipeline STOPS here if security fails

    - stage:
        name: Deploy to Production
        type: Deployment
        spec:
          # This stage ONLY runs if Security Scan passes
          environment: production
          service: user-service
```

**Key differences from GitHub**:

| Aspect | GitHub Actions | Harness |
|--------|----------------|---------|
| **Pipeline location** | In developer repo (.github/workflows/) | In Harness platform (outside repo) |
| **Developer control** | Can modify workflows (unless CODEOWNERS blocks) | Cannot modify pipelines (architecturally locked) |
| **Execution model** | Parallel by default | Sequential stages |
| **Conditional execution** | Workaround with workflow_run | Built-in stage dependencies |
| **Enforcement** | Required Workflows run in parallel | Stages run sequentially, blocking |
| **Bypass potential** | Can deploy before Required Workflow completes | Cannot proceed to next stage if previous fails |

---

### Harness Template Locking

**Centralized templates** (not in developer repos):
```yaml
# Harness template (platform team controls)
template:
  name: Secure Deployment
  stages:
    - Security Scan (LOCKED)
    - Build (LOCKED)
    - Deploy to Dev (LOCKED)
    - Deploy to Prod (LOCKED, requires approval)
```

**Developers cannot**:
- ❌ Modify template stages
- ❌ Skip security scan
- ❌ Change stage order
- ❌ Add `continue-on-error` equivalent
- ❌ Deploy before security passes

**Platform team controls**:
- ✅ Template stored outside repos
- ✅ Version controlled separately
- ✅ Updates apply to all services
- ✅ Developers use templates via UI/config

---

## Detailed Comparison

### Security Gate Enforcement

| Capability | GitHub Actions + Required Workflows | GitHub Actions + workflow_run | Harness |
|------------|-------------------------------------|-------------------------------|---------|
| **Prevent skipping security** | ✅ Required Workflow runs | ✅ Sequential execution | ✅ Pipeline stages |
| **Prevent continue-on-error** | ✅ Required Workflow enforces failure | ✅ If properly configured | ✅ Stage failure stops pipeline |
| **Prevent workflow modification** | ⚠️ CODEOWNERS (manual review) | ⚠️ CODEOWNERS (manual review) | ✅ Templates locked outside repos |
| **Sequential execution** | ❌ Parallel by default | ⚠️ With workflow_run workaround | ✅ Built-in stage dependencies |
| **Deploy only if security passes** | ❌ Parallel execution gap | ⚠️ With workflow_run + if condition | ✅ Stage blocking |
| **Centralized enforcement** | ✅ Required Workflows org-wide | ❌ Per-repo configuration | ✅ Templates + policies |
| **Scale to 1000 repos** | ⚠️ CODEOWNERS review doesn't scale | ⚠️ Complex workflow_run setup | ✅ Centralized templates |
| **Developer bypass potential** | ⚠️ Can deploy before Required Workflow completes | ⚠️ Can remove workflow_run trigger (if no CODEOWNERS) | ❌ Architecturally impossible |

---

### Verdict by Scenario

#### Scenario 1: Small Team (< 10 repos, high trust)

**GitHub Actions + Required Workflows**: ✅ **WORKS**
- Required Workflows enforce security scans
- CODEOWNERS review is manageable
- Parallel execution gap acceptable with high trust

**Harness**: ⚠️ Overkill for small scale

---

#### Scenario 2: Medium Team (50-200 repos, mixed trust)

**GitHub Actions + Required Workflows**: ⚠️ **WORKS WITH EFFORT**
- Required Workflows enforce scans
- CODEOWNERS review becomes burden (5-10 PRs/day)
- Need workflow_run pattern in each repo
- Parallel execution gap requires process enforcement

**Harness**: ✅ Better at this scale
- Templates prevent bypass architecturally
- No manual review needed
- Sequential execution guaranteed

---

#### Scenario 3: Enterprise (1000+ repos, zero trust)

**GitHub Actions + Required Workflows**: ❌ **DOESN'T SCALE**
- CODEOWNERS review impossible (20-50 PRs/day)
- Parallel execution gap too risky
- workflow_run pattern in 1000 repos = configuration drift
- Manual review doesn't scale

**Harness**: ✅ Purpose-built for this
- Locked templates
- Zero bypass potential
- Sequential enforcement
- Centralized management

---

## Recommendations

### Use GitHub Actions + Required Workflows If:

✅ You have **< 50 repositories**
✅ You have **high trust** in developers
✅ You can accept **parallel execution gap** (deployments may happen before security completes)
✅ You can **manually review** workflow changes via CODEOWNERS
✅ You're willing to implement **workflow_run pattern** in each repo

**Cost**: Low ($50k/year GitHub Enterprise)
**Operational burden**: Medium (CODEOWNERS review, workflow_run setup)

---

### Use Harness If:

✅ You have **1000+ repositories**
✅ You need **zero-trust enforcement** (architecturally prevent bypasses)
✅ You cannot accept **parallel execution gap** (must block deployment if security fails)
✅ You want **centralized template management** (no per-repo configuration)
✅ You need **sequential pipeline stages** (deploy only if security passes)

**Cost**: Higher ($600k/year for 1000 services)
**Operational burden**: Low (templates locked, no manual review needed)

---

## The Honest Answer

### Can developers bypass security gates in GitHub Actions?

**With GitHub Enterprise features (Required Workflows + Rulesets + CODEOWNERS)**:

**NO** - Developers **cannot**:
- ❌ Skip security scans (Required Workflows run automatically)
- ❌ Use continue-on-error to bypass (Required Workflow enforces failure)
- ❌ Bypass branch protection (Organization Rulesets enforced)
- ❌ Merge without security passing (Status checks required)

**YES** - There is **one architectural gap**:
- ⚠️ Deployments can happen **before Required Workflow completes** (parallel execution)
- ⚠️ Vulnerable code can reach production before security scan fails
- ⚠️ Workaround exists (workflow_run) but doesn't scale to 1000 repos

---

### Updated Documentation Statement

**BEFORE** (too broad):
> "Developers can bypass security gates in workflows. GitHub Enterprise can't prevent this architecturally."

**AFTER** (accurate):
> "GitHub Enterprise Required Workflows and Rulesets **prevent most bypass attempts** (skipping scans, continue-on-error, modifying workflows). However, there is **one architectural limitation**: workflows run in **parallel**, allowing deployments to complete **before** Required Workflows finish. This means vulnerable code can reach production before security scans detect issues. Workarounds exist (workflow_run triggers) but require per-repo configuration and don't scale to 1000+ repositories. Harness solves this with sequential pipeline stages that architecturally block deployment until security passes."

---

## Summary Table

| Security Concern | GitHub Actions (Basic) | GitHub Actions (Enterprise) | GitHub + workflow_run | Harness |
|------------------|------------------------|-----------------------------|-----------------------|---------|
| **Skip security scan** | ❌ Easy | ✅ Prevented (Required Workflows) | ✅ Prevented | ✅ Prevented |
| **continue-on-error bypass** | ❌ Easy | ✅ Prevented (Required Workflows) | ✅ Prevented | ✅ Prevented |
| **Modify workflow file** | ❌ Easy | ⚠️ CODEOWNERS review (doesn't scale) | ⚠️ CODEOWNERS review | ✅ Prevented (templates locked) |
| **Deploy before security completes** | ❌ Easy | ⚠️ **POSSIBLE (parallel execution)** | ✅ Prevented (workflow_run) | ✅ Prevented (sequential stages) |
| **Centralized enforcement** | ❌ No | ✅ Yes (Required Workflows) | ❌ Per-repo setup | ✅ Yes (templates) |
| **Scales to 1000 repos** | ❌ No | ⚠️ CODEOWNERS review bottleneck | ❌ Configuration drift | ✅ Yes |

---

## References

[1] [GitHub Docs - Required Workflows](https://docs.github.com/en/actions/using-workflows/required-workflows)

[2] [GitHub Docs - Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

[3] [GitHub Docs - CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)

[4] [GitHub Docs - Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)

[5] [GitHub Docs - Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)

[6] [GitHub Docs - workflow_run trigger](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_run)

---

## Conclusion

**The original claim was too broad.**

**Accurate statement**:
- ✅ GitHub Enterprise **prevents most bypass attempts**
- ✅ Required Workflows **cannot be disabled** by developers
- ✅ Organization Rulesets **enforce security checks**
- ⚠️ **One architectural gap remains**: parallel execution allows deployment before security completes
- ⚠️ Workaround exists but **doesn't scale** to enterprise (1000+ repos)

**For enterprise scale**: Harness's sequential pipeline architecture solves the parallel execution gap architecturally, while GitHub requires per-repo workflow_run configuration and CODEOWNERS review that doesn't scale.

**Both tools are secure** when properly configured. The difference is **operational burden** at scale.
