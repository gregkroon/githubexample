# GitHub Environment Setup Guide

This guide shows how to configure GitHub Environments with approval gates to demonstrate deployment promotion (Dev → Prod).

## Overview

The CD workflow now deploys to two environments:
1. **Dev** - Automatic deployment after CI passes
2. **Production** - Requires manual approval before deployment

## Setting Up Environments

### Step 1: Navigate to Repository Settings

1. Go to your GitHub repository
2. Click **Settings** tab
3. Click **Environments** in the left sidebar

### Step 2: Create Dev Environment

1. Click **New environment**
2. Name: `dev`
3. Click **Configure environment**
4. **No protection rules needed** - Dev should deploy automatically
5. (Optional) Add environment URL: `https://dev.user-service.example.com`
6. Click **Save protection rules**

### Step 3: Create Production Environment

1. Click **New environment**
2. Name: `production`
3. Click **Configure environment**
4. Enable **Required reviewers**
   - Add yourself and/or team members who can approve production deploys
   - Minimum: 1 reviewer
5. (Optional) Add **Wait timer**
   - Example: 5 minutes to simulate a "soak time" in dev
6. (Optional) Add environment URL: `https://user-service.example.com`
7. Click **Save protection rules**

## What This Demonstrates

### Deployment Flow

```
┌─────────────┐
│   Git Push  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│  CI Pipeline                     │
│  • Test                          │
│  • Build & Push Image            │
│  • Security Scan (Trivy/Grype)   │
│  • Generate SBOM                 │
│  • Sign with Cosign              │
│  • Policy Validation             │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│  Deploy to Dev (automatic)       │
│  • Create Kind cluster           │
│  • Deploy to user-service-dev    │
│  • Run smoke tests               │
│  ✅ No approval required         │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│  ⏸️  WAIT FOR APPROVAL          │
│                                  │
│  Production environment gate:    │
│  • Review deployment             │
│  • Check dev metrics             │
│  • Approve or reject             │
└──────┬──────────────────────────┘
       │
       ▼ (after approval)
┌─────────────────────────────────┐
│  Deploy to Production            │
│  • Create Kind cluster           │
│  • Deploy to user-service-prod   │
│  • Run production smoke tests    │
│  ✅ Deployment complete          │
└─────────────────────────────────┘
```

### GitHub UI Experience

When the workflow reaches the production job:

1. **Workflow pauses** at the production deployment
2. **Yellow status** shows "Waiting for approval"
3. **Reviewers receive notification** (email/GitHub notification)
4. **Reviewer clicks "Review deployments"** button
5. **Can approve or reject** with optional comment
6. **After approval** → production deployment runs

### Key Features Demonstrated

✅ **Environment-based RBAC**
- Only designated reviewers can approve production deployments
- Prevents unauthorized production changes

✅ **Visual deployment tracking**
- GitHub UI shows which environment is deployed
- Environment URLs link to deployed services
- Deployment history per environment

✅ **Audit trail**
- Who approved production deployment
- When it was approved
- Any comments/justification

⚠️ **Limitations vs. Purpose-Built CD Platforms**

| Feature | GitHub Environments | Harness |
|---------|-------------------|---------|
| Approval gates | ✅ Manual reviewers | ✅ Manual + automated policies |
| Deployment history | ✅ Per environment | ✅ Per environment + global view |
| Rollback | ❌ Manual re-deploy | ✅ One-click rollback |
| Canary/Blue-Green | ❌ Custom scripting | ✅ Built-in strategies |
| Multi-service orchestration | ❌ Not supported | ✅ Dependency management |
| Metrics-based verification | ❌ Requires custom code | ✅ Built-in integrations |
| Deployment windows | ❌ Requires custom logic | ✅ Configurable calendars |

## Testing the Approval Flow

### Trigger a Deployment

1. Make a code change to `services/user-service/`
2. Commit and push to `main`
3. CI pipeline runs automatically
4. CD pipeline starts → Dev deploys automatically
5. Production job shows "Waiting for approval"

### Approve Production Deployment

1. Go to **Actions** tab in GitHub
2. Click the running workflow
3. You'll see: `Deploy to Production` with ⏸️ status
4. Click **Review deployments** button
5. Check the `production` checkbox
6. (Optional) Add comment: "Approved - dev tests passed"
7. Click **Approve and deploy**
8. Production deployment runs

### Reject Production Deployment

1. Follow steps 1-4 above
2. Click **Reject** instead
3. Production deployment is skipped
4. Workflow completes with production marked as skipped

## Environment Variables and Secrets

You can configure environment-specific secrets:

### Per-Environment Secrets

1. Go to **Settings** → **Environments**
2. Click environment name (e.g., `production`)
3. Click **Add secret**
4. Example secrets:
   - `DATABASE_URL` (different per environment)
   - `API_KEY` (prod has different key than dev)
   - `SLACK_WEBHOOK` (notify different channels)

### Using in Workflows

```yaml
deploy-prod:
  environment: production
  steps:
    - name: Deploy
      env:
        DB_URL: ${{ secrets.DATABASE_URL }}  # Uses production-specific secret
```

## Comparison: GitHub vs Harness

### What GitHub Environments Provide

✅ Basic approval gates (manual reviewers)
✅ Environment-specific secrets
✅ Deployment history tracking
✅ Visual workflow pausing

### What GitHub Environments DON'T Provide

❌ **Advanced deployment strategies**
  - No built-in canary/blue-green
  - No traffic shifting
  - No automatic rollback

❌ **Policy-based approvals**
  - Can't block based on metrics (error rate, latency)
  - Can't enforce soak time requirements
  - Can't check incident status (PagerDuty integration)

❌ **Deployment windows**
  - Can't prevent Friday 6pm deployments
  - No calendar-based controls
  - Requires custom workflow logic

❌ **Multi-service orchestration**
  - Can't coordinate deploying 5 services in order
  - Each workflow is isolated
  - No dependency graph

❌ **Centralized governance**
  - Configuration is per-repository
  - Can't enforce org-wide deployment policies
  - Each repo needs identical workflow setup

## At Scale: The Real Problem

### 1 Microservice = Easy ✅

Setting up environments for one service is straightforward.

### 100 Microservices = Hard ⚠️

- Configure environments for 100 repos manually
- Keep approval policies in sync
- Update all workflows when rules change

### 1000 Microservices = Impossible ❌

- 3000 environments to configure (dev, staging, prod each)
- No way to enforce consistent approval workflows
- Developers can edit workflow files directly
- No centralized deployment visibility

## Next Steps

1. **Set up environments** following Step 2 and Step 3 above
2. **Push a change** to trigger the workflow
3. **Test approval flow** by approving production deployment
4. **Compare** this experience to what Harness provides

See `docs/DEMO.md` for the complete walkthrough including this feature.
