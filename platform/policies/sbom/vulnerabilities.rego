# OPA Policy: SBOM Vulnerability Checks
# Validates that SBOM contains no critical vulnerabilities
# Integrates with vulnerability databases

package sbom

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ==============================================================================
# CRITICAL VULNERABILITY THRESHOLD
# ==============================================================================
deny[msg] {
    # Count critical vulnerabilities
    critical_vulns := [vuln |
        vuln := input.vulnerabilities[_]
        vuln.severity == "CRITICAL"
    ]

    count(critical_vulns) > 0

    msg := sprintf("SBOM contains %d CRITICAL vulnerabilities. All critical vulnerabilities must be resolved before deployment.", [count(critical_vulns)])
}

# ==============================================================================
# HIGH VULNERABILITY THRESHOLD
# ==============================================================================
deny[msg] {
    # Count high severity vulnerabilities
    high_vulns := [vuln |
        vuln := input.vulnerabilities[_]
        vuln.severity == "HIGH"
    ]

    # Allow max 5 high vulnerabilities (with exceptions)
    count(high_vulns) > 5

    msg := sprintf("SBOM contains %d HIGH severity vulnerabilities. Maximum allowed is 5. Please remediate or request exception.", [count(high_vulns)])
}

# ==============================================================================
# PROHIBITED PACKAGES
# ==============================================================================
prohibited_packages := {
    "lodash": "3.10.1",  # Known vulnerable version
    "axios": "0.18.0",   # Known vulnerable version
}

deny[msg] {
    package := input.packages[_]
    prohibited_version := prohibited_packages[package.name]
    package.version == prohibited_version

    msg := sprintf("Prohibited package found: %s@%s is known to be vulnerable", [package.name, package.version])
}

# ==============================================================================
# REQUIRE LICENSE COMPLIANCE
# ==============================================================================
prohibited_licenses := {
    "GPL-2.0",
    "GPL-3.0",
    "AGPL-3.0",
}

deny[msg] {
    package := input.packages[_]
    license := package.license
    license in prohibited_licenses

    msg := sprintf("Package '%s' uses prohibited license: %s. GPL/AGPL licenses are not allowed in proprietary software.", [package.name, license])
}

# ==============================================================================
# WARN: OUTDATED PACKAGES
# ==============================================================================
warn[msg] {
    # This would integrate with a package registry API to check latest versions
    # For now, this is a placeholder

    msg := "Recommendation: Run 'npm audit' or equivalent to check for outdated packages"
}

# ==============================================================================
# SUPPLY CHAIN SECURITY
# ==============================================================================
warn[msg] {
    package := input.packages[_]
    not package.supplier

    msg := sprintf("Package '%s' has no supplier information. Verify package authenticity.", [package.name])
}
