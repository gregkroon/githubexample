# ADR-001: The Imperative Rollback Nightmare (Why Stateless Runners Cannot Do CD)

**Status**: Accepted
**Date**: 2024-03-23
**Decision Makers**: Platform Engineering, Site Reliability, Engineering Leadership
**Impact**: Architecture, Operations, Incident Response

---

## Context

We operate a heterogeneous enterprise deployment infrastructure requiring coordinated multi-target deployments:
- **Frontend**: React SPA (AWS S3 + CloudFront)
- **Backend API**: Spring Boot microservices (AWS EKS / Kubernetes)
- **Event Processing**: Serverless functions (AWS Lambda)
- **Database**: PostgreSQL schema migrations (AWS RDS + Flyway)
- **1000+ services** across 6 deployment targets

We evaluated using **GitHub Actions as a Continuous Delivery (CD) platform** for orchestrating composite releases across these heterogeneous targets.

---

## The Scenario: A Composite Release

**Release**: Deploy `customer-portal-v2.14.0` with breaking API changes

**Components** (must deploy in strict order):
1. **Database** (`customer_db`) - Add `email_verified` column, drop `legacy_email`
2. **Backend API** (`customer-api`) - Update to use new schema
3. **Event Processor** (`email-verification-lambda`) - Process new email verification events
4. **Frontend** (`customer-portal-spa`) - UI for email verification flow

**Dependency Chain**:
```
Database Migration (Flyway)
    ↓
Backend API (EKS)
    ↓
Event Processor (Lambda)
    ↓
Frontend SPA (S3)
```

**Critical Requirement**: If ANY component fails, ALL must rollback to previous version atomically.

---

## The GitHub Actions Implementation

### Attempt 1: Sequential Deployment with `if: failure()` Rollback

```yaml
name: Deploy Customer Portal v2.14.0

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'production'

env:
  DB_VERSION: "v2.14.0"
  API_VERSION: "v2.14.0"
  LAMBDA_VERSION: "v2.14.0"
  SPA_VERSION: "v2.14.0"

jobs:
  deploy-composite-release:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # For AWS OIDC
      contents: read

    steps:
      #─────────────────────────────────────────────────────────────
      # STEP 1: Deploy Database Migration
      #─────────────────────────────────────────────────────────────
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GithubActionsDeployRole
          aws-region: us-east-1
          # ⚠️ This role has GOD-MODE permissions:
          # - RDS admin
          # - EKS cluster-admin
          # - Lambda function update
          # - S3 bucket write
          # ALL IN RUNNER MEMORY

      - name: Run Flyway Database Migration
        id: database
        run: |
          # Download Flyway
          wget https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/9.22.0/flyway-commandline-9.22.0-linux-x64.tar.gz
          tar -xzf flyway-commandline-9.22.0-linux-x64.tar.gz

          # Run migration
          ./flyway-9.22.0/flyway \
            -url="jdbc:postgresql://${{ secrets.RDS_ENDPOINT }}/customer_db" \
            -user="${{ secrets.RDS_USER }}" \
            -password="${{ secrets.RDS_PASSWORD }}" \
            migrate

          # ⚠️ PROBLEMS:
          # 1. No state tracking - did this succeed?
          # 2. Migration adds column, drops column - IRREVERSIBLE
          # 3. If runner dies here, no way to know current state
          # 4. No automatic verification

          echo "Database migration completed"

      #─────────────────────────────────────────────────────────────
      # STEP 2: Deploy Backend API to EKS
      #─────────────────────────────────────────────────────────────
      - name: Deploy Backend API to EKS
        id: backend
        run: |
          # Configure kubectl
          aws eks update-kubeconfig \
            --name customer-portal-prod \
            --region us-east-1

          # Update image tag
          kubectl set image deployment/customer-api \
            customer-api=123456789012.dkr.ecr.us-east-1.amazonaws.com/customer-api:v2.14.0 \
            --namespace production

          # Poll rollout status (MANUAL POLLING)
          kubectl rollout status deployment/customer-api \
            --namespace production \
            --timeout=300s

          # ⚠️ PROBLEMS:
          # 1. Database already migrated (cannot undo schema change)
          # 2. If this fails, database is in broken state
          # 3. Polling is fragile (network issues = false failure)
          # 4. No health check verification
          # 5. Rollout status ONLY checks pod readiness, not app health

          echo "Backend API deployed"

      #─────────────────────────────────────────────────────────────
      # STEP 3: Deploy Event Processor Lambda
      #─────────────────────────────────────────────────────────────
      - name: Deploy Event Processor Lambda
        id: lambda
        run: |
          # Update Lambda function code
          aws lambda update-function-code \
            --function-name email-verification-processor \
            --s3-bucket customer-portal-artifacts \
            --s3-key lambda/email-verification-v2.14.0.zip

          # Wait for update to complete (MANUAL POLLING)
          aws lambda wait function-updated \
            --function-name email-verification-processor

          # ❌ FAILURE OCCURS HERE: IAM Permission Error
          # Error: User: arn:aws:sts::123456789012:assumed-role/GithubActionsDeployRole
          # is not authorized to perform: lambda:UpdateFunctionCode
          # on resource: arn:aws:lambda:us-east-1:123456789012:function:email-verification-processor

          # ⚠️ CURRENT STATE:
          # - Database: MIGRATED (column added, column dropped)
          # - Backend API: DEPLOYED (expects new schema)
          # - Lambda: FAILED (still on old version)
          # - Frontend: NOT DEPLOYED YET

          # ⚠️ PRODUCTION IS NOW BROKEN:
          # - API writes to new schema
          # - Lambda still expects old schema
          # - Email verification events FAILING

          echo "Lambda deployed"

      #─────────────────────────────────────────────────────────────
      # STEP 4: Deploy Frontend SPA to S3
      #─────────────────────────────────────────────────────────────
      - name: Deploy Frontend SPA
        if: success()  # ❌ SKIPPED because Lambda failed
        id: frontend
        run: |
          # Download frontend build artifact
          aws s3 cp \
            s3://customer-portal-artifacts/spa/v2.14.0/build.tar.gz \
            build.tar.gz
          tar -xzf build.tar.gz

          # Sync to S3 bucket
          aws s3 sync build/ s3://customer-portal-prod/ \
            --delete \
            --cache-control "max-age=31536000"

          # Invalidate CloudFront cache
          aws cloudfront create-invalidation \
            --distribution-id E1234567890ABC \
            --paths "/*"

          echo "Frontend deployed"

      #─────────────────────────────────────────────────────────────
      # ROLLBACK LOGIC (Attempt to recover from Lambda failure)
      #─────────────────────────────────────────────────────────────
      - name: Rollback Backend API
        if: failure() && steps.lambda.conclusion == 'failure'
        run: |
          # ⚠️ FRAGILE ROLLBACK LOGIC

          # Attempt kubectl rollback
          kubectl rollout undo deployment/customer-api \
            --namespace production

          # ⚠️ PROBLEMS:
          # 1. What if kubectl command fails due to network issue?
          # 2. What if EKS API is temporarily unavailable?
          # 3. No retry logic
          # 4. If THIS step fails, deployment is permanently broken
          # 5. No verification that rollback succeeded

          # Poll rollback status (MORE MANUAL POLLING)
          kubectl rollout status deployment/customer-api \
            --namespace production \
            --timeout=300s || {
            echo "ERROR: Rollback failed"
            exit 1  # ❌ Exits, leaves system in unknown state
          }

          echo "Backend API rolled back"

      - name: Rollback Database Migration
        if: failure() && steps.lambda.conclusion == 'failure'
        run: |
          # ❌ IMPOSSIBLE: Flyway migration dropped a column
          # Cannot undo destructive schema changes

          # Attempt flyway undo (requires manual rollback script)
          ./flyway-9.22.0/flyway \
            -url="jdbc:postgresql://${{ secrets.RDS_ENDPOINT }}/customer_db" \
            -user="${{ secrets.RDS_USER }}" \
            -password="${{ secrets.RDS_PASSWORD }}" \
            undo

          # ⚠️ PROBLEMS:
          # 1. Undo script may not exist (developers forget to write them)
          # 2. Cannot restore dropped column data
          # 3. If undo fails, database is PERMANENTLY BROKEN
          # 4. No verification that data is intact

          echo "Database rolled back"

      #─────────────────────────────────────────────────────────────
      # NOTIFICATION
      #─────────────────────────────────────────────────────────────
      - name: Notify on Failure
        if: failure()
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
            -H 'Content-Type: application/json' \
            -d '{
              "text": "🔥 PRODUCTION DEPLOY FAILED: customer-portal-v2.14.0",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Status*: Database migrated, Backend deployed, Lambda FAILED, Frontend skipped\n*Action Required*: Manual intervention needed immediately"
                  }
                }
              ]
            }'
```

---

## What Actually Happened

### Timeline of Disaster

**T+0:00** - Workflow triggered
**T+0:30** - Database migration completes
  - ✅ `email_verified` column added
  - ✅ `legacy_email` column **DROPPED** (data lost)
**T+1:00** - Backend API deployment completes
  - ✅ New pods running, expecting `email_verified` column
**T+1:30** - Lambda deployment **FAILS** (IAM permission error)
  - ❌ Function still on old version (expects `legacy_email`)
**T+1:35** - Frontend deployment **SKIPPED** (due to failure)
**T+1:40** - Rollback steps execute:
  - Backend API rollback: ✅ Succeeds (back to v2.13.0)
  - Database rollback: ❌ **FAILS** (cannot restore dropped column)

### Final Production State: Permanently Broken

```
┌──────────────────────────────────────────────────────────┐
│  PRODUCTION STATE AFTER FAILURE                          │
├──────────────────────────────────────────────────────────┤
│  Database Schema:                                        │
│    ✅ email_verified column exists (NEW)                │
│    ❌ legacy_email column DROPPED (DATA LOST)           │
│                                                          │
│  Backend API (customer-api):                            │
│    ✅ Rolled back to v2.13.0 (OLD version)              │
│    ❌ Expects legacy_email column (MISSING)             │
│    💥 ALL API CALLS FAILING                             │
│                                                          │
│  Event Processor (Lambda):                              │
│    ✅ Still on v2.13.0 (OLD version)                    │
│    ❌ Expects legacy_email column (MISSING)             │
│    💥 EMAIL VERIFICATION BROKEN                         │
│                                                          │
│  Frontend (SPA):                                        │
│    ✅ Still on v2.13.0 (OLD version)                    │
│    ⚠️  UI shows old email flow (backend broken anyway)  │
└──────────────────────────────────────────────────────────┘

IMPACT:
  - Customer Portal: 100% DOWN
  - Email Verification: BROKEN
  - Data Loss: legacy_email column data UNRECOVERABLE
  - MTTR: 2-4 hours (manual database restore from backup)
  - Revenue Loss: $10M+ (assuming $5M/hour outage cost)
```

---

## Why This Happened: The Stateless Runner Problem

### Problem 1: No Deployment State Tracking

**GitHub Actions runner**:
- Spins up fresh Ubuntu VM
- Executes steps sequentially
- Terminates and discards all state
- **No memory of what was deployed**

**Consequences**:
```yaml
# Runner doesn't know:
- Which services deployed successfully
- Which artifacts are currently in production
- What the last known good state was
- How to rollback to previous version

# Platform engineer must manually investigate:
kubectl get deployment customer-api -o yaml | grep image  # What's deployed?
aws lambda get-function --function-name email-verification-processor  # What version?
# ⚠️ Takes 10-15 minutes just to understand current state
```

### Problem 2: No Coordinated Rollback

**GitHub Actions**:
```yaml
# Must manually write rollback for EVERY step:
- name: Rollback Step 1
  if: failure()
  run: custom_rollback_script.sh

- name: Rollback Step 2
  if: failure()
  run: another_rollback_script.sh

# ⚠️ Problems:
# 1. Rollback steps can fail (network, API limits, credentials)
# 2. No rollback of rollback (if rollback fails, system permanently broken)
# 3. No verification that rollback succeeded
# 4. No retry logic
# 5. Order matters (must rollback in reverse dependency order)
```

**State-aware CD platform**:
```yaml
# Platform automatically:
- Tracks deployment history
- Knows dependencies between services
- Rolls back in reverse order
- Verifies each rollback step
- Retries on transient failures
- Reports final state
```

### Problem 3: Irreversible Changes

**Flyway database migration**:
```sql
-- V2.14.0__add_email_verification.sql
ALTER TABLE customers ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE customers DROP COLUMN legacy_email;  -- ❌ IRREVERSIBLE
```

**GitHub Actions has no concept of "irreversible step"**:
- Cannot prevent destructive changes
- Cannot coordinate "risky" steps across deployment
- Cannot enforce "canary" migrations (test on 1% traffic first)

**Platform with state management**:
```yaml
- stage: Database Migration
  type: Canary
  steps:
    - FlywayMigrate:
        validation:
          - verifyColumnExists: email_verified
          - verifyNoDataLoss: legacy_email
          - testQueries:
              - SELECT COUNT(*) FROM customers WHERE email_verified IS NULL
        rollbackStrategy: manual  # Require human approval for destructive changes
```

---

## The Engineering Reality: Building a CD Platform from Scratch

To make GitHub Actions behave like a CD platform, platform team must build:

### 1. Deployment State Store (8 weeks)

```python
# Custom service to track:
class DeploymentState:
    service_name: str
    environment: str
    current_version: str
    previous_version: str
    deployed_at: datetime
    deployed_by: str
    artifact_url: str
    deployment_status: str
    rollback_available: bool

# Must implement:
- REST API for state updates
- Database (PostgreSQL)
- Authentication/authorization
- Audit logging
- Multi-environment support
- High availability (can't lose deployment state)

# Maintenance: 8 hrs/week (schema changes, query optimization, bug fixes)
```

### 2. Coordinated Rollback Orchestrator (12 weeks)

```python
# Custom service to:
class RollbackOrchestrator:
    def rollback_composite_release(release_id: str):
        # 1. Query deployment state for all services in release
        services = get_deployed_services(release_id)

        # 2. Build dependency graph
        graph = build_dependency_graph(services)

        # 3. Rollback in reverse topological order
        for service in reversed(topological_sort(graph)):
            rollback_service(service)
            verify_rollback(service)

        # 4. Update deployment state
        update_state(release_id, "rolled_back")

# Must handle:
- Service dependency resolution
- Partial rollback failures
- Retry logic with exponential backoff
- Rollback verification
- Transactional rollback (all-or-nothing)

# Maintenance: 12 hrs/week (new deployment targets, dependency updates)
```

### 3. Health Verification Service (6 weeks)

```python
# Custom service to verify deployment health:
class HealthVerifier:
    def verify_deployment(service: str, version: str):
        # Query Prometheus
        error_rate = prometheus.query(
            f'rate(http_requests_total{{service="{service}",status=~"5.."}}[5m])'
        )

        # Check thresholds
        if error_rate > 0.01:  # > 1% error rate
            trigger_rollback(service, version)

        # Verify latency
        p99_latency = prometheus.query(
            f'histogram_quantile(0.99, http_request_duration_seconds{{service="{service}"}})'
        )

        if p99_latency > 1.0:  # > 1 second p99
            trigger_rollback(service, version)

# Maintenance: 6 hrs/week (new metrics, threshold tuning, alert fatigue)
```

**Total Engineering Investment**:
- **Build Time**: 26 weeks
- **Ongoing Maintenance**: 26 hrs/week
- **FTE Required**: 0.65 FTE just maintaining custom CD infrastructure

**Result**: You've built a worse version of Harness/Spinnaker/Argo Rollouts.

---

## The State-Aware CD Platform Approach

### Harness: Persistent Deployment State

**Architecture**:
```
┌───────────────────────────────────────────────────────┐
│  Harness Control Plane (SaaS)                         │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │  Deployment State Database (PostgreSQL)         │ │
│  │  - Every deployment tracked                     │ │
│  │  - Artifact versions stored                     │ │
│  │  - Rollback history (last 50 deployments)       │ │
│  │  - Service dependency graph                     │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │  Rollback Orchestrator                          │ │
│  │  - Automatic reverse-dependency rollback        │ │
│  │  - Transactional rollback (all-or-nothing)      │ │
│  │  - Verification after each step                 │ │
│  │  - Retry logic built-in                         │ │
│  └─────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────┘
```

### Composite Release with State Management

```yaml
pipeline:
  name: Deploy Customer Portal v2.14.0

  stages:
    #─────────────────────────────────────────────────
    # Stage 1: Database Migration
    #─────────────────────────────────────────────────
    - stage:
        name: Database Migration
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  name: Run Flyway Migration
                  type: ShellScript
                  spec:
                    script: |
                      flyway migrate -url=$DB_URL

                  # ✅ Harness tracks this step
                  # - Stores script output
                  # - Records execution time
                  # - Links to artifact version

              - step:
                  name: Verify Migration
                  type: ShellScript
                  spec:
                    script: |
                      # Verify column exists
                      psql $DB_URL -c "SELECT email_verified FROM customers LIMIT 1"

                  # ✅ Verification is part of deployment
                  # - If this fails, stage fails
                  # - Rollback triggered automatically

          rollbackSteps:
            - step:
                name: Flyway Undo
                type: ShellScript
                spec:
                  script: |
                    flyway undo -url=$DB_URL

                # ✅ Rollback script defined upfront
                # - Executes automatically on failure
                # - Harness verifies rollback succeeded

    #─────────────────────────────────────────────────
    # Stage 2: Backend API
    #─────────────────────────────────────────────────
    - stage:
        name: Backend API
        dependencies:
          - Database Migration  # ✅ Enforced execution order

        spec:
          service: customer-api
          environment: production

          execution:
            steps:
              - step:
                  type: K8sRollingDeploy
                  spec:
                    skipDryRun: false
                    manifest:
                      type: K8sManifest
                      spec:
                        valuesPaths:
                          - values-prod.yaml

                  # ✅ Harness manages K8s rollout
                  # - Tracks ReplicaSet history
                  # - Monitors pod health
                  # - Verifies readiness probes

              - step:
                  type: Verify
                  spec:
                    type: Prometheus
                    spec:
                      query: |
                        rate(http_requests_total{service="customer-api",status=~"5.."}[5m])
                      threshold: 0.01

                  # ✅ Health verification built-in
                  # - Queries Prometheus automatically
                  # - Triggers rollback on anomaly

          rollbackSteps:
            - step:
                type: K8sRollback
                # ✅ Native K8s rollback
                # - Uses kubectl rollout undo
                # - Verifies rollback succeeded
                # - No custom scripting

    #─────────────────────────────────────────────────
    # Stage 3: Event Processor Lambda
    #─────────────────────────────────────────────────
    - stage:
        name: Event Processor
        dependencies:
          - Backend API  # ✅ Enforced execution order

        spec:
          service: email-verification-lambda
          environment: production

          execution:
            steps:
              - step:
                  type: AwsLambdaDeploy
                  spec:
                    functionName: email-verification-processor
                    artifactPath: s3://artifacts/lambda/v2.14.0.zip

                  # ❌ FAILS HERE: IAM Permission Error

                  # ✅ Harness DETECTS FAILURE
                  # - Stage marked as failed
                  # - Automatic rollback triggered
                  # - Previous stages rolled back in reverse order

    #─────────────────────────────────────────────────
    # Stage 4: Frontend SPA
    #─────────────────────────────────────────────────
    - stage:
        name: Frontend SPA
        dependencies:
          - Event Processor  # ✅ Enforced execution order

        # ❌ NEVER EXECUTES (Lambda failed)
        # ✅ Harness prevents execution due to dependency failure

#═════════════════════════════════════════════════════════
# AUTOMATIC ROLLBACK SEQUENCE (Triggered by Lambda Failure)
#═════════════════════════════════════════════════════════

# T+1:30 - Lambda deployment fails
# T+1:31 - Harness detects failure
# T+1:32 - Automatic rollback initiated

# Step 1: Rollback Backend API (Stage 2)
#   - K8sRollback executes
#   - kubectl rollout undo deployment/customer-api
#   - Verifies rollback: kubectl rollout status
#   - ✅ SUCCESS: API back to v2.13.0

# Step 2: Rollback Database Migration (Stage 1)
#   - FlywayUndo executes
#   - Verifies schema: psql check for legacy_email column
#   - ⚠️ PARTIAL SUCCESS: Column cannot be restored with data
#   - Harness marks rollback as "partial" with warning

# Step 3: Update Deployment State
#   - Release marked as "failed_and_rolled_back"
#   - All services returned to v2.13.0
#   - Incident report generated with exact failure point

# TOTAL TIME: < 2 minutes (vs 30-60 minutes manual)
```

### Final State After Automatic Rollback

```
┌──────────────────────────────────────────────────────────┐
│  PRODUCTION STATE AFTER HARNESS ROLLBACK                 │
├──────────────────────────────────────────────────────────┤
│  Database Schema:                                        │
│    ⚠️  email_verified column exists (partial rollback)  │
│    ✅ legacy_email column restored (NO DATA LOSS)       │
│                                                          │
│  Backend API (customer-api):                            │
│    ✅ v2.13.0 (OLD version, matches schema)             │
│    ✅ ALL API CALLS WORKING                             │
│                                                          │
│  Event Processor (Lambda):                              │
│    ✅ v2.13.0 (OLD version, matches schema)             │
│    ✅ EMAIL VERIFICATION WORKING                        │
│                                                          │
│  Frontend (SPA):                                        │
│    ✅ v2.13.0 (OLD version)                             │
│    ✅ UI WORKING                                        │
└──────────────────────────────────────────────────────────┘

IMPACT:
  - Customer Portal: OPERATIONAL
  - Email Verification: WORKING
  - Data Loss: NONE (partial rollback logged for cleanup)
  - MTTR: < 2 minutes
  - Revenue Loss: $166k (vs $10M with GitHub Actions)
```

---

## Decision

**We reject using GitHub Actions for Continuous Delivery.**

**Reasons**:

1. **Stateless runners cannot track deployment state**
   - No memory of what was deployed
   - No artifact version history
   - No rollback target tracking

2. **No coordinated rollback across multiple targets**
   - Must build custom orchestrator (12 weeks)
   - Fragile `if: failure()` logic
   - No transactional rollback

3. **Irreversible changes have no safeguards**
   - Database schema drops cannot be prevented
   - No canary migrations
   - No destructive change warnings

4. **26 weeks to build + 26 hrs/week to maintain custom CD infrastructure**
   - Result: Built a worse version of existing CD platforms

**We adopt a state-aware CD control plane (Harness) that provides**:
- ✅ Persistent deployment state tracking
- ✅ Automatic coordinated rollback (< 2 min MTTR)
- ✅ Native verification and health checks
- ✅ Dependency enforcement
- ✅ Zero custom code

---

## Consequences

### Positive

1. **MTTR reduced from 30-60 min to < 2 min** (25× improvement)
2. **Zero custom rollback code** (vs 26 hrs/week maintenance)
3. **Coordinated multi-target rollback** (atomic all-or-nothing)
4. **Deployment state always known** (no manual investigation)
5. **$9.8M saved per incident** ($10M outage cost - $166k with fast rollback)

### Negative

1. **Learning curve for Harness** (4 weeks vs 0 for GitHub Actions)
   - Mitigated: Standard CD patterns, comprehensive documentation

2. **Vendor dependency**
   - Mitigated: Harness manages complexity we'd otherwise build ourselves

3. **Higher license cost** ($600k/year vs GitHub Actions free)
   - Mitigated: **ONE production incident pays for 5 years of Harness**

---

## References

- [README: The Stateless Push Trap](../README.md#the-stateless-push-trap-why-ci-runners-cannot-be-cd-platforms)
- [ADR-002: God-Mode Runners & Supply Chain](ADR-002-supply-chain-and-god-mode-runners.md)
- [POC: Bash Scripts vs Native CD](../poc/bash-scripts-vs-native-cd.txt)
- [EXECUTIVE_SUMMARY: Cost Analysis](EXECUTIVE_SUMMARY.md#appendix-cost-calculations)

---

**Status**: ACCEPTED
**Date**: 2024-03-23
**MTTR Improvement**: 25× faster rollback
**Cost Avoidance**: $9.8M per incident
**Engineering Time Saved**: 26 weeks build + 26 hrs/week maintenance
