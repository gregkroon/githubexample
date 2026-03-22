# Adversarial Assessment: Challenging the GitHub vs Harness Narrative

**Purpose**: Critical examination of all claims in this repository from a skeptical viewpoint.

**Methodology**: Devil's advocate analysis - what if we're wrong?

---

## 1. The Cost Analysis Is Misleading

### Claim: "$2.05M savings over 5 years with Harness"

**Problems with this claim**:

**1.1 GitHub Enterprise Pricing Is Inflated**

The analysis assumes:
```
GitHub Enterprise: $400k/year
= 1000 users × $21/user/month × 12
```

**Counterargument**:
- You don't need 1000 GitHub licenses for 1000 microservices
- Maybe 200 engineers actually commit code
- 200 × $21 × 12 = **$50,400/year** (not $400k!)
- Difference: **$349,600/year inflated cost**
- Over 5 years: **$1.748M overestimated**

**Corrected 5-year cost**: $5.76M - $1.748M = **$4.01M** (not $5.76M)

**Now Harness looks more expensive**: $4.01M vs $3.71M = only $300k savings

---

**1.2 Harness Pricing Is Underestimated**

The analysis assumes:
```
Harness CD Enterprise: $400k/year
```

**Counterargument**:
- Harness pricing is per-service, not flat rate
- 1000 services × actual enterprise pricing = likely **$600k-800k/year**
- Professional services: $150k one-time is low
- Training: ongoing costs not included
- Support contracts: additional 20% annually
- Integration costs: custom connectors, API work

**Real Harness cost**: Likely $600k-800k/year = **$3M-4M over 5 years** (not $2M)

**Revised 5-year comparison**:
- GitHub (corrected): $4.01M
- Harness (corrected): $4.5M - $6M
- **Harness is now MORE expensive**

---

**1.3 Platform Engineer FTE Estimates Are Wrong**

**Claim**: GitHub requires 2-4 FTE, Harness requires 0.5-1 FTE

**Counterargument**:

**For GitHub**:
- After initial setup, 1-2 FTE is sufficient (not 2-4)
- Most issues are automated after Year 1
- Workflows stabilize, tool updates are quarterly
- **Realistic: 1.5 FTE ongoing**

**For Harness**:
- Still need platform engineers to:
  - Manage Harness configuration
  - Write and maintain templates
  - Integrate with monitoring/alerting
  - Handle Harness upgrades
  - Debug pipeline failures
  - Manage Harness RBAC
  - Respond to developer requests
- **Realistic: 1 FTE minimum, likely 1.5 FTE**

**Savings**: 1.5 FTE vs 1.5 FTE = **zero FTE savings**

---

**1.4 Custom Services Are Exaggerated**

**Claim**: Must build 7 custom services (32 weeks)

**Counterargument**:

**SBOM Enforcement**:
- The "210 lines per service" can be extracted to a **reusable workflow**
- Write once: 2 weeks
- Reference from all repos: 1 line per repo
- Maintenance: same as any shared workflow
- **Actual cost: 2 weeks, not 9 weeks**

**Deployment Gates**:
- Most companies don't need metrics-based gates immediately
- Can start with manual approvals (built-in)
- Add automation incrementally
- **Actual cost: defer or 2 weeks for basic version**

**DORA Metrics**:
- GitHub provides insights out of the box
- Third-party tools (LinearB, Sleuth, Swarmia) cost $10k-50k/year
- **Actual cost: $50k/year vs 3 weeks engineering**

**Multi-Service Orchestrator**:
- How many companies ACTUALLY deploy interdependent services?
- Most microservices are independent
- If needed, use Argo Workflows or Flux (OSS)
- **Actual cost: use existing tools, not custom build**

**Revised custom engineering**:
- SBOM: 2 weeks (reusable workflow)
- Deployment gates: defer or use Harness later
- DORA metrics: $50k/year for tool
- Orchestration: use Argo/Flux if needed
- **Total: 2-4 weeks, not 32 weeks**

---

## 2. The "Parallel Execution Gap" Is Solvable

### Claim: "Cannot enforce 'deploy ONLY IF security passes' - architectural limitation"

**This is misleading.**

**2.1 Solution 1: workflow_run with Conditional Deploy**

```yaml
# Developer workflow
on:
  workflow_run:
    workflows: ["Required Security Scan"]
    types: [completed]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    # Only deploys if security scan passed
```

**This solves the parallel execution problem.**

**2.2 Solution 2: Status Checks**

```yaml
# In repo settings: require status checks
required_status_checks:
  - "Required Security Scan"

# CD workflow
on:
  push:
    branches: [main]

jobs:
  deploy:
    # GitHub won't allow push to main unless status checks pass
```

**2.3 Solution 3: Environment Protection Rules**

```yaml
# In environment settings
required_checks:
  - "Security Scan"
  - "Trivy Scan"
  - "SBOM Validation"

# Deploy job waits for these to pass
```

**Conclusion**: The "architectural limitation" is a **configuration issue, not unsolvable**.

---

## 3. The "Developers Can Bypass Security" Argument Is Weak

### Claim: "Developers can add continue-on-error: true to bypass security"

**3.1 This Is a Process Problem, Not a GitHub Problem**

**If developers can bypass security**:
- Your code review process is broken
- Your CODEOWNERS are not working
- Your organization culture has problems

**This would happen with ANY tool**:
- Harness: Developers could request "emergency bypass" approvals
- Jenkins: Developers could modify Jenkinsfile
- GitLab: Developers could edit .gitlab-ci.yml

**Solution**: Proper CODEOWNERS + Required Workflows
```
# .github/CODEOWNERS
/.github/workflows/ @platform-team @security-team

# Platform maintains Required Workflows
# Developers cannot modify these
```

**With proper governance**: Developers CANNOT bypass

---

**3.2 Harness "Locked Templates" Aren't That Different**

**Claim**: Harness templates are "locked outside developer repos"

**Reality**:
- Harness still requires developers to reference templates
- Developers can create exceptions, request overrides
- Platform team still reviews deployment requests
- Bypass mechanisms exist (emergency deploys, incident response)

**Same governance needed in both**:
- Platform team approval
- Security team review
- Exception process
- Audit trail

**Harness advantage**: Slightly better UX for template management

**Not worth**: $2M+ in licensing

---

## 4. The SBOM Complexity Is Overstated

### Claim: "210 lines per service × 1000 = 210,000 lines of code"

**4.1 This Math Is Dishonest**

**You don't write 210 lines per service.**

**You write it ONCE as a reusable workflow**:

```yaml
# .github/workflows/reusable-sbom-enforcement.yml (210 lines, write once)

# Each service (1 line):
jobs:
  sbom:
    uses: org/.github/.github/workflows/reusable-sbom-enforcement.yml@main
```

**Actual code to maintain**: 210 lines total (not 210,000)

**Maintenance**: Update one file, applies to all 1000 services

**This is how GitHub Actions is designed to work.**

---

**4.2 Harness "Zero Lines" Is Also Dishonest**

**Claim**: Harness SBOM enforcement is "config-driven, zero lines"

**Reality**:

Harness still requires:
- Writing YAML templates
- Configuring policy rules
- Integrating with SBOM tools
- Setting up verification steps
- Maintaining policy database

**Example Harness config**:
```yaml
# Still need to write this
template:
  sbom:
    generate:
      tool: syft
      format: spdx-json
    validate:
      policies:
        - name: banned-packages
          rules:
            - package: "log4j"
              version: "<2.17.1"
              action: BLOCK
        - name: license-compliance
          rules:
            - license: "GPL-3.0|AGPL-3.0"
              action: REQUIRE_APPROVAL
    attest:
      enabled: true
      tool: cosign
      keyless: true
    verify:
      enabled: true
      failOnError: true
```

**Line count**: 50-100 lines of YAML

**Plus**: Learning Harness DSL, debugging Harness issues, Harness upgrades

**Claim of "zero lines" is marketing BS.**

---

**4.3 Cosign Complexity Exists Regardless**

**The analysis says**:
- Cosign is complex
- OIDC is hard
- Sigstore requires expertise

**But**:
- Harness uses Cosign under the hood
- OIDC tokens still needed
- Sigstore infrastructure still required

**You don't escape complexity by using Harness.**

**You just pay someone to abstract it** (for $400k-800k/year).

---

## 5. The Scale Assumption Is Questionable

### Claim: "At 1000+ microservices..."

**5.1 How Many Companies Have 1000 Microservices?**

**Reality check**:
- Netflix: ~800 microservices
- Uber: ~2200 microservices
- Amazon: ~thousands (not public)

**Most companies**:
- Series A-B: 5-20 services
- Series C: 20-100 services
- Public companies: 100-500 services

**Companies with 1000+ services**: Maybe 50-100 globally

**This analysis is relevant to**: 0.001% of companies

---

**5.2 At What Scale Does This Matter?**

**Let's recalculate for realistic scales**:

**100 services** (most public companies):
- GitHub licenses: 50 users × $21 = $12,600/year
- Custom code: Reusable workflows = 2 weeks
- Platform engineers: 1 FTE
- 5-year cost: **$1.2M**

**Harness**:
- 100 services × pricing = $100k-150k/year
- Platform engineers: 1 FTE (still needed)
- 5-year cost: **$1.75M**

**At 100 services, GitHub is cheaper.**

**Break-even point**: Probably 500-800 services (not 1000)

---

## 6. Missing Context and Hidden Costs

### 6.1 What This Analysis Doesn't Mention

**GitHub Advantages Not Discussed**:
- ✅ Native integration with GitHub (no sync issues)
- ✅ Developer familiarity (GitHub Actions is standard)
- ✅ Massive ecosystem (thousands of actions)
- ✅ No vendor lock-in (workflows are portable)
- ✅ Built-in security scanning (CodeQL, Dependabot free)
- ✅ OIDC for cloud providers (AWS, Azure, GCP)
- ✅ Matrix builds (parallel jobs, free compute)

**Harness Disadvantages Not Discussed**:
- ❌ Vendor lock-in (proprietary YAML DSL)
- ❌ Migration cost if you want to leave
- ❌ Learning curve (new tool for developers)
- ❌ Integration complexity (GitHub → Harness handoff)
- ❌ Dependency on Harness SaaS uptime
- ❌ Feature gaps (Harness may not do everything GitHub can)
- ❌ Support costs (enterprise support contracts)

---

**6.2 Hidden Harness Costs**

**The analysis doesn't include**:
- **Training**: $50k-100k (workshops, certifications)
- **Migration**: 6-12 months to migrate 1000 services
- **Integration engineering**: Custom connectors, API work
- **Monitoring**: Harness-specific observability tools
- **Incident response**: New tool in critical path
- **Annual true-ups**: License overages
- **Professional services**: Ongoing consulting

**Estimated hidden costs**: $200k-500k over 5 years

---

**6.3 GitHub Enterprise Features Not Used**

**This analysis doesn't leverage**:
- **Enterprise Managed Users** (centralized auth)
- **Organization Rulesets** (centralized policies)
- **Required Workflows** (enforced scans)
- **Deployment Protection Rules** (custom gates via GitHub Apps)
- **Actions Runner Controller** (K8s-native runners)
- **Larger runners** (8-core, 32GB RAM machines)

**With these features**: Many "must build" services are **unnecessary**

---

## 7. The Comparison Is Biased

### 7.1 Strawman Argument

**This repo compares**:
- ❌ GitHub (poorly configured, no reusable workflows, manual everything)
- ✅ Harness (perfectly configured, best practices, all features)

**A fair comparison**:
- ✅ GitHub (reusable workflows, enterprise features, proper governance)
- ✅ Harness (realistic pricing, hidden costs, learning curve)

---

**7.2 The Demo Is Designed to Make GitHub Look Bad**

**Example biases**:

1. **SBOM code is duplicated** (should be reusable workflow)
2. **No use of composite actions** (further reduce duplication)
3. **Manual environment setup** (could be automated with Terraform/Pulumi)
4. **Secrets are "15,000 to configure manually"** (ignoring Vault integration, OIDC)
5. **Parallel execution shown as unsolvable** (ignoring workflow_run solution)

---

**7.3 Harness Is Presented As Perfect**

**Claims about Harness**:
- "Zero lines of code" (false - still need YAML config)
- "Built-in verification" (still need to configure it)
- "One-click rollback" (still need to define what "previous version" means)
- "ML-based deployment verification" (requires training data, tuning)

**Reality**: Harness has its own complexity, just different complexity.

---

## 8. Alternative Solutions Not Considered

### 8.1 Other CD Tools Ignored

**Why only Harness?**

**Alternatives**:
- **Argo CD** (open source, free, K8s-native)
- **Flux CD** (open source, free, GitOps)
- **Spinnaker** (open source, Netflix, multi-cloud)
- **GitLab** (all-in-one, $99/user/year)
- **Jenkins X** (open source, K8s-native)

**Cost comparison**:
- Argo CD: $0 (open source) + 1 FTE = $1M over 5 years
- **Savings vs Harness**: $2.7M

**Why isn't this compared?**

---

**8.2 Hybrid Approaches**

**The analysis presents**:
- Option A: GitHub only
- Option B: GitHub CI + Harness CD

**What about**:
- Option C: GitHub + Argo CD (save $2M)
- Option D: GitHub + Spinnaker (save $2M)
- Option E: GitHub + custom thin orchestrator (2 weeks, not 32)

---

## 9. Real-World Counterexamples

### 9.1 Companies Using GitHub Actions at Scale

**Companies successfully using GitHub Actions for 100+ services**:
- **Shopify** (1000+ repos)
- **HashiCorp** (500+ repos)
- **Stripe** (hundreds of repos)
- **GitHub itself** (thousands of repos)

**How do they do it?**
- Reusable workflows
- Composite actions
- Organization-wide policies
- Proper CODEOWNERS
- Required Workflows

**They are NOT spending $5.76M over 5 years.**

---

**9.2 Companies That Left Harness**

**Reasons companies leave Harness**:
- Cost too high
- Feature gaps vs expectations
- Vendor lock-in concerns
- Integration complexity
- Simpler alternatives (Argo, Flux)

**Where did they go?**
- Back to GitHub Actions (with better configuration)
- Open source tools (Argo, Flux)
- GitLab (all-in-one)

---

## 10. What This Analysis Gets Right

**To be fair, these points are valid**:

### 10.1 Configuration Sprawl Is Real

**At 1000 repos, configuration drift is a problem.**

**But**:
- Reusable workflows reduce this (not mentioned)
- IaC can automate environment setup (not mentioned)
- Organization Rulesets centralize policies (underutilized)

### 10.2 Approval Gates Are Manual

**GitHub environment approvals are manual only.**

**But**:
- Most companies want manual approvals for production
- Custom gates can be built with Deployment Protection Rules (not explored)
- Third-party integrations exist (PagerDuty, etc.)

### 10.3 Secret Management Could Be Better

**15,000 secrets via UI is painful.**

**But**:
- GitHub integrates with Vault (not mentioned)
- OIDC eliminates many secrets (not emphasized)
- Terraform can automate secret setup (not mentioned)

### 10.4 No One-Click Rollback

**This is true and a legitimate gap.**

**But**:
- Most rollbacks are "redeploy previous version" (achievable with GitHub)
- "One-click" requires knowing what "previous good state" is
- Harness still requires configuration for this

---

## 11. The Verdict: Is This Repo Honest?

### 11.1 Biased But Educational

**What it does well**:
- ✅ Shows a complete working implementation
- ✅ Demonstrates GitHub Actions capabilities
- ✅ Highlights real limitations (manual approvals, environment config)
- ✅ Provides hands-on demo

**What it misleads on**:
- ❌ Cost analysis (inflated GitHub, understated Harness)
- ❌ FTE estimates (exaggerated for GitHub, optimistic for Harness)
- ❌ Custom code requirements (210k lines is dishonest math)
- ❌ Parallel execution (solvable, presented as unsolvable)
- ❌ Ignores reusable workflows (critical GitHub feature)
- ❌ Ignores alternative tools (Argo, Flux, GitLab)

---

### 11.2 Who Benefits From This Narrative?

**This analysis benefits**:
- Harness sales team (obviously)
- Consulting firms (selling Harness implementations)
- Enterprise software vendors (complexity justifies cost)

**This analysis harms**:
- Platform engineers (told their work is "210k lines of unmaintainable code")
- GitHub (shown in worst possible light)
- Open source tools (not even considered)

---

### 11.3 The Actual Recommendation

**For < 200 repos**:
- ✅ GitHub Actions (CI + CD)
- ✅ Use reusable workflows
- ✅ Use OIDC for secrets
- ✅ Use organization rulesets
- **Cost**: ~$1M over 5 years

**For 200-500 repos**:
- ✅ GitHub Actions (CI)
- ✅ Argo CD or Flux (CD) - FREE
- **Cost**: ~$1.2M over 5 years
- **Saves**: $2.5M vs Harness

**For 500-1000+ repos**:
- ⚠️ Evaluate Harness (if budget allows)
- ✅ Or: GitHub + Argo + proper governance
- **Cost**: $2-3M over 5 years (GitHub + OSS)
- **Saves**: $1-2M vs Harness

**For 1000+ repos** (if you're Netflix/Uber):
- ✅ Build custom platform (you have the resources)
- ✅ Or: GitHub + Argo/Flux + dedicated team
- **Cost**: $3-4M over 5 years
- **Saves**: $1-2M vs Harness

---

## 12. Corrected Cost Analysis

### 12.1 Realistic GitHub-Native (1000 services)

```
Year 1:
  GitHub Enterprise: $50k (200 users, not 1000)
  Reusable workflows: $40k (2 weeks × 2 engineers)
  Environment automation (Terraform): $40k (2 weeks)
  Platform engineers (1.5 FTE): $300k
  ─────────────────────────────────────
  Total: $430k

Years 2-5:
  GitHub Enterprise: $50k/year
  Workflow maintenance: $20k/year
  Platform engineers (1.5 FTE): $300k/year
  ─────────────────────────────────────
  Total: $370k/year

5-Year Total: $1,910,000
```

### 12.2 Realistic Harness Hybrid (1000 services)

```
Year 1:
  GitHub Team (CI): $50k (200 users)
  Harness Enterprise: $600k (realistic pricing)
  Professional services: $200k (realistic)
  Training: $100k
  Integration engineering: $100k
  Platform engineers (1.5 FTE): $300k
  ─────────────────────────────────────
  Total: $1,350k

Years 2-5:
  GitHub Team: $50k/year
  Harness licenses: $600k/year
  Harness support (20%): $120k/year
  Platform engineers (1.5 FTE): $300k/year
  ─────────────────────────────────────
  Total: $1,070k/year

5-Year Total: $5,630,000
```

### 12.3 Corrected Comparison

| Approach | 5-Year Cost | Savings |
|----------|-------------|---------|
| GitHub-Native (corrected) | **$1,910,000** | Baseline |
| Harness Hybrid (corrected) | **$5,630,000** | -$3,720,000 (195% more expensive) |
| GitHub + Argo CD | **$1,910,000** | Same as GitHub-native |

**Conclusion**: Harness is **$3.72M MORE expensive** than GitHub (opposite of repo claim)

---

## 13. Final Assessment

### What This Repo Claims:
> "GitHub costs $2.05M MORE than Harness over 5 years"

### Adversarial Assessment:
> "Harness likely costs $3.72M MORE than GitHub when using realistic numbers and proper GitHub configuration"

### The Truth Is Probably:
**It depends on your specific context**:

- **Actual number of users** (not services)
- **Quality of platform engineering team**
- **Willingness to use reusable workflows**
- **Need for advanced features** (canary, verification)
- **Budget constraints**
- **Vendor lock-in tolerance**

**For most companies**: GitHub + proper configuration + Argo/Flux is the most cost-effective

**For companies with unlimited budget**: Harness provides convenience (at 3-5× cost)

**For companies at Netflix/Uber scale**: Build custom (you have the resources)

---

## 14. Recommendations for Repo Improvement

**To make this analysis more honest**:

1. ✅ **Add reusable workflow examples** (this is critical missing piece)
2. ✅ **Show workflow_run solution** for parallel execution
3. ✅ **Include realistic user counts** (not 1:1 with services)
4. ✅ **Add Argo CD / Flux comparison** (open source alternatives)
5. ✅ **Show Terraform for environment automation**
6. ✅ **Correct Harness pricing** (show realistic enterprise costs)
7. ✅ **Add "Companies using GitHub at scale" section**
8. ✅ **Acknowledge Harness vendor lock-in risks**
9. ✅ **Show composite actions** (further reduce duplication)
10. ✅ **Add "What we got wrong" section**

**Without these additions**: This repo is a **Harness sales pitch disguised as analysis**

---

## 15. What Question Should Actually Be Asked?

**Not**: "Can you build enterprise CI/CD with GitHub?"

**But**: "What is the right CI/CD architecture for YOUR scale and constraints?"

**The answer varies**:
- Startup (< 10 services): GitHub Actions all the way
- Growth (10-100 services): GitHub Actions + maybe Argo CD
- Scale (100-500 services): GitHub Actions + Argo/Flux + governance
- Enterprise (500+ services): Evaluate Harness vs custom platform
- Mega-scale (1000+ services): You're Netflix/Uber, build custom

**One size does NOT fit all.**

**This repo suggests**: "Everyone should use Harness at scale"

**Reality**: "It depends, and open source alternatives exist"

---

## Conclusion

**This repository is**:
- ✅ Technically impressive (working implementation)
- ✅ Educational (shows GitHub features)
- ⚠️ Financially misleading (cost analysis flawed)
- ❌ Architecturally incomplete (ignores reusable workflows)
- ❌ Comparison biased (GitHub worst-case vs Harness best-case)

**Corrected conclusion**:
> "GitHub can do enterprise CI/CD at 1000+ repos, and with proper configuration (reusable workflows, OIDC, IaC), it's likely $2-4M CHEAPER than Harness over 5 years."

**The gap is NOT operational efficiency.**

**The gap is configuration expertise.**

**You're not paying Harness for features.**

**You're paying Harness to avoid learning GitHub properly.**

---

**Value of this adversarial assessment**: Challenges readers to think critically about vendor claims and cost analyses.
