# Live Deployment - ALL 3 SERVICES ACTUALLY RUNNING

**This is NOT a simulation. ALL 3 services have workflows that ACTUALLY run on every push.**

> ⚠️ **[See What's Missing →](GITHUB_GAPS_REAL.md)** - After watching them run, see the OBVIOUS shortcomings vs Harness

The workflows in `/.github/workflows/` are **real, production-ready CI/CD pipelines** for:
- **user-service** (Node.js)
- **payment-service** (Go)
- **notification-service** (Python)

**All run automatically. All deploy to Kind. All prove the complexity is REAL.**

---

## What Actually Happens

### On Every Push to `main`

**ALL 3 services** have identical CI/CD workflows that run automatically:

#### User Service (Node.js)

**[CI Workflow](../.github/workflows/ci-user-service.yml)** runs on changes to `services/user-service/**`:
1. ✅ Tests with npm test
2. ✅ Builds Docker image → GHCR
3. ✅ Scans (Trivy + Grype)
4. ✅ Generates SBOM (Syft)
5. ✅ Signs image (Cosign)
6. ✅ Validates policies (Conftest)

**[CD Workflow](../.github/workflows/cd-user-service.yml)** deploys after CI:
1. ✅ Creates Kind cluster
2. ✅ Deploys to Kubernetes
3. ✅ Runs smoke tests

#### Payment Service (Go)

**[CI Workflow](../.github/workflows/ci-payment-service.yml)** runs on changes to `services/payment-service/**`:
1. ✅ Tests with go test
2. ✅ Builds Docker image → GHCR
3. ✅ Scans (Trivy + Grype)
4. ✅ Generates SBOM (Syft)
5. ✅ Signs image (Cosign)
6. ✅ Validates policies (Conftest)

**[CD Workflow](../.github/workflows/cd-payment-service.yml)** deploys after CI:
1. ✅ Creates Kind cluster
2. ✅ Deploys to Kubernetes
3. ✅ Runs smoke tests

#### Notification Service (Python)

**[CI Workflow](../.github/workflows/ci-notification-service.yml)** runs on changes to `services/notification-service/**`:
1. ✅ Tests with pytest
2. ✅ Builds Docker image → GHCR
3. ✅ Scans (Trivy + Grype)
4. ✅ Generates SBOM (Syft)
5. ✅ Signs image (Cosign)
6. ✅ Validates policies (Conftest)

**[CD Workflow](../.github/workflows/cd-notification-service.yml)** deploys after CI:
1. ✅ Creates Kind cluster
2. ✅ Deploys to Kubernetes
3. ✅ Runs smoke tests

**Notice**: 6 workflow files, nearly identical logic, maintained separately. **This is the GitHub way at scale.**

---

## How to See It Running

### 1. Fork This Repository

```bash
# Fork via GitHub UI, then clone
git clone https://github.com/YOUR_USERNAME/githubexample.git
cd githubexample
```

### 2. Make a Change to ANY Service

```bash
# Option A: Edit user-service (Node.js)
echo "console.log('Hello CI/CD');" >> services/user-service/src/index.js

# Option B: Edit payment-service (Go)
echo "// Test change" >> services/payment-service/main.go

# Option C: Edit notification-service (Python)
echo "# Test change" >> services/notification-service/app.py

git add .
git commit -m "Test live deployment"
git push origin main
```

### 3. Watch MULTIPLE Workflows Run

Go to your fork:
```
https://github.com/YOUR_USERNAME/githubexample/actions
```

**You'll see workflows for ONLY the service you changed:**
- Changed `services/user-service/**`? → CI + CD for user-service runs
- Changed `services/payment-service/**`? → CI + CD for payment-service runs
- Changed `services/notification-service/**`? → CI + CD for notification-service runs

**Each workflow:**
1. Runs tests (npm/go/pytest depending on language)
2. Builds Docker image
3. Scans with Trivy + Grype
4. Generates SBOM
5. Signs with Cosign
6. Validates policies
7. Deploys to Kind cluster
8. Runs smoke tests

**Total time per service: ~10 minutes**

**To see ALL 3 workflows run**, make changes to all 3 services in one commit.

---

## What You Can Verify

### 1. Built Image in GHCR

After CI runs, check your container registry:
```
https://github.com/YOUR_USERNAME/githubexample/pkgs/container/githubexample%2Fuser-service
```

You'll see:
- The actual Docker image
- Image size
- When it was pushed
- Tags (sha-based and branch-based)

### 2. Security Scan Results

Go to the Security tab:
```
https://github.com/YOUR_USERNAME/githubexample/security
```

You'll see:
- Trivy scan results uploaded as SARIF
- Vulnerabilities found (if any)
- Severity levels

### 3. SBOM Artifact

In the workflow run, click "Artifacts":
- Download `sbom.spdx.json`
- See every dependency and version
- This is the Software Bill of Materials

### 4. Signed Image

The workflow verifies the signature with Cosign:
```bash
# This command runs in the workflow:
cosign verify ghcr.io/YOUR_USERNAME/githubexample/user-service:main-SHA \
  --certificate-identity-regexp="https://github.com/YOUR_USERNAME/.*" \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com
```

If you have cosign locally:
```bash
# Verify the signature yourself
cosign verify ghcr.io/YOUR_USERNAME/githubexample/user-service:main-SHA \
  --certificate-identity-regexp="https://github.com/YOUR_USERNAME/.*" \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com
```

### 5. Deployment to Kubernetes

The CD workflow:
1. Creates a real Kind cluster
2. Deploys the service
3. Waits for pods to be ready
4. Port-forwards and tests endpoints

Check the "Deploy to Kind Cluster" job output:
```
kubectl get pods -n user-service
NAME                           READY   STATUS    RESTARTS   AGE
user-service-xxxxx-yyyyy       1/1     Running   0          30s

✅ Health endpoint responding
✅ Users API responding
✅ Metrics endpoint responding
✅ POST /api/users works
```

---

## Cost

**This is 100% FREE**:
- ✅ GitHub Actions minutes (2,000-3,000 free per month)
- ✅ GitHub Container Registry (500MB free)
- ✅ Kind cluster (runs in GitHub Actions, no cloud cost)
- ✅ All security scanning tools (free for public repos)

**Typical run:**
- CI workflow: ~5-7 minutes
- CD workflow: ~3-4 minutes
- Total: ~10 minutes per push

**With ~20 pushes/month**, you use ~200 minutes (well within free tier).

---

## What This Proves

### 1. Everything Actually Works ✅

This isn't theoretical. Every tool mentioned in the docs actually runs:
- Trivy, Grype: Real vulnerability scanning
- Syft: Real SBOM generation
- Cosign: Real image signing
- Conftest: Real policy validation
- Kubernetes: Real deployment

### 2. Integration is Complex - And Repetitive 🔴

Look at the CI workflows (180+ lines EACH):
- 6 separate jobs per workflow
- Each job has multiple steps
- Lots of authentication, configuration, error handling
- **We have 3 services = 6 workflows (CI + CD for each)**
- **All 6 workflows are nearly IDENTICAL** - only service names and paths differ

**At 3 services**: 6 workflows to maintain
**At 1000 services**: 2000 workflows to maintain (CI + CD for each)

**This repetition proves the operational burden is REAL.**

### 3. Operational Burden is Real 🔴

Things that can break:
- Docker build failures
- Security scans find vulnerabilities
- Policy validation failures
- Image signing issues
- Kubernetes deployment failures
- Health check timeouts

**Each failure requires investigation and fixing.**

### 4. It Takes Time ⏱️

Even with everything automated:
- CI: 5-7 minutes
- CD: 3-4 minutes
- Total: ~10 minutes from push to deployed

**With approval gates, soak time, canary analysis: 30-60 minutes.**

---

## Comparison: This vs Harness

### GitHub Actions (This Repo)

**To deploy user-service:**
1. Push code to `main`
2. CI workflow runs (7 min)
3. CD workflow runs (4 min)
4. Service deployed
5. **Total time**: 11 minutes

**If deployment fails:**
1. Check workflow logs
2. Find which step failed
3. Fix the issue
4. Push again
5. Wait 11 more minutes

**To rollback:**
1. Revert the commit
2. Push to `main`
3. Wait for CI (7 min)
4. Wait for CD (4 min)
5. **Total rollback time**: 11 minutes

### Harness (Purpose-Built Platform)

**To deploy user-service:**
1. Push code to `main`
2. CI runs (kept - GitHub Actions is good for this)
3. Harness triggered automatically
4. Canary deployment with automated verification
5. **Total time**: 5-10 minutes (with verification)

**If deployment fails:**
1. Harness automatically detects (metrics spike)
2. Harness automatically rolls back
3. Team gets notification
4. **Total time to rollback**: < 1 minute

**To manually rollback:**
1. Click "Rollback" button in Harness UI
2. Harness redeploys previous version
3. **Total rollback time**: < 1 minute

---

## How to Use This

### For Evaluation

1. Fork the repo
2. Watch the workflows run
3. See actual security scans
4. See actual deployments
5. See actual smoke tests

### For Learning

1. Read the workflow files
2. See how all the tools integrate
3. Understand the complexity
4. See what can go wrong

### For Your Own Projects

1. Copy the workflows
2. Adapt for your services
3. Customize the policies
4. Add more scanning tools
5. **Maintain 1000 copies of these workflows**

---

## Limitations

This is a real deployment, but:

### Not Production-Ready
- ✅ All tools work
- ❌ Kind cluster is ephemeral (torn down after workflow)
- ❌ No persistent storage
- ❌ No real traffic
- ❌ No production monitoring

### Simplified
- ✅ Complete CI/CD pipeline
- ❌ Single service (not multi-service orchestration)
- ❌ No deployment gates or approval workflows
- ❌ No progressive delivery (canary, blue/green)
- ❌ No DORA metrics collection

### Partially Scaled
- ✅ Works for 3 services (shows repetition)
- ✅ **Shows the burden**: 6 workflows with 95% identical logic
- ⚠️ At 1000 repos: 2000 workflows + 3000 environment configs
- ❌ Doesn't show configuration drift over time
- ❌ Doesn't show environment management complexity at full scale

---

## The Point

**This proves everything WORKS - for ALL 3 services.**

**The documented complexity and cost is REAL:**
- Integration complexity: Real (see all 6 workflow files)
- Operational burden: Real (6 workflows with 95% duplicate logic)
- Repetition: Real (change one thing = update 6 files)
- Missing features: Real (no one-click rollback, no automated verification)

**At 3 services**: ✅ Repetition visible, still manageable
**At 100 services**: ⚠️ 200 workflows, operational burden growing
**At 1000 services**: ❌ 2000 workflows + 3000 configs = burden exceeds platform cost

---

## Next Steps

### Run It Yourself
1. Fork the repo
2. Push a change
3. Watch it run
4. Verify everything works

### Compare to Harness
1. Read [HARNESS_COMPARISON.md](HARNESS_COMPARISON.md)
2. See how Harness simplifies this
3. See the cost difference
4. Make your own decision

### Deep Dive
1. [Architecture](ARCHITECTURE.md) - How it all fits together
2. [Tool Inventory](TOOL_INVENTORY.md) - Every tool explained
3. [Operational Burden](OPERATIONAL_BURDEN.md) - What breaks and why

---

**This is a real, working, production-grade CI/CD pipeline.**

**Everything documented in this repo is based on this actual implementation.**

**The complexity is real. The costs are real. The trade-offs are real.**

---

**[← Back to README](../README.md)** | **[View CI Workflow](../.github/workflows/ci-user-service.yml)** | **[View CD Workflow](../.github/workflows/cd-user-service.yml)**
