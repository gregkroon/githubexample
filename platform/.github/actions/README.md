# GitHub Composite Actions

This directory contains reusable **composite actions** that bundle common workflow steps.

## Available Actions

### 1. `scan-and-sign`

Scans container images for CVEs and signs them with Cosign.

**Usage:**
```yaml
- name: Scan and sign container
  uses: yourorg/platform/.github/actions/scan-and-sign@main
  with:
    image: ghcr.io/yourorg/service:${{ github.sha }}
    severity: 'CRITICAL,HIGH'
    fail-on-vulnerabilities: 'true'
```

**What it does:**
- Scans with Trivy
- Scans with Grype (second opinion)
- Signs image with Cosign (keyless OIDC signing)
- Verifies signature

### 2. `validate-policies`

Validates Dockerfile, Kubernetes manifests, and SBOM against OPA/Rego policies.

**Usage:**
```yaml
- name: Validate policies
  uses: yourorg/platform/.github/actions/validate-policies@main
  with:
    dockerfile-path: 'Dockerfile'
    k8s-manifests-path: 'k8s/'
    sbom-path: 'sbom.json'
    policies-repo: 'platform'
```

**What it does:**
- Validates Dockerfile against Docker policies
- Validates Kubernetes manifests against security policies
- Validates SBOM against vulnerability and license policies

---

## Complete Example: Using Composite Actions

```yaml
# services/user-service/.github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-and-scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write  # For Cosign OIDC

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build container image
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ghcr.io/${{ github.repository }}:${{ github.sha }}
          format: json
          output-file: sbom.json

      # ← Use composite action for policy validation
      - name: Validate policies
        uses: yourorg/platform/.github/actions/validate-policies@main
        with:
          dockerfile-path: 'Dockerfile'
          k8s-manifests-path: 'k8s/'
          sbom-path: 'sbom.json'

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Push image
        run: |
          docker push ghcr.io/${{ github.repository }}:${{ github.sha }}

      # ← Use composite action for scanning and signing
      - name: Scan and sign image
        uses: yourorg/platform/.github/actions/scan-and-sign@main
        with:
          image: ghcr.io/${{ github.repository }}:${{ github.sha }}
          severity: 'CRITICAL,HIGH'
          fail-on-vulnerabilities: 'true'
```

---

## What Composite Actions Solve ✅

✅ **Code reuse**: DRY principle - don't repeat scan/sign/validate steps in every workflow
✅ **Easier maintenance**: Update scanning logic in one place, all repos benefit
✅ **Version control**: Pin to `@v1.0.0` for stability or use `@main` for auto-updates
✅ **Consistency**: Ensures all services use the same scanning and validation logic

---

## What Composite Actions DON'T Solve ❌

### 1. **Still Requires Workflow Files in Every Repo**

Even with composite actions, you STILL need a workflow file in all 1000 repos:

```yaml
# This file MUST exist in EVERY repository
# services/user-service/.github/workflows/ci.yml
# services/payment-service/.github/workflows/ci.yml
# services/notification-service/.github/workflows/ci.yml
# ... × 1000 repos
```

❌ 1000 workflow files to maintain
❌ Updates to workflow structure require touching every repo
❌ Configuration drift (which repos use which action versions?)

### 2. **Still Requires Per-Repo Secrets**

Composite actions can't access organization secrets directly:

```yaml
# Each repo must have these secrets configured:
- uses: platform/.github/actions/scan-and-sign@main
  env:
    COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}  # ← Must be in EVERY repo

# Scenario: Rotate COSIGN_PASSWORD
# GitHub: Update secret in 1000 repos (4-8 hours of scripting)
# Harness: Update one connector (2 minutes, all services updated)
```

### 3. **Still Requires GitHub Environments**

Composite actions don't solve deployment governance:

```bash
# You STILL need to configure 3000 GitHub Environments:
for repo in $(gh repo list --limit 1000); do
  gh api repos/$repo/environments/production -X PUT \
    -f reviewers='[{"type":"Team","id":12345}]'
done

# Approvals, deployment gates, protection rules are NOT in composite actions
```

### 4. **No Enforcement Mechanism**

Teams can bypass composite actions entirely:

```yaml
# A team could just... not use your composite actions:
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: docker build -t myimage .
      - run: docker push myimage  # No scanning, no signing, no policies
      - run: kubectl apply -f deployment.yaml
```

❌ No way to enforce all repos use your composite actions
❌ No central visibility into compliance

### 5. **Limited to Workflow Steps**

Composite actions can only bundle **workflow steps**, they can't:

❌ Make decisions based on external APIs or production metrics
❌ Orchestrate multi-service deployments
❌ Provide deployment dashboards or observability
❌ Implement progressive delivery (canary, blue/green)
❌ Automate rollback based on metrics
❌ Enforce deployment windows or approval policies

---

## The Bigger Picture

Composite actions are **helpful for code reuse** (~15-20% operational burden reduction), but you still have:

- ❌ **1000 workflow files** to maintain
- ❌ **3000 GitHub Environment configurations**
- ❌ **1000+ secret configurations**
- ❌ **24 deployment tools** to integrate
- ❌ **6 custom services** to build
- ❌ **No enforcement** (teams can bypass actions)
- ❌ **No central visibility** (which repos are compliant?)
- ❌ **2-4 FTE** to operate

**Composite actions improve code reuse, but don't fundamentally reduce operational burden at scale.**

---

## Comparison: Composite Actions vs Harness Plugins

| Aspect | GitHub Composite Actions | Harness Plugins |
|--------|--------------------------|-----------------|
| **Reusability** | ✅ Reusable across workflows | ✅ Reusable across pipelines |
| **Workflow files** | ❌ Still need 1000 workflow files | ✅ No per-service files needed |
| **Secrets** | ❌ Per-repo secret management | ✅ Centralized connectors |
| **Enforcement** | ❌ Teams can bypass | ✅ Enforced via templates |
| **Deployment logic** | ❌ Limited to CI steps | ✅ Full deployment orchestration |
| **Visibility** | ❌ No central dashboard | ✅ Built-in dashboards |
| **Version control** | ⚠️ Per-repo pinning or risky @main | ✅ Centralized version management |

---

## Recommendation

**Use composite actions** for:
- ✅ Bundling common CI steps (build, test, scan)
- ✅ Code reuse within GitHub Actions
- ✅ Small-scale deployments (< 50 repos)

**Don't rely on composite actions** for:
- ❌ Enterprise-scale deployment governance
- ❌ Centralized configuration management
- ❌ Deployment orchestration and verification
- ❌ Operational burden reduction at 1000+ repos

**For enterprise CI/CD at scale, composite actions help with code reuse, but you still need a purpose-built CD platform like Harness to solve the operational burden.**

See [HARNESS_COMPARISON.md](../../../docs/HARNESS_COMPARISON.md) for the complete analysis.
