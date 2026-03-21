# SBOM Enforcement: Theater vs Reality

This document explains what SBOM (Software Bill of Materials) enforcement actually requires, and why generating SBOMs is easy but using them is hard.

## What We Demonstrate

The CI workflow for user-service now includes **real SBOM validation** to show the gap between:
- ✅ **Easy**: Generating SBOMs (automated with Syft)
- ❌ **Hard**: Actually enforcing policies based on SBOM contents

## The Pipeline Flow

```
Build Image
    ↓
Generate SBOM (Syft) ← Easy, automated
    ↓
SBOM Validation ← Hard, requires custom code
    ├─ Check banned packages
    ├─ Check license compliance
    └─ Block deployment if violations found
    ↓
Sign Image (only if SBOM passes)
    ↓
Deploy
```

## What SBOM Validation Does

### 1. Display SBOM Contents

Shows what's actually in your container:
```
Total packages: 847
Top 10 packages:
  express 4.18.2
  body-parser 1.20.1
  winston 3.8.2
  ...
```

### 2. Check for Banned Packages

Checks for known vulnerable versions:
```bash
# Example: Block log4j < 2.17.1 (Log4Shell CVE-2021-44228)
if jq -e '.packages[] | select(.name | test("log4j"))
        | select(.versionInfo | test("^2\\.(0|1[0-6])\\."))'
```

**What this catches:**
- log4j 2.14.1 → ❌ BLOCKED (vulnerable to Log4Shell)
- log4j 2.17.1 → ✅ ALLOWED (patched)

**In production, you'd maintain:**
- List of banned packages/versions
- CVE database integration
- Automatic updates when new vulnerabilities discovered

### 3. Check License Compliance

Checks for licenses incompatible with your business:
```bash
# Example: Block GPL/AGPL in proprietary software
if echo "$LICENSES" | grep -iE "GPL|AGPL|SSPL"
```

**What this catches:**
- MIT, Apache-2.0, BSD → ✅ ALLOWED
- GPL-3.0, AGPL-3.0 → ❌ BLOCKED (requires legal review)

**In production, you'd need:**
- Legal team approval for license policy
- Regular review of new licenses
- Exception process for approved GPL usage

## The Problem: Custom Code Required

Look at `.github/workflows/ci-user-service.yml` lines 160-250.

**Every policy check requires:**
- Custom bash scripting
- jq queries for JSON parsing
- Regex patterns for version matching
- Manual maintenance of banned lists

**This is 90+ lines of custom code** just for basic SBOM validation.

## At Scale: The Real Cost

### For 1 Service (This Demo)
```
✅ SBOM generation: 1 line (uses: anchore/sbom-action@v0)
❌ SBOM validation: 90 lines of custom bash/jq
```

### For 1000 Services
```
Copy 90 lines × 1000 workflows = 90,000 lines
Update banned package list? → Edit 1000 files
New license policy? → Edit 1000 files
CVE database integration? → Build custom service
```

**Time to implement:**
- Write validation logic: 1 week
- Copy to 1000 repos: 2 weeks
- Test and debug: 2 weeks
- **Total: 5 weeks**

**Ongoing maintenance:**
- Update banned packages: 4 hrs/week
- Respond to new CVEs: 8 hrs/incident
- Fix drift across repos: 8 hrs/week
- **Total: 1 FTE**

## What's Missing (vs Purpose-Built Platforms)

| Feature | Current Implementation | What You'd Need | Harness |
|---------|----------------------|-----------------|---------|
| Generate SBOM | ✅ Syft | ✅ Built-in | ✅ Built-in |
| Store SBOM | Artifact only | Centralized database | ✅ Centralized |
| Banned packages | ❌ Manual list in code | CVE database integration | ✅ Integrated |
| License compliance | ❌ Manual regex | Legal policy engine | ✅ Configurable |
| Cross-service queries | ❌ Not possible | Custom database + API | ✅ "What has log4j?" |
| Auto-update policies | ❌ Edit 1000 files | Custom sync service | ✅ One command |
| Block deployment | ⚠️ Demo only | Actually block | ✅ Enforced |
| SBOM attestation | ❌ Not attached | Cosign integration | ✅ Signed & attached |

## Why This Is "Security Theater"

### Current Demo State

The validation runs but **doesn't actually block deployment**:

```bash
if [ "$BANNED_FOUND" = true ]; then
  echo "❌ Deployment blocked due to banned packages"
  echo "NOTE: In this demo, we continue anyway"
  # exit 1  # Commented out!
fi
```

**Why**: We want the demo to complete successfully to show the full pipeline.

### In Production

You'd uncomment `exit 1` to actually block. But then:

**Problem 1**: False positives block legitimate deployments
- Developer productivity drops
- Teams add `continue-on-error: true` to bypass
- Security theater continues

**Problem 2**: Maintenance burden
- New CVE announced → Update 1000 workflows
- Package renamed → Update 1000 regex patterns
- Legal policy changes → Update 1000 license checks

**Problem 3**: No centralized visibility
- "Which services use log4j?" → Check 1000 SBOMs manually
- "Did we patch everywhere?" → No way to know
- Audit request → Download 1000 artifacts

## What Real SBOM Enforcement Looks Like

### Platform Approach (Harness Example)

**Centralized Policy** (once, applies to all 1000 services):
```yaml
# policies/sbom-enforcement.yaml
policies:
  - name: block-vulnerable-packages
    action: DENY_DEPLOYMENT
    rules:
      - package: log4j
        version: "< 2.17.1"
        severity: CRITICAL
        cve: CVE-2021-44228

  - name: license-compliance
    action: REQUIRE_APPROVAL
    rules:
      - license: GPL-3.0|AGPL-3.0
        approvers: ["legal-team"]

sbom:
  generate: true
  attach: true  # Attached to image as attestation
  store: true   # Centralized database
  verify: true  # Check before deployment
```

**Developer Experience**:
- Developers don't see policy code
- Violations show clear error: "Blocked: log4j 2.14.1 (CVE-2021-44228)"
- Can't bypass (locked template)
- Auto-generated exemption workflow

**Platform Team Experience**:
- Update policy once → applies everywhere instantly
- Query: "What has log4j?" → Get answer in seconds
- Dashboard: "847 services patched, 3 pending"
- Audit: Export all SBOMs with one command

## Recommendations

### Current Scale: < 10 Services
✅ **This approach works**
- 90 lines × 10 = 900 lines of validation code
- Manageable to maintain
- Use this demo as-is

### Growing: 10-100 Services
⚠️ **Consider automation**
- Extract validation to reusable workflow
- Centralize banned package list
- Build SBOM query tool

**Time investment**: 4-6 weeks

### Enterprise: 100+ Services
❌ **Don't do this manually**
- Use purpose-built platform (Harness, etc.)
- OR build centralized SBOM service (12+ weeks)

**Cost comparison (500 services, 5 years)**:
- DIY: $2.5M (2 FTE platform engineers)
- Platform: $1.2M (0.5 FTE + licensing)
- **Savings: $1.3M**

## Try It Yourself

### 1. See SBOM Validation in Action

Push a change and watch the CI workflow:
```bash
echo "// Test SBOM" >> services/user-service/src/index.js
git add . && git commit -m "test SBOM validation" && git push
```

In the Actions tab:
- Click "CI - User Service"
- Open "SBOM Validation" job
- See the package list, license checks, and validation summary

### 2. Add a Banned Package Check

Edit `.github/workflows/ci-user-service.yml`:
```bash
# Add check for a package you use
if jq -e '.packages[] | select(.name == "express")' sbom.spdx.json > /dev/null; then
  echo "❌ Express detected - blocked by policy"
  exit 1  # Actually block deployment
fi
```

Push and see deployment blocked.

### 3. Calculate Your Cost

How many services do you have?
- Number of services: __________
- 90 lines of validation × services = __________ lines to maintain
- Update frequency: __________ times/year
- Hours per update: __________ hrs
- Annual maintenance: __________ hours

Convert to FTE and salary cost.

## The Bottom Line

**Generating SBOMs is trivial.**

**Using SBOMs to enforce security is complex.**

At enterprise scale:
- Custom code approach costs 2 FTE
- Purpose-built platform costs 0.5 FTE + licensing
- **Savings: 1.5 FTE = $300k-450k/year**

**The gap isn't the SBOM generation. It's the governance infrastructure.**

---

**See also:**
- [GitHub Workarounds Guide](GITHUB_WORKAROUNDS.md) - All 6 governance requirements
- [Demo Walkthrough](DEMO.md) - Try the complete pipeline
- [Executive Summary](EXECUTIVE_SUMMARY.md) - Business case
