# GitHub Enterprise Setup Guide - Enabling All Security Features

**This guide shows how to configure ALL GitHub Enterprise features** to provide the maximum possible security enforcement at scale (1000+ repos).

> ⚠️ **Cost**: GitHub Enterprise Cloud costs ~$400,000/year for 1000 users
> **This guide assumes you have GitHub Enterprise Cloud with Advanced Security enabled.**

---

## Prerequisites

**Required**:
- GitHub Enterprise Cloud organization
- GitHub Advanced Security enabled
- Organization owner permissions
- 1000 repositories to manage

**Cost Breakdown**:
- GitHub Enterprise Cloud: $21/user/month
- 1000 users × $21 × 12 months = $252,000/year
- Advanced Security: Included
- Additional compute for Required Workflows: ~$148,000/year (estimated)
- **Total: ~$400,000/year**

---

## Step 1: Enable Organization-Wide Features

### 1.1 Enable GitHub Advanced Security

```bash
# Via GitHub UI:
Organization Settings → Code security and analysis
→ Enable GitHub Advanced Security for all repositories
→ Enable Dependency graph
→ Enable Dependabot alerts
→ Enable Dependabot security updates
→ Enable Code scanning
→ Enable Secret scanning
```

**What this provides**:
- ✅ Automated vulnerability scanning
- ✅ Secret detection in commits
- ✅ Dependency security alerts

**What this DOESN'T provide**:
- ❌ Deployment-time enforcement
- ❌ Prevention of deployment bypasses

---

## Step 2: Configure CODEOWNERS

### 2.1 Create CODEOWNERS File

In EACH repository (or use a template):

```bash
# Location: .github/CODEOWNERS

# Workflow files require platform team approval
/.github/workflows/ @your-org/platform-team @your-org/security-team

# Deployment manifests require platform team approval
**/Dockerfile @your-org/platform-team
**/k8s/ @your-org/platform-team
```

### 2.2 Enable CODEOWNERS Enforcement

```bash
# Via GitHub UI (per repository):
Settings → Branches → Branch protection rules → main
→ ✅ Require pull request reviews before merging
→ ✅ Require review from Code Owners
→ ✅ Dismiss stale pull request approvals when new commits are pushed
```

### 2.3 Automate Across 1000 Repos

```bash
#!/bin/bash
# Script to add CODEOWNERS to all repos

ORG="your-org"
REPOS=$(gh repo list $ORG --limit 1000 --json name -q '.[].name')

for repo in $REPOS; do
  echo "Adding CODEOWNERS to $repo..."

  # Clone repo
  gh repo clone $ORG/$repo temp/$repo
  cd temp/$repo

  # Add CODEOWNERS
  mkdir -p .github
  cp /path/to/CODEOWNERS .github/CODEOWNERS

  # Commit and push
  git add .github/CODEOWNERS
  git commit -m "Add CODEOWNERS for security governance"
  git push origin main

  cd ../..
  rm -rf temp/$repo
done
```

**Time to deploy**: ~8-10 hours for 1000 repos
**Ongoing maintenance**: Update when team structure changes

**What this provides**:
- ✅ Platform team must approve workflow changes
- ✅ Blocks obvious bypasses (commented out jobs)

**What this DOESN'T prevent**:
- ❌ Subtle bypasses (continue-on-error: true)
- ❌ Scale issues (manual review of 1000 repos)
- ❌ Context switching fatigue
- ❌ Reviewers missing small changes in large PRs

---

## Step 3: Create Organization Rulesets

### 3.1 Create Ruleset via UI

```bash
# Via GitHub UI:
Organization Settings → Rules → Rulesets → New ruleset

Name: Production Branch Protection
Enforcement: Active
Target: Branches matching "main", "master", "production"

Rules:
  ✅ Require pull request
     - 2 approving reviews
     - Require review from code owners
     - Dismiss stale reviews

  ✅ Require status checks to pass
     - Required Security Scan
     - Required SBOM Generation
     - Required Policy Validation

  ✅ Require workflows to pass
     - .github/workflows/required-security-scan.yml

  ✅ Block force pushes
  ✅ Require linear history
```

### 3.2 Alternative: API Configuration

```bash
# Using GitHub API
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/orgs/YOUR_ORG/rulesets \
  -d @platform/rulesets/organization-production-ruleset.json
```

**What this provides**:
- ✅ Centralized policy management
- ✅ Applies to all current and future repos
- ✅ Enforces required status checks
- ✅ Requires code owner approval

**What this DOESN'T prevent**:
- ❌ Developer's workflow running in parallel with required workflow
- ❌ Deployment before required workflow completes
- ❌ Bypasses in developer's own workflow logic

---

## Step 4: Deploy Required Workflows

### 4.1 Create Organization-Private Repository

```bash
# This is a special repository recognized by GitHub
gh repo create your-org/.github-private --private

cd .github-private
mkdir -p .github/workflows
```

### 4.2 Add Required Workflow

```bash
# Copy the required security workflow
cp /path/to/platform/.github/workflows/required-security-scan.yml \
   .github/workflows/required-security-scan.yml

# Commit and push
git add .github/workflows/required-security-scan.yml
git commit -m "Add required security scanning workflow"
git push origin main
```

### 4.3 Configure Organization Settings

```bash
# Via GitHub UI:
Organization Settings → Actions → General
→ Required workflows
→ Add workflow: .github/workflows/required-security-scan.yml
→ Repository: your-org/.github-private
→ Apply to: All repositories
```

**What this provides**:
- ✅ Automatic security scanning on ALL repos
- ✅ Developers cannot disable or bypass
- ✅ Creates status checks used by rulesets
- ✅ Centralized workflow management

**What this DOESN'T prevent**:
- ❌ **Critical**: Runs in PARALLEL with developer's workflow
- ❌ **Critical**: Cannot block deployment in developer's workflow
- ❌ **Critical**: Scans filesystem, not Docker images
- ❌ **Critical**: No cross-workflow dependency mechanism

**The architectural limitation**:

```
t=0:    Developer pushes code
t=0:    Required workflow starts (scans filesystem)
t=0:    Developer's workflow starts (builds image, deploys)
t=3min: Developer's workflow DEPLOYS ✅
t=5min: Required workflow finds CVE ❌

Result: Vulnerable code ALREADY IN PRODUCTION
```

**Why**: GitHub Actions has no cross-workflow dependency mechanism.
Two workflows triggered by the same event run independently and in parallel.

---

## Step 5: Configure Branch Protection (Redundant but Recommended)

Even with Organization Rulesets, configure Branch Protection as defense in depth:

### 5.1 Via Terraform (Scales Better)

```hcl
# terraform/branch-protection.tf

resource "github_branch_protection" "main" {
  for_each = toset(var.repositories)

  repository_id = each.value
  pattern       = "main"

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
    required_approving_review_count = 2
    require_last_push_approval      = true
  }

  required_status_checks {
    strict   = true
    contexts = [
      "Required Security Scan",
      "Required SBOM Generation",
      "Required Policy Validation"
    ]
  }

  enforce_admins = false
  allows_deletions = false
  allows_force_pushes = false
  require_signed_commits = true
  required_linear_history = true
}
```

```bash
# Deploy to all 1000 repos
terraform apply

# Time: ~2-3 hours
# Cost: One-time configuration, updates via Terraform
```

---

## Step 6: Enable Additional Security Features

### 6.1 Secret Scanning

```bash
# Via GitHub UI:
Organization Settings → Code security
→ Enable secret scanning for all repositories
→ Enable secret scanning push protection
```

### 6.2 Dependency Review

```bash
# Already included in Required Workflow
# Automatically runs on all PRs
```

### 6.3 Code Scanning (CodeQL)

```bash
# Add to .github-private required workflow:
- name: Initialize CodeQL
  uses: github/codeql-action/init@v3
  with:
    languages: javascript, python, go

- name: Perform CodeQL Analysis
  uses: github/codeql-action/analyze@v3
```

---

## Step 7: Monitoring and Compliance

### 7.1 Security Dashboard

```bash
# View organization-wide security status:
https://github.com/organizations/YOUR_ORG/security
```

### 7.2 Compliance Reporting

```bash
# Export security data via API
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/orgs/YOUR_ORG/dependabot/alerts
```

### 7.3 Audit Logs

```bash
# Track who modified security settings
Organization Settings → Audit log
Filter by: security, workflows, rulesets
```

---

## Summary: What You've Deployed

### ✅ Enabled Features (All GitHub Enterprise)

| Feature | Enabled | Purpose |
|---------|---------|---------|
| **Advanced Security** | ✅ | CVE scanning, secret detection |
| **CODEOWNERS** | ✅ | Require platform team approval |
| **Organization Rulesets** | ✅ | Centralized policy enforcement |
| **Required Workflows** | ✅ | Org-wide security scanning |
| **Branch Protection** | ✅ | Per-repo enforcement |
| **Secret Scanning** | ✅ | Detect exposed credentials |
| **Dependency Review** | ✅ | Alert on vulnerable deps |
| **Code Scanning (CodeQL)** | ✅ | SAST analysis |

**Total Configuration Time**: ~20-30 hours
**Ongoing Maintenance**: 8-12 hours/week
**Annual Cost**: ~$400,000 (GitHub Enterprise)

---

## What's STILL Missing (Architectural Gaps)

Even with ALL features enabled:

### ❌ Gap 1: Parallel Workflow Execution

```yaml
# Required workflow (org-level)
name: Required Security
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - run: trivy scan  # Scans filesystem

# Developer's workflow (repo-level)
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: docker build
      - run: docker push
      - run: kubectl apply  # Deploys in parallel!
```

**Problem**: Both workflows run simultaneously. No dependency mechanism.

### ❌ Gap 2: Cannot Scan Docker Images

```
Required workflow scans: Source code (filesystem)
Developer builds: Docker image (after checkout)
Required workflow cannot: Scan what doesn't exist yet
```

### ❌ Gap 3: Cannot Block Deployments

```yaml
# Developer's deploy job
deploy:
  runs-on: ubuntu-latest
  # NO WAY to require required workflow completion
  steps:
    - run: kubectl apply  # Runs regardless
```

### ❌ Gap 4: Subtle Bypasses Still Possible

```yaml
# Passes code review but bypasses security
jobs:
  security-scan:
    continue-on-error: true  # ← Looks like error handling
    steps:
      - uses: trivy-action@master
        with:
          exit-code: 0  # ← Never fails
```

Reviewer approves (looks reasonable) → Security bypassed

### ❌ Gap 5: Configuration Still Distributed

| What | Where | Count |
|------|-------|-------|
| Required Workflows | .github-private repo | 1 (centralized ✅) |
| Organization Rulesets | Organization settings | 1 (centralized ✅) |
| Developer Workflows | Each repository | 1000 (distributed ❌) |
| GitHub Environments | Each repository | 3000 (distributed ❌) |
| Deployment Logic | Developer workflows | 1000 (developer-controlled ❌) |

**Result**: Even with centralized policies, deployment logic is still distributed and developer-controlled.

---

## Compare to Harness

### What You Had to Do (GitHub Enterprise)

1. Enable Advanced Security across org
2. Create and deploy CODEOWNERS to 1000 repos
3. Configure Organization Rulesets
4. Create .github-private repository
5. Deploy Required Workflows
6. Configure Branch Protection (1000 repos)
7. Set up monitoring and compliance
8. Write scripts to maintain consistency
9. **Still have architectural gaps**

**Time**: 20-30 hours initial + 8-12 hours/week ongoing
**Cost**: $400k/year + 2-4 FTE

### What You'd Do (Harness)

```yaml
# One template, applies to all services
template:
  name: Production Deployment
  stages:
    - stage:
        name: Security
        locked: true  # Developers cannot modify
        spec:
          imageScan:
            tool: Trivy
            failOnCVE: true
            waitForResults: true  # Blocks next stage

    - stage:
        name: Deploy
        dependsOn: [Security]  # Cannot run until security passes
        locked: true
        spec:
          approval:
            required: true
            approvers: [platform-team]
```

**Time**: 2-4 hours initial + 2-4 hours/week ongoing
**Cost**: $400k/year + 0.5-1 FTE
**No architectural gaps**: Deployment cannot proceed without security passing

---

## Recommendation

### When GitHub Enterprise Works

**< 50 repositories**:
- ✅ Manual review via CODEOWNERS is manageable
- ✅ Platform team can monitor 50 repos
- ✅ Configuration drift is manageable

### When GitHub Enterprise Struggles

**1000+ repositories**:
- ❌ Manual review doesn't scale
- ❌ Subtle bypasses slip through
- ❌ Parallel execution allows races
- ❌ Cannot enforce deployment-time policies
- ❌ 2-4 FTE required just to maintain

**At this scale**: Architectural enforcement (Harness) more cost-effective than process-based enforcement (GitHub).

---

## Conclusion

**We've shown that even with GitHub Enterprise and ALL features enabled:**
- ✅ You get powerful pre-merge security
- ✅ You get organization-wide policies
- ❌ **You still have the parallel execution gap**
- ❌ **You still can't enforce deployment-time policies**
- ❌ **Developers still control deployment logic**

**This is not a GitHub limitation - it's an architectural difference.**

GitHub Actions workflows run in parallel.
Harness pipeline stages run sequentially.

**At enterprise scale, sequential enforcement > parallel enforcement.**

---

**[← Back to README](../README.md)** | **[See Gaps Analysis](GITHUB_GAPS_REAL.md)** | **[Developer vs Platform](DEVELOPER_VS_PLATFORM.md)**
