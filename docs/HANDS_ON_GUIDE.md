# Hands-On Guide: See It Run, Try It Yourself

**Complete practical guide** - watch it run, set it up locally, try adding a feature, onboard a new service.

> **Consolidates**: Live Deployment, Tutorial Walkthrough, Day in the Life, Getting Started, Onboarding

---

## Table of Contents

1. [Watch It Run (5 min)](#watch-it-run)
2. [Set Up Locally (30 min)](#set-up-locally)
3. [Try It Yourself: Add a Feature (60 min)](#try-it-yourself)
4. [Day in the Life (Developer Journey)](#day-in-the-life)
5. [Onboard a New Service](#onboard-a-new-service)

---

## Watch It Run

**See real CI/CD pipelines execute** - no setup required, just watch.

### Quick Start (2 min)

1. **Visit**: https://github.com/gregkroon/githubexample/actions
2. **Click**: Recent workflow run (e.g., "CI - User Service")
3. **Expand**: Jobs to see all steps

**What you'll see**:
```
✅ Test (npm test with coverage)
✅ Build (Docker build + push to GHCR)
✅ Security Scan (Trivy, Grype finding CVEs)
✅ SBOM (Syft generating software bill of materials)
✅ Sign (Cosign signing image with OIDC)
✅ Policy (Conftest validating Dockerfile, K8s manifests)
```

### Fork and Watch Your Own (5 min)

**Make it yours**:
```bash
# Fork the repository
gh repo fork gregkroon/githubexample

# Clone your fork
gh repo clone yourusername/githubexperiment
cd githubexperiment

# Make a change
echo "// Trigger workflow" >> services/user-service/src/index.js

# Push and watch
git add .
git commit -m "test: trigger CI/CD pipeline"
git push origin main

# Watch it run
gh run watch
```

**What happens**:
```
t=0:   Push detected
t=0:   CI workflow starts
t=1m:  Tests pass
t=2m:  Docker image built
t=3m:  Security scan (Trivy finds vulnerabilities or passes)
t=4m:  SBOM generated
t=5m:  Image signed with Cosign
t=6m:  Policy validation passes
t=7m:  CD workflow starts
t=8m:  Kind cluster created
t=9m:  Service deployed to Kubernetes
t=10m: Smoke tests run
t=11m: ✅ Complete
```

### Explore the Results

**Security scan results**:
- Go to: Security tab → Code scanning alerts
- See: CVEs found by Trivy (if any)

**Container image**:
- Go to: Packages
- See: ghcr.io/yourusername/githubexperiment/user-service:sha-abc123
- Click: See layers, vulnerabilities, SBOM

**Image signature**:
```bash
# Verify the signature
cosign verify \
  --certificate-identity-regexp="https://github.com/yourusername/githubexperiment" \
  ghcr.io/yourusername/githubexperiment/user-service:latest
```

**SBOM**:
- Download artifact from workflow run
- See: Complete software bill of materials (SPDX format)

---

## Set Up Locally

**Run the full pipeline on your machine** - requires Docker, Kind, and tools.

### Prerequisites

**Required tools**:
```bash
# macOS
brew install \
  docker \
  kind \
  kubectl \
  cosign \
  trivy \
  grype \
  syft \
  conftest \
  gh

# Ubuntu
# Install Docker first, then:
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind

# Install kubectl, cosign, trivy, grype, syft, conftest
# (See official installation docs for each tool)
```

### Step 1: Clone and Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/githubexperiment.git
cd githubexperiment

# Verify tools
docker --version
kind --version
kubectl version --client
trivy --version
grype version
syft version
conftest --version
```

### Step 2: Build and Test Locally

```bash
# Go to a service
cd services/user-service

# Install dependencies
npm install

# Run tests
npm test

# Build Docker image
docker build -t user-service:local .

# Run locally
docker run -p 3000:3000 user-service:local

# Test endpoints (in another terminal)
curl http://localhost:3000/health
curl http://localhost:3000/api/users
curl http://localhost:3000/metrics
```

### Step 3: Security Scanning

```bash
# Scan with Trivy
trivy image user-service:local

# Scan with Grype
grype user-service:local

# Generate SBOM
syft user-service:local -o spdx-json > sbom.json

# Validate Dockerfile
conftest test Dockerfile -p ../../platform/policies/docker/
```

### Step 4: Deploy to Local Kubernetes

```bash
# Create Kind cluster
kind create cluster --name githubexperiment

# Load image into Kind
kind load docker-image user-service:local --name githubexperiment

# Deploy
kubectl create namespace user-service
kubectl apply -f k8s/ -n user-service

# Watch rollout
kubectl rollout status deployment/user-service -n user-service

# Port-forward to access
kubectl port-forward -n user-service service/user-service 3000:80

# Test
curl http://localhost:3000/health
```

### Step 5: Clean Up

```bash
# Delete deployment
kubectl delete namespace user-service

# Delete cluster
kind delete cluster --name githubexperiment
```

### Troubleshooting

**Issue**: Docker build fails
```bash
# Check Dockerfile syntax
docker build --no-cache -t user-service:local .

# Check for typos in package.json
cat package.json
```

**Issue**: Tests fail
```bash
# Run tests with verbose output
npm test -- --verbose

# Check test files
ls src/__tests__/
```

**Issue**: Trivy scan fails
```bash
# Update Trivy database
trivy image --download-db-only

# Scan again
trivy image user-service:local
```

**Issue**: Kind cluster won't start
```bash
# Delete and recreate
kind delete cluster --name githubexperiment
kind create cluster --name githubexperiment

# Check Docker is running
docker ps
```

---

## Try It Yourself

**Add a feature and experience the full pipeline** (60 min hands-on).

### The Task: Add a PUT Endpoint

**Goal**: Add `PUT /api/users/:id` to user-service with validation and tests.

---

### Step 1: Write the Code (10 min)

**Edit** `services/user-service/src/index.js`:

```javascript
// Add after GET /api/users endpoint

// PUT /api/users/:id - Update user
app.put('/api/users/:id', (req, res) => {
  const { id } = req.params;
  const { name, email } = req.body;

  // Validation
  if (!name || !email) {
    return res.status(400).json({ error: 'name and email required' });
  }

  if (!email.includes('@')) {
    return res.status(400).json({ error: 'invalid email format' });
  }

  // Update user (in-memory for demo)
  const userIndex = users.findIndex(u => u.id === id);
  if (userIndex === -1) {
    return res.status(404).json({ error: 'user not found' });
  }

  users[userIndex] = { id, name, email };

  res.json(users[userIndex]);
});
```

---

### Step 2: Write Tests (10 min)

**Edit** `services/user-service/src/__tests__/api.test.js`:

```javascript
describe('PUT /api/users/:id', () => {
  it('should update an existing user', async () => {
    const response = await request(app)
      .put('/api/users/1')
      .send({ name: 'Updated Name', email: 'updated@example.com' });

    expect(response.status).toBe(200);
    expect(response.body.name).toBe('Updated Name');
    expect(response.body.email).toBe('updated@example.com');
  });

  it('should return 400 if name missing', async () => {
    const response = await request(app)
      .put('/api/users/1')
      .send({ email: 'test@example.com' });

    expect(response.status).toBe(400);
    expect(response.body.error).toContain('required');
  });

  it('should return 400 if email invalid', async () => {
    const response = await request(app)
      .put('/api/users/1')
      .send({ name: 'Test', email: 'invalid-email' });

    expect(response.status).toBe(400);
    expect(response.body.error).toContain('invalid email');
  });

  it('should return 404 if user not found', async () => {
    const response = await request(app)
      .put('/api/users/999')
      .send({ name: 'Test', email: 'test@example.com' });

    expect(response.status).toBe(404);
    expect(response.body.error).toContain('not found');
  });
});
```

---

### Step 3: Test Locally (5 min)

```bash
cd services/user-service

# Run tests
npm test

# Expected output:
#   PUT /api/users/:id
#     ✓ should update an existing user
#     ✓ should return 400 if name missing
#     ✓ should return 400 if email invalid
#     ✓ should return 404 if user not found
#
#   Test Suites: 1 passed
#   Tests: 8 passed (4 new)

# Build and run locally
docker build -t user-service:local .
docker run -p 3000:3000 user-service:local

# Test the new endpoint
curl -X PUT http://localhost:3000/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated","email":"updated@example.com"}'
```

---

### Step 4: Push and Watch CI/CD (15 min)

```bash
# Commit and push
git add services/user-service/
git commit -m "feat(user-service): add PUT /api/users/:id endpoint"
git push origin main

# Watch the pipeline
gh run watch
```

**What you'll experience**:

**Minute 1-2: Tests**
```
Run npm test
  PASS src/__tests__/api.test.js
  ✓ Tests pass
```

**Minute 2-3: Build**
```
Build Docker image
  Building image...
  Pushing to ghcr.io/yourusername/githubexperiment/user-service:sha-abc123
  ✓ Image pushed
```

**Minute 3-5: Security Scanning**
```
Run Trivy scan
  Scanning ghcr.io/.../user-service:sha-abc123

  Critical: 2
  High: 5
  Medium: 12
  Low: 20

  ❌ FAIL: Critical vulnerabilities found
```

**Wait, what?** 🤔

This is where you experience **security gate enforcement**.

If Trivy finds CRITICAL or HIGH vulnerabilities, the workflow FAILS.

**Your options**:
1. Update dependencies to fix CVEs
2. Add exception to `.trivyignore` (with approval)
3. Wait for upstream fixes

**This is the reality** of enterprise security gates.

---

### Step 5: Fix Security Issues (10 min)

```bash
# Check what's vulnerable
# (Look at Trivy output in workflow logs)

# Example: Update base image
cd services/user-service

# Edit Dockerfile
# FROM: node:18-alpine
# TO:   node:20-alpine (newer, fewer CVEs)

# Rebuild
docker build -t user-service:local .

# Scan locally
trivy image user-service:local

# Push again
git add Dockerfile
git commit -m "fix: update to node:20-alpine for security"
git push origin main

# Watch again
gh run watch
```

---

### Step 6: Watch Deployment (10 min)

**If security scan passes**, CD workflow runs:

```
Deploy to Kind cluster
  Creating Kind cluster...
  Loading image...
  Applying manifests...
  Waiting for rollout...
  ✓ Deployment successful

Run smoke tests
  Testing /health... ✓
  Testing /api/users... ✓
  Testing /api/users/1 (GET)... ✓
  Testing /api/users/1 (PUT)... ✓
  ✓ All smoke tests passed
```

**Your feature is deployed!**

---

### What You Experienced

✅ **Local development** - Write code, run tests
✅ **Security scanning** - Trivy catches CVEs (blocks deployment!)
✅ **Build automation** - Docker image built automatically
✅ **SBOM generation** - Software bill of materials created
✅ **Image signing** - Cosign signs with OIDC
✅ **Policy validation** - Conftest checks Dockerfile, K8s
✅ **Deployment** - Automatic to Kind cluster
✅ **Smoke tests** - Verify endpoints work

**17 security gates** - all automated, all enforced.

**But also experienced**:
- ⚠️ Security scan failure blocking deployment (good!)
- ⚠️ Need to update dependencies (operational burden)
- ⚠️ Workflow takes 8-10 minutes (wait time)

---

## Day in the Life

**Follow a developer through a full day** - realistic scenarios.

### 9:00 AM - Start Work

**Task**: Add metrics endpoint to payment-service

```bash
cd services/payment-service

# Create branch
git checkout -b feat/metrics-endpoint

# Add endpoint (Go code)
# ... write code ...

# Run tests locally
go test ./...

# Commit
git add .
git commit -m "feat: add /metrics endpoint"
git push origin feat/metrics-endpoint
```

---

### 9:15 AM - Create PR

```bash
gh pr create \
  --title "feat: add /metrics endpoint" \
  --body "Adds Prometheus metrics endpoint for payment-service"
```

**CI workflow runs automatically**:
- ✅ Tests pass
- ✅ Build succeeds
- ❌ **Security scan FAILS** - HIGH severity CVE in dependency

---

### 9:30 AM - Fix Security Issue

```
Trivy found: CVE-2024-1234 in golang.org/x/net
Severity: HIGH
Fix: Update to v0.25.0
```

```bash
# Update dependency
go get golang.org/x/net@v0.25.0
go mod tidy

# Test locally
trivy image payment-service:local

# Push fix
git add go.mod go.sum
git commit -m "fix: update golang.org/x/net to fix CVE-2024-1234"
git push origin feat/metrics-endpoint
```

**CI runs again**:
- ✅ Tests pass
- ✅ Security scan passes
- ✅ All checks green

---

### 10:00 AM - Code Review

**Platform team reviews**:

**Reviewer checks**:
1. `.github/workflows/` changes? (CODEOWNERS requires approval)
2. Dockerfile changes? (Platform team approval)
3. New dependencies? (Security team review)

**Comments**:
> "Looks good! But please add a test for the /metrics endpoint."

```bash
# Add test
# ... write test ...

git add .
git commit -m "test: add test for /metrics endpoint"
git push origin feat/metrics-endpoint
```

**Reviewer approves** ✅

---

### 10:30 AM - Merge to Main

```bash
gh pr merge --squash
```

**Post-merge**:
- CI workflow runs on main
- CD workflow starts
- Deploys to **staging** (automatic)
- **Production** requires manual approval (waits)

---

### 11:00 AM - Staging Verification

```bash
# Check staging deployment
kubectl get pods -n payment-service-staging

# Test endpoints
curl https://payment-staging.example.com/health
curl https://payment-staging.example.com/metrics

# Check metrics in Grafana
# (Open browser, verify metrics flowing)
```

**Looks good!** ✅

---

### 11:30 AM - Production Approval

**Platform team approves** production deployment via GitHub UI.

**CD workflow continues**:
- Deploy to production
- Run smoke tests
- ✅ Complete

---

### 12:00 PM - Lunch Break

---

### 1:00 PM - Incident!

**PagerDuty alert**: Payment service error rate spiked!

```
Error rate: 15% (normal: 0.5%)
Affected: /api/payments endpoint
Started: 12:45 PM
```

**Investigation**:
```bash
# Check logs
kubectl logs -n payment-service-prod deployment/payment-service --tail=100

# Found issue: Metrics endpoint consuming too much memory
# Causing OOM kills
```

---

### 1:15 PM - Rollback

**Manual rollback** (no one-click button):
```bash
# Option 1: Git revert
git revert HEAD
git push origin main
# Wait for CI/CD pipeline (8-10 min)

# Option 2: kubectl rollback
kubectl rollout undo deployment/payment-service -n payment-service-prod
# Immediate, but risky (no audit trail)
```

**Choose Option 2** for speed:
```bash
kubectl rollout undo deployment/payment-service -n payment-service-prod

# Verify
kubectl rollout status deployment/payment-service -n payment-service-prod

# Check metrics
# Error rate back to 0.5% ✅
```

**Total incident time**: 30 minutes

---

### 2:00 PM - Postmortem

**What went wrong**:
- New /metrics endpoint had memory leak
- No load testing before production
- Deployment verification only checked HTTP 200, not error rate

**Action items**:
1. Add load tests to CI pipeline
2. Build deployment gate to check error rate (4 weeks of work!)
3. Implement automatic rollback on high error rate

---

### 3:00 PM - Fix the Bug

```bash
git checkout -b fix/metrics-memory-leak

# Fix memory leak
# ... fix code ...

# Add load test
# ... write load test ...

git add .
git commit -m "fix: resolve memory leak in metrics endpoint"
git push origin fix/metrics-memory-leak

# Create PR
gh pr create --title "fix: metrics endpoint memory leak"
```

---

### 4:00 PM - Another Task

**Platform team asks**: "Can you update the deployment to use the new OPA policy?"

```bash
cd services/payment-service

# Update .github/workflows/cd-payment-service.yml
# (Change conftest policy version)

git add .github/workflows/cd-payment-service.yml
git commit -m "chore: update OPA policy version"
git push origin main
```

**CODEOWNERS requires platform team approval** for workflow changes.

**Wait for review**... (30 min - 2 hours)

---

### 5:00 PM - End of Day

**Accomplished**:
- ✅ Added metrics endpoint
- ✅ Fixed security CVE
- ✅ Deployed to production
- ✅ Handled incident (rollback)
- ✅ Fixed bug
- ⏳ Waiting on workflow approval

**Time spent**:
- Feature development: 2 hours
- Security fixes: 1 hour
- Code review iterations: 1 hour
- Incident response: 1.5 hours
- **Pipeline wait times: 1.5 hours** (CI runs, approvals)
- **Manual tasks: 1 hour** (rollback, verification)

**Reality**: 30% of time waiting for pipelines or manual approvals.

---

## Onboard a New Service

**Add a 4th service to the platform** - shows repetition at scale.

### Prerequisites

**You have**:
- New microservice code (example: order-service in Python)
- Dockerfile
- Kubernetes manifests
- Tests

### Step 1: Copy Workflow Template (15 min)

```bash
# Copy user-service workflow as template
cp .github/workflows/ci-user-service.yml .github/workflows/ci-order-service.yml
cp .github/workflows/cd-user-service.yml .github/workflows/cd-order-service.yml

# Edit ci-order-service.yml
# Replace all instances of:
#   user-service → order-service
#   node → python
#   npm → pip

# Edit cd-order-service.yml
# Replace all instances of:
#   user-service → order-service
```

**Time**: 15 minutes per service × 1000 services = **250 hours**

---

### Step 2: Create GitHub Environment (10 min)

**Via GitHub UI**:
```
Repository Settings → Environments → New environment

Name: order-service-staging
Reviewers: @platform-team
Secrets:
  - AWS_ROLE_ARN
  - DATABASE_URL
  - API_KEY

Name: order-service-production
Reviewers: @platform-team, @security-team
Secrets:
  - AWS_ROLE_ARN
  - DATABASE_URL
  - API_KEY
```

**Time**: 10 minutes × 2 environments = **20 minutes per service**

**At 1000 services**: 20 min × 1000 = **333 hours**

---

### Step 3: Configure Secrets (10 min)

```bash
# Via GitHub CLI
gh secret set AWS_ROLE_ARN --env order-service-staging --body "arn:aws:..."
gh secret set DATABASE_URL --env order-service-staging --body "postgres://..."
gh secret set API_KEY --env order-service-staging --body "..."

# Repeat for production environment
gh secret set AWS_ROLE_ARN --env order-service-production --body "arn:aws:..."
gh secret set DATABASE_URL --env order-service-production --body "postgres://..."
gh secret set API_KEY --env order-service-production --body "..."
```

**Time**: 10 minutes per service

---

### Step 4: Add CODEOWNERS (5 min)

```bash
# Edit .github/CODEOWNERS
echo "/services/order-service/ @platform-team" >> .github/CODEOWNERS
```

---

### Step 5: Push and Test (15 min)

```bash
git add .github/workflows/ci-order-service.yml \
        .github/workflows/cd-order-service.yml \
        .github/CODEOWNERS

git commit -m "chore: onboard order-service"
git push origin main

# Watch CI run
gh run watch

# Test deployment
# (Wait for staging approval, approve, verify)
```

---

### Step 6: Documentation (10 min)

- Update README (add order-service to list)
- Update architecture diagram
- Update runbook

---

### Total Time Per Service

| Task | Time |
|------|------|
| Copy and edit workflows | 15 min |
| Create environments | 20 min |
| Configure secrets | 10 min |
| Add CODEOWNERS | 5 min |
| Push and test | 15 min |
| Documentation | 10 min |
| **Total** | **75 minutes** |

**At 1000 services**: 75 min × 1000 = **1,250 hours** (156 days!)

---

### What Gets Repetitive

**Every service needs**:
1. Workflow files (2 files: CI + CD)
2. Environment configuration (2 environments: staging + production)
3. Secrets (3+ per environment)
4. CODEOWNERS entry
5. Testing and verification

**No centralization**.

**Compare to Harness**:
```yaml
# Developer creates one file: harness/pipeline.yml
pipeline:
  template: production-deployment  # ← References centralized template
  variables:
    service: order-service
```

**Time**: 5 minutes per service

---

## The Operational Reality

**What this hands-on guide demonstrates**:

✅ **GitHub CI/CD works** - All 3 (now 4) services have working pipelines
✅ **Security gates work** - Trivy catches CVEs, blocks deployment
✅ **Local development works** - Can build, test, deploy locally

❌ **Repetition at scale** - 75 min onboarding × 1000 services
❌ **Manual approvals** - Platform team reviews everything
❌ **Configuration sprawl** - 3,000 environment configs
❌ **No one-click rollback** - Manual kubectl or wait for git revert pipeline
❌ **Pipeline wait times** - 8-10 min per deployment
❌ **Incident response** - Manual rollback, no automation

**At < 50 services**: Manageable
**At 1000 services**: Operational burden exceeds platform cost

---

**[← Back to README](../README.md)** | **[Quick Start Demo](QUICK_START_DEMO.md)** | **[GitHub Analysis](GITHUB_ANALYSIS.md)**
