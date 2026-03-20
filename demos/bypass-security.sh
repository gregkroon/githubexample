#!/bin/bash
#
# Demonstration: How Developers Can Bypass Security in GitHub
#
# This script shows how EASY it is for a developer to bypass security scanning
# in GitHub Actions workflows.
#
# ⚠️  WARNING: This is for demonstration purposes ONLY.
#     In a real environment, this would be caught by:
#     - Code review (if platform team reviews)
#     - CODEOWNERS enforcement (if configured)
#     - Branch protection (if properly configured)
#
#     But at 1000 repos, manual review doesn't scale.
#

set -e

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     Demonstration: Bypassing Security in GitHub Workflows        ║"
echo "║     (Assuming GitHub Enterprise with ALL Features Enabled)       ║"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo ""
echo "⚠️  NOTE: This assumes GitHub Enterprise with:"
echo "   - Required Workflows"
echo "   - Organization Rulesets"
echo "   - Advanced Security"
echo "   - CODEOWNERS enforcement"
echo ""
echo "   Even with all Enterprise features, bypasses are still possible."
echo ""

# Check if we're in the right directory
if [ ! -f ".github/workflows/ci-user-service.yml" ]; then
    echo "❌ Error: Must run from repository root"
    echo "   cd /path/to/githubexperiment && ./demos/bypass-security.sh"
    exit 1
fi

echo "📋 Current Security Workflow"
echo "═════════════════════════════"
echo ""
echo "The workflow currently has these security gates:"
grep -A 5 "security-scan:" .github/workflows/ci-user-service.yml | head -6
echo ""

read -p "Press ENTER to see bypass options..."
echo ""

echo "🔓 Bypass Option 1: Skip Security Scanning"
echo "═══════════════════════════════════════════"
echo ""
echo "A developer could simply add:"
echo ""
cat <<'EOF'
  security-scan:
    continue-on-error: true  # ← BYPASS: Never fail, even with CVEs
EOF
echo ""

read -p "Press ENTER to see next bypass..."
echo ""

echo "🔓 Bypass Option 2: Remove Job Entirely"
echo "════════════════════════════════════════"
echo ""
echo "Or just comment out the entire security-scan job:"
echo ""
cat <<'EOF'
# jobs:
#   security-scan:
#     name: Security Scanning
#     ...
EOF
echo ""

read -p "Press ENTER to see next bypass..."
echo ""

echo "🔓 Bypass Option 3: Change Exit Code"
echo "═════════════════════════════════════"
echo ""
echo "Or modify Trivy to never fail:"
echo ""
cat <<'EOF'
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.image.outputs.tag }}
          severity: 'CRITICAL,HIGH'
          exit-code: 0  # ← BYPASS: Was 1, now never fails
EOF
echo ""

read -p "Press ENTER to see next bypass..."
echo ""

echo "🔓 Bypass Option 4: Skip on Commit Message"
echo "═══════════════════════════════════════════"
echo ""
echo "Or add conditional skip:"
echo ""
cat <<'EOF'
  security-scan:
    if: "!contains(github.event.head_commit.message, 'skip-security')"
EOF
echo ""
echo "Then commit with: git commit -m 'Quick fix skip-security'"
echo ""

read -p "Press ENTER to see what GitHub Enterprise provides..."
echo ""

echo "🛡️  What GitHub Enterprise Provides"
echo "═══════════════════════════════════"
echo ""
echo "✅ 1. Required Workflows (Enterprise):"
echo "   - Platform team defines org-wide security workflows"
echo "   - Automatically runs on all 1000 repos"
echo "   - Scans code before merge"
echo "   ⚠️  But: Runs in PARALLEL with developer's workflow"
echo "   ⚠️  But: Cannot block developer's deploy job"
echo ""
echo "✅ 2. Organization Rulesets (Enterprise):"
echo "   - Enforce status checks across all repos"
echo "   - Require specific checks to pass"
echo "   ⚠️  But: Status checks come from developer's workflow"
echo "   ⚠️  But: If developer removes job, check never created"
echo ""
echo "✅ 3. CODEOWNERS (Enterprise):"
echo "   - Require platform team approval for workflow changes"
echo "   ⚠️  But: Manual review of 1000 repos doesn't scale"
echo "   ⚠️  But: Subtle bypasses (continue-on-error) slip through"
echo ""
echo "✅ 4. Branch Protection (All tiers):"
echo "   - Require PR reviews and status checks"
echo "   ⚠️  But: Developer controls what creates status checks"
echo ""
echo ""
echo "🔴 The Core Problem (Remains Even in Enterprise):"
echo "   Developer's workflow runs IN PARALLEL with required workflow"
echo "   Developer's deploy job has NO DEPENDENCY on required workflow"
echo "   Result: Can deploy BEFORE required workflow finds vulnerabilities"
echo ""

read -p "Press ENTER to see Harness solution..."
echo ""

echo "✅ Harness Solution: Architectural Enforcement"
echo "═══════════════════════════════════════════════"
echo ""
echo "In Harness:"
echo ""
cat <<'EOF'
# Template lives in Harness (NOT in developer's repo)
template:
  stages:
    - stage:
        name: Security
        locked: true  # ← DEVELOPERS CANNOT MODIFY
        spec:
          tests:
            - trivy_scan:
                required: true
                failOnSeverity: HIGH
                cannotSkip: true  # ← Architecturally impossible

# Developer's repo just references template:
pipeline:
  templateRef: prod_deploy_v1  # ← Cannot modify template
EOF
echo ""
echo "Result: Developer CANNOT bypass security. It's not in their repo."
echo ""

echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📊 Summary"
echo ""
echo "GitHub: Workflows are files in developer repos"
echo "  → Developers CAN edit them"
echo "  → Platform team relies on code review (doesn't scale)"
echo ""
echo "Harness: Templates live in platform (outside repos)"
echo "  → Developers CANNOT edit them"
echo "  → Security enforced architecturally (scales to 1000+ repos)"
echo ""
echo "🔴 At enterprise scale, you need architectural enforcement."
echo ""
echo "📖 Full analysis: docs/DEVELOPER_VS_PLATFORM.md"
echo "═══════════════════════════════════════════════════════════════════"
