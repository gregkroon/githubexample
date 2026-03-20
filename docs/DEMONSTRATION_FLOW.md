# Demonstration Flow: GitHub vs Harness for Enterprise CI/CD

**How to present this repository** in meetings, demos, or stakeholder presentations.

---

## Demonstration Formats

### Format A: Executive Briefing (15 min)
**Audience**: Leadership, decision-makers
**Goal**: Business case for Harness over GitHub-native

### Format B: Technical Deep Dive (45 min)
**Audience**: Platform engineers, architects
**Goal**: Understand implementation, gaps, and alternatives

### Format C: Security Review (30 min)
**Audience**: Security teams, compliance
**Goal**: Show governance gaps and enforcement capabilities

### Format D: Live Demo (30 min)
**Audience**: Mixed technical + business
**Goal**: See working example + understand trade-offs

---

## Format A: Executive Briefing (15 min)

### Slide 1: The Question (1 min)
**Show**: README.md title
```
"Can You Build Enterprise CI/CD with GitHub-Native Tooling?"

Short answer: Yes. Should you? It depends.
```

**Say**:
> "We built a complete working implementation to answer this question definitively.
> This is not theoretical - everything you'll see actually runs."

---

### Slide 2: The Working Example (2 min)
**Show**: Open GitHub Actions tab
- Point to recent workflow runs for user-service, payment-service, notification-service
- Show one workflow completing successfully

**Say**:
> "We have 3 production microservices with full CI/CD:
> - Automated security scanning
> - Image signing for supply chain security
> - Policy validation
> - Automated deployment to Kubernetes
>
> This proves GitHub CAN do enterprise CI/CD."

---

### Slide 3: The Problem at Scale (4 min)
**Show**: `docs/QUICK_START_DEMO.md` - Part 2 table

| What You Need | GitHub-Native | Operational Burden |
|---------------|---------------|-------------------|
| Workflows | 1000 files | Update 1000 files for changes |
| Environments | 3000 configs | No centralized management |
| Deployment gates | Custom service | 4 weeks engineering |
| DORA metrics | Custom service | 3 weeks engineering |

**Say**:
> "At 1000 repos, you need:
> - 24 tools that must work together
> - 6 custom services to build (17 weeks of engineering)
> - 3,000 environment configurations with no centralization
> - 2-4 platform engineers just to keep it running"

---

### Slide 4: The Architectural Gap (3 min)
**Show**: `docs/QUICK_START_DEMO.md` - Parallel Execution diagram

```
t=0:   Developer pushes code
t=0:   Required workflow starts (scans filesystem)
t=0:   Developer's workflow starts (builds image, deploys)
t=3m:  Developer's workflow DEPLOYS ✅
t=5m:  Required workflow finds CVE ❌

Result: Vulnerable code ALREADY IN PRODUCTION
```

**Say**:
> "Even with GitHub Enterprise at $400k/year and ALL features enabled,
> there's an architectural gap: workflows run in parallel.
>
> We cannot enforce 'deploy ONLY IF security passes' because
> there's no cross-workflow dependency mechanism."

---

### Slide 5: The Cost (3 min)
**Show**: `docs/QUICK_START_DEMO.md` - Cost Comparison

```
GitHub-Native (5 years): $5,600,000
  - GitHub Enterprise: $2,000k
  - Custom services: $600k
  - Platform engineers (2-4 FTE): $3,000k

Harness Hybrid (5 years): $3,710,000
  - GitHub Team (CI): $460k
  - Harness CD: $2,000k
  - Platform engineers (0.5-1 FTE): $1,250k

Savings: $1,890,000 (34%)
```

**Say**:
> "Over 5 years, the GitHub-native approach costs $1.9 million MORE
> because of the custom engineering and operational burden.
>
> You're not paying Harness for features.
> You're paying them to NOT build 6 custom services."

---

### Slide 6: The Recommendation (2 min)
**Show**: `docs/QUICK_START_DEMO.md` - Recommendation table

```
< 50 repos:       ✅ GitHub-native viable
50-500 repos:     ⚠️  Evaluate resources
1000+ repos:      ✅ Hybrid recommended (GitHub CI + Harness CD)
```

**Say**:
> "Our recommendation:
> - Keep GitHub Actions for CI (it's excellent)
> - Use Harness for CD (purpose-built for scale)
>
> Lower cost, less operational burden, better security enforcement."

**Hand off**: "Questions? Or shall I show you the working example?"

---

## Format B: Technical Deep Dive (45 min)

### Part 1: Show the Working Example (10 min)

**1. Open GitHub Actions tab**
- Show recent workflow runs
- Click into one completed workflow (e.g., CI - User Service)
- Expand jobs to show: Test → Build → Security Scan → SBOM → Sign → Policy

**2. Show a workflow file** (`.github/workflows/ci-user-service.yml`)
```yaml
# Point out the 6 jobs
jobs:
  test:          # Unit tests with coverage
  build:         # Docker build + push to GHCR
  security-scan: # Trivy + Grype scanning
  sbom:          # Software Bill of Materials
  sign:          # Cosign image signing
  policy:        # Conftest/OPA validation
```

**3. Show deployment workflow** (`.github/workflows/cd-user-service.yml`)
- Creates Kind cluster
- Deploys to Kubernetes
- Runs smoke tests

**Say**: "This is real. It runs on every push. Everything works."

---

### Part 2: Demonstrate the Gaps (15 min)

**1. Show CODEOWNERS** (`.github/CODEOWNERS`)
```bash
/.github/workflows/ @platform-team @security-team
```

**Explain**:
- Requires platform team approval for workflow changes
- At 1000 repos: 10-20 PRs/day × 1000 = unsustainable
- Subtle bypasses slip through

**2. Show bypass example** (`docs/DEVELOPER_VS_PLATFORM.md`)
```yaml
# Bypass that passes code review
jobs:
  security-scan:
    continue-on-error: true  # ← Looks like error handling
    steps:
      - uses: trivy-action@master
        with:
          exit-code: 0  # ← Security never fails
```

**3. Show GitHub Enterprise features** (`docs/GITHUB_ENTERPRISE_SETUP.md`)
- Organization Rulesets (`platform/rulesets/organization-production-ruleset.json`)
- Required Workflows (`platform/.github/workflows/required-security-scan.yml`)

**Explain the parallel execution gap**:
```
Required Workflow: Scans filesystem
Developer Workflow: Builds image, deploys

Both triggered by same event → run in parallel
No mechanism to enforce dependencies
```

**4. Show what's still missing** (`docs/GITHUB_GAPS_REAL.md`)
- One-click rollback
- Deployment verification with ML
- Centralized configuration
- Multi-service orchestration

---

### Part 3: GitHub Enterprise Workarounds (10 min)

**Show**: `docs/GITHUB_WORKAROUNDS.md`

**Walk through 2-3 examples**:

**Example 1: Metrics-based verification**
```javascript
// Custom Deployment Protection Rule (must build yourself)
app.post('/evaluate', async (req, res) => {
  const errorRate = await prometheus.query('error_rate');
  if (errorRate > 0.05) {
    return res.json({ state: 'rejected' });
  }
  res.json({ state: 'approved' });
});
```

**Cost**: 3-4 weeks to build, 4-8 hrs/week to maintain

**Example 2: Multi-service orchestration**
- Must build custom orchestrator service
- 4-6 weeks engineering
- 8-12 hrs/week maintenance

**Say**: "Everything is POSSIBLE in GitHub, but you're building a mini-Harness."

---

### Part 4: Harness Comparison (10 min)

**Show**: `docs/HARNESS_COMPARISON.md`

**Side-by-side templates**:

**GitHub** (180 lines per repo):
```yaml
# In EACH repository (1000 copies)
name: CI/CD Pipeline
jobs:
  security-scan:
    # Developer can edit this
```

**Harness** (one template):
```yaml
# Centralized (referenced by all services)
template:
  stages:
    - stage:
        name: Security
        locked: true  # Developers CANNOT modify
        spec:
          imageScan:
            failOnCVE: true
            waitForResults: true  # Blocks deployment
    - stage:
        name: Deploy
        dependsOn: [Security]  # Sequential enforcement
```

**Key differences**:
| Capability | GitHub | Harness |
|------------|--------|---------|
| Template location | In each repo | Centralized |
| Developer modification | Can edit | Locked stages |
| Execution | Parallel | Sequential |
| Configuration | 3000 configs | One template |

---

## Format C: Security Review (30 min)

### Part 1: What We Secure (5 min)

**Show**: Running workflow with security gates

**Walk through**:
1. **Secret scanning** (Gitleaks)
2. **Dependency scanning** (Dependabot, Trivy)
3. **Container scanning** (Trivy, Grype)
4. **SBOM generation** (Syft)
5. **Image signing** (Cosign)
6. **Policy validation** (Conftest/OPA)
7. **Deployment verification** (smoke tests)

**Say**: "We have 17 security gates. Everything is automated."

---

### Part 2: The Governance Gap (15 min)

**Critical**: `docs/DEVELOPER_VS_PLATFORM.md`

**The Two Roles**:
- **Platform Team**: Wants to enforce security
- **Developers**: Control workflow files

**Show the 4 bypass scenarios**:

**Bypass 1: Comment out security job**
```yaml
# jobs:
#   security-scan:
#     ...
```
**Prevention**: CODEOWNERS (requires approval)
**Limitation**: Manual review, doesn't scale

**Bypass 2: Subtle configuration change**
```yaml
jobs:
  security-scan:
    continue-on-error: true
```
**Prevention**: CODEOWNERS (requires approval)
**Limitation**: Reviewer might miss it

**Bypass 3: Conditional skip**
```yaml
jobs:
  security-scan:
    if: "!contains(github.event.head_commit.message, 'skip-security')"
```
**Prevention**: CODEOWNERS (requires approval)
**Limitation**: Looks like reasonable logic

**Bypass 4: Deploy before scanning completes**
```
Required Workflow: Scanning (5 min)
Developer Workflow: Deploy (3 min) ← Finishes first!
```
**Prevention**: None (architectural limitation)
**Limitation**: No cross-workflow dependencies

---

### Part 3: GitHub Enterprise Protections (10 min)

**Show actual configurations**:

**1. CODEOWNERS** (`.github/CODEOWNERS`)
- What it provides: Platform team approval required
- Limitation: Manual review, doesn't scale to 1000 repos

**2. Organization Rulesets** (`platform/rulesets/organization-production-ruleset.json`)
- What it provides: Centralized policies, required status checks
- Limitation: Can't prevent parallel execution

**3. Required Workflows** (`platform/.github/workflows/required-security-scan.yml`)
- What it provides: Org-wide scanning, cannot disable
- Limitations:
  - Runs in parallel with developer workflow
  - Scans filesystem, not Docker images
  - Cannot block deployment

**The bottom line**:
> "GitHub Enterprise provides pre-merge security.
> But deployment-time enforcement requires architectural changes
> that GitHub Actions cannot provide."

**Compare to Harness**:
```yaml
# Harness: Architectural enforcement
stages:
  - Security (locked, scans image, blocks)
  - Deploy (cannot run until Security passes)
```

---

## Format D: Live Demo (30 min)

### Setup (before the demo)
1. Fork the repository to your account
2. Ensure workflows have run at least once
3. Have browser tabs open:
   - GitHub Actions tab
   - GitHub Container Registry (GHCR)
   - `docs/QUICK_START_DEMO.md`
   - `docs/DEVELOPER_VS_PLATFORM.md`

---

### Demo Flow

**1. Show the repository** (2 min)
- "This is a real implementation with 3 microservices"
- Show directory structure: `services/user-service`, `payment-service`, `notification-service`
- "Each has complete CI/CD that actually runs"

**2. Show workflows running** (3 min)
- Open GitHub Actions tab
- Point to recent runs
- "These run automatically on every push"
- Click into one workflow, expand jobs
- "6 jobs: test, build, scan, SBOM, sign, policy"

**3. Make a change and watch it run** (5 min)
```bash
# Edit a file
echo "// Demo change" >> services/user-service/src/index.js

# Commit and push
git add . && git commit -m "Demo: trigger workflow" && git push

# Show workflow starting
# Point out each job executing
```

**4. Show the security gates** (5 min)
- Click into security-scan job
- Show Trivy finding vulnerabilities (or passing)
- Show SBOM generation output
- Show Cosign signature
- "17 security gates, fully automated"

**5. Show the governance gap** (10 min)
- Open `docs/DEVELOPER_VS_PLATFORM.md`
- Show bypass scenario #4 (parallel execution)
- Open `.github/CODEOWNERS` - "Requires approval"
- Open `platform/.github/workflows/required-security-scan.yml`
  - "Runs on all repos, cannot disable"
  - Scroll to bottom comments: "What this doesn't prevent"
- Explain timing race:
  ```
  t=0: Required workflow starts (scans code)
  t=0: Developer workflow starts (builds, deploys)
  t=3m: Deploy completes
  t=5m: Security scan finds CVE ← Too late
  ```

**6. Show the cost comparison** (3 min)
- Open `docs/QUICK_START_DEMO.md`
- Scroll to cost comparison
- "$5.6M vs $3.7M over 5 years"
- "The difference is custom engineering"

**7. Q&A and wrap-up** (2 min)

---

## Handling Common Questions

### "Can't you just use reusable workflows?"
**Answer**: Yes, we do! But you still need:
- 1000 workflow files (one per repo)
- 3000 environment configurations
- Developers can modify or skip reusable workflows
**Show**: `docs/WHY_GITHUB_TEMPLATES_FAIL.md`

### "Can't Required Workflows prevent bypasses?"
**Answer**: They help, but have limitations:
- Run in parallel (cannot block deployment)
- Scan filesystem, not Docker images
- Create status checks, but can't control developer workflow
**Show**: `platform/.github/workflows/required-security-scan.yml` comments

### "What about GitHub Enterprise features?"
**Answer**: We configured them all!
**Show**: `docs/GITHUB_ENTERPRISE_SETUP.md`
- CODEOWNERS: Requires approval (but manual review doesn't scale)
- Organization Rulesets: Centralized policies (but can't prevent parallel execution)
- Required Workflows: Org-wide scanning (but architectural limitations)

### "Can you solve these gaps in GitHub?"
**Answer**: Yes! But at significant cost.
**Show**: `docs/GITHUB_WORKAROUNDS.md`
- Each gap has a workaround
- Each requires custom engineering (weeks to build, hours/week to maintain)
- Total: 17 weeks build + 16-24 hrs/week ongoing

### "Why not just use GitHub for everything?"
**Answer**: We recommend that for < 50 repos!
**Show**: Recommendation by scale
- < 50 repos: GitHub-native viable
- 50-500 repos: Evaluate
- 1000+ repos: Hybrid (GitHub CI + Harness CD)
**Reason**: Total cost of ownership

### "Is this biased toward Harness?"
**Answer**: We tried to be fair:
- Assumed GitHub Enterprise ($400k/year)
- Configured ALL Enterprise features
- Built working examples (not theoretical)
- Showed GitHub workarounds for every gap
- All claims verified with citations
**Show**: `docs/ACCURACY_VERIFICATION.md`

---

## Presentation Tips

### Do's ✅
- Start with the working example (builds credibility)
- Use actual running workflows (not slides)
- Show both capabilities AND limitations
- Be fair to GitHub (we configured everything)
- Focus on scale (1000+ repos)
- Talk about total cost of ownership

### Don'ts ❌
- Don't bash GitHub (it's excellent for CI)
- Don't claim Harness is the only option
- Don't ignore GitHub Enterprise features
- Don't oversell Harness capabilities
- Don't skip the cost analysis
- Don't forget to mention hybrid approach

---

## Follow-Up Materials

After the demonstration, share:

1. **Quick Start Demo**: `docs/QUICK_START_DEMO.md`
2. **Executive Summary**: `docs/EXECUTIVE_SUMMARY.md`
3. **Repository Link**: https://github.com/yourusername/githubexperiment

**Email template**:
```
Subject: GitHub vs Harness - Working Example

Hi [Name],

As discussed, here's the complete working implementation:
https://github.com/yourusername/githubexperiment

Key documents:
- Quick Start (30 min): docs/QUICK_START_DEMO.md
- Executive Summary (15 min): docs/EXECUTIVE_SUMMARY.md
- Essential Reading Guide: docs/ESSENTIAL_READING.md

The repository contains:
- 3 real microservices with working CI/CD
- GitHub Enterprise feature configurations
- Cost analysis ($5.6M vs $3.7M over 5 years)
- Workarounds for every gap

Feel free to fork it and see the workflows run yourself.

Happy to answer any questions!
```

---

**[← Back to README](../README.md)** | **[Quick Start Demo](QUICK_START_DEMO.md)** | **[Essential Reading](ESSENTIAL_READING.md)**
