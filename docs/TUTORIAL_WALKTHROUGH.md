# Tutorial Walkthrough: Deploy a Feature to Production

**A hands-on, step-by-step guide you can actually execute**

Follow along to deploy a new API endpoint through the complete CI/CD pipeline with all security gates.

**Prerequisites**:
- You've cloned this repository
- You have Node.js installed
- You have a GitHub account

**Time required**: 1-2 hours (if following along) or 20 minutes (if just reading)

---

## What We'll Build

**Feature**: Add a `PUT /api/users/:id` endpoint to update user profiles

**Journey**: Local development → CI pipeline → Dev → Staging → Production

**Result**: Experience all 17 security/compliance gates in action

---

## Part 1: Local Development

### Step 1: Set Up the Project

```bash
# Navigate to the user-service
cd services/user-service

# Install dependencies
npm install

# Run existing tests to verify everything works
npm test

# You should see:
# ✓ User Service API
#   ✓ GET /health
#   ✓ GET /api/users
#   ✓ GET /api/users/:id
#   ✓ POST /api/users
#   ✓ GET /metrics
# Tests: 7 passed, 7 total
```

### Step 2: Start the Service

```bash
# Run the service
npm start

# You should see:
# {"level":"info","message":"User service listening on port 3000"}
```

**In another terminal**, test existing endpoints:

```bash
# Health check
curl http://localhost:3000/health

# Get users
curl http://localhost:3000/api/users

# Get specific user
curl http://localhost:3000/api/users/1
```

Stop the server (Ctrl+C) before proceeding.

---

### Step 3: Create Feature Branch

```bash
# Make sure you're in the services/user-service directory
cd services/user-service

# Initialize git if not already (should already be initialized)
git status

# Create feature branch
git checkout -b feature/user-profile-update

# Verify you're on the new branch
git branch
# Should show: * feature/user-profile-update
```

---

### Step 4: Add the PUT Endpoint

**Edit `src/index.js`**

Add this code **after the POST /api/users endpoint** (after line 94):

```javascript
// Add this new endpoint after the POST /api/users endpoint
app.put('/api/users/:id', (req, res) => {
  const userId = req.params.id;
  const { name, email } = req.body;

  logger.info(`Updating user ${userId}`);

  // Validation
  if (!name && !email) {
    return res.status(400).json({ error: 'At least one field (name or email) required' });
  }

  // Email validation
  if (email && !email.includes('@')) {
    return res.status(400).json({ error: 'Invalid email format' });
  }

  // In production: Update database
  // For now: Return mock updated user
  if (userId === '1') {
    res.json({
      id: parseInt(userId),
      name: name || 'Alice',
      email: email || 'alice@example.com',
      updated_at: new Date().toISOString()
    });
  } else {
    res.status(404).json({ error: 'User not found' });
  }
});
```

**Here's exactly where to add it** in `src/index.js`:

```javascript
// ... existing POST /api/users code (lines 84-94) ...

// 👇 ADD THE NEW ENDPOINT HERE 👇
app.put('/api/users/:id', (req, res) => {
  // ... code from above ...
});

// Graceful shutdown (line 96)
process.on('SIGTERM', () => {
  // ... existing code ...
});
```

---

### Step 5: Add Tests for the New Endpoint

**Edit `src/index.test.js`**

Add this **after the POST /api/users tests** (after line 52):

```javascript
  describe('PUT /api/users/:id', () => {
    it('should update user profile', async () => {
      const res = await request(app)
        .put('/api/users/1')
        .send({ name: 'Alice Updated', email: 'alice.new@example.com' });

      expect(res.statusCode).toBe(200);
      expect(res.body.name).toBe('Alice Updated');
      expect(res.body.email).toBe('alice.new@example.com');
      expect(res.body.updated_at).toBeDefined();
    });

    it('should update only name', async () => {
      const res = await request(app)
        .put('/api/users/1')
        .send({ name: 'Alice Smith' });

      expect(res.statusCode).toBe(200);
      expect(res.body.name).toBe('Alice Smith');
    });

    it('should update only email', async () => {
      const res = await request(app)
        .put('/api/users/1')
        .send({ email: 'alice.updated@example.com' });

      expect(res.statusCode).toBe(200);
      expect(res.body.email).toBe('alice.updated@example.com');
    });

    it('should return 400 if no fields provided', async () => {
      const res = await request(app)
        .put('/api/users/1')
        .send({});

      expect(res.statusCode).toBe(400);
      expect(res.body.error).toBe('At least one field (name or email) required');
    });

    it('should validate email format', async () => {
      const res = await request(app)
        .put('/api/users/1')
        .send({ email: 'invalid-email' });

      expect(res.statusCode).toBe(400);
      expect(res.body.error).toBe('Invalid email format');
    });

    it('should return 404 for non-existent user', async () => {
      const res = await request(app)
        .put('/api/users/999')
        .send({ name: 'Test' });

      expect(res.statusCode).toBe(404);
      expect(res.body.error).toBe('User not found');
    });
  });
```

---

### Step 6: Test Your Changes

```bash
# Run all tests
npm test

# You should now see:
# ✓ User Service API
#   ✓ GET /health
#   ✓ GET /api/users
#   ✓ GET /api/users/:id (existing tests)
#   ✓ POST /api/users (existing tests)
#   ✓ PUT /api/users/:id
#     ✓ should update user profile
#     ✓ should update only name
#     ✓ should update only email
#     ✓ should return 400 if no fields provided
#     ✓ should validate email format
#     ✓ should return 404 for non-existent user
#   ✓ GET /metrics
# Tests: 13 passed, 13 total
```

**If tests pass**, continue. If not, check your code.

---

### Step 7: Test the Endpoint Manually

```bash
# Start the server
npm start
```

**In another terminal**:

```bash
# Test updating both fields
curl -X PUT http://localhost:3000/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Smith", "email": "alice.smith@example.com"}'

# Expected response:
# {
#   "id": 1,
#   "name": "Alice Smith",
#   "email": "alice.smith@example.com",
#   "updated_at": "2024-01-15T10:30:00.000Z"
# }

# Test validation - invalid email
curl -X PUT http://localhost:3000/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"email": "invalid-email"}'

# Expected response:
# {"error": "Invalid email format"}

# Test validation - no fields
curl -X PUT http://localhost:3000/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{}'

# Expected response:
# {"error": "At least one field (name or email) required"}

# Test 404 - non-existent user
curl -X PUT http://localhost:3000/api/users/999 \
  -H "Content-Type: application/json" \
  -d '{"name": "Test"}'

# Expected response:
# {"error": "User not found"}
```

**Stop the server** (Ctrl+C).

✅ **Everything works!**

---

### Step 8: Check Security Locally

```bash
# Check for secrets in code (should return nothing)
git diff | grep -iE "(password|api_key|secret|token)"

# Check for linting issues (if you have eslint configured)
npm run lint 2>/dev/null || echo "No lint script configured (that's OK)"

# All clear ✅
```

---

### Step 9: Commit Your Changes

```bash
# Stage the changes
git add src/index.js src/index.test.js

# Check what will be committed
git status

# Commit with conventional commit format
git commit -m "feat: add PUT endpoint for user profile updates

- Implements PUT /api/users/:id
- Validates email format
- Requires at least one field (name or email)
- Returns 400 for invalid input
- Returns 404 for non-existent users
- Includes comprehensive tests (6 test cases)

This feature allows users to update their profile information
via the API with proper validation."

# Your changes are now committed locally
```

---

## Part 2: Simulated CI/CD Pipeline

Since this is a reference implementation, we'll **simulate** what would happen if you pushed this to GitHub.

### What Would Happen: CI Pipeline

If you pushed to a real GitHub repository with the workflows configured:

#### Job 1: Code Quality & SAST (8 minutes)

```yaml
Running CodeQL Analysis...
✅ No security issues found in JavaScript code

Running Semgrep...
✅ No OWASP vulnerabilities detected

Running Dependency Review...
⚠️  Checking npm dependencies...
✅ No high-severity vulnerabilities
```

#### Job 2: Build & Scan Container (10 minutes)

```yaml
Building Docker image...
✅ Image built: user-service:sha-abc123 (156MB)

Scanning with Trivy...
✅ 0 CRITICAL vulnerabilities
✅ 2 HIGH vulnerabilities (below threshold)
✅ 5 MEDIUM vulnerabilities

Scanning with Grype...
✅ Confirms Trivy results

Generating SBOM with Syft...
✅ SBOM created: 247 packages listed

Signing with Cosign...
✅ Image signed (keyless with OIDC)
✅ Signature: sha256:def456...
```

#### Job 3: Policy Validation (3 minutes)

```yaml
Testing Dockerfile against policies...
✅ Uses approved base image (node:20-alpine)
✅ Runs as non-root user (nodejs:1001)
✅ Has HEALTHCHECK
✅ No secrets in ENV variables

Testing Kubernetes manifests...
✅ Pod security context configured
✅ Resource limits defined
✅ Security context: runAsNonRoot=true
✅ Capabilities dropped: ALL
✅ Read-only root filesystem: true

All policies passed ✅
```

#### Job 4: Deployment Readiness

```yaml
✅ All security scans passed
✅ All policies validated
✅ Artifact signed and verified
✅ Ready for deployment

Service: user-service
Image: ghcr.io/yourorg/user-service@sha256:abc123...
Tests passed: 13/13
Coverage: 94%
```

**Total CI time**: ~15 minutes

---

### Local Policy Testing (You Can Do This)

You can actually test the Dockerfile policy locally:

```bash
# Navigate back to repo root
cd ../..

# Test Dockerfile against policies
docker run --rm -v $(pwd):/project openpolicyagent/conftest test \
  services/user-service/Dockerfile \
  --policy platform/policies/docker \
  --namespace docker

# Expected output:
# WARN - services/user-service/Dockerfile - Recommendation: Use 'npm ci' instead of 'npm install'
# (This is just a warning, not a failure)
```

If you have `conftest` installed locally:

```bash
# Install conftest (macOS)
brew install conftest

# Test Dockerfile
cd services/user-service
conftest test Dockerfile \
  --policy ../../platform/policies/docker \
  --namespace docker

# Test Kubernetes manifests
conftest test k8s/*.yaml \
  --policy ../../platform/policies/kubernetes \
  --namespace kubernetes
```

---

## Part 3: Deployment Simulation

### Deploy to Dev (Simulated)

In a real setup, this would happen automatically after CI passes:

```yaml
Pre-deployment checks...
✅ Verify image signature
✅ Check deployment window (dev: always open)
✅ Custom deployment gate:
   - No active incidents ✅
   - Service health acceptable ✅

Deploying to dev-cluster...
✅ Authenticated via OIDC
✅ Applied Kubernetes manifests
✅ Rollout complete (3 pods running)

Post-deployment verification...
✅ Health check passed
✅ Readiness check passed
✅ Service responding

Continuous verification (5 minutes)...
✅ Error rate: 0.01%
✅ p99 latency: 145ms

Dev deployment: SUCCESS ✅
Time: 5 minutes
```

### Manual Testing in "Dev"

You can test locally as if it were dev:

```bash
# Start the service (simulating dev environment)
cd services/user-service
PORT=3000 npm start
```

**In another terminal**:

```bash
# Test the new endpoint (as if testing in dev)
curl -X PUT http://localhost:3000/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "Dev Test", "email": "test@dev.example.com"}'

# Verify response
# {"id":1,"name":"Dev Test","email":"test@dev.example.com","updated_at":"..."}

# Run smoke tests
curl http://localhost:3000/health
curl http://localhost:3000/api/users
curl http://localhost:3000/api/users/1

# All work ✅
```

Stop the server (Ctrl+C).

---

### Deploy to Staging (Simulated - Requires Approval)

```yaml
Deployment to staging PENDING...

Waiting for approval:
- Reviewers: Tech Leads (1 required)
- Wait timer: 5 minutes minimum
- Custom checks:
  ✅ Dev deployed successfully
  ✅ Dev metrics healthy for 30 minutes
  ✅ No active incidents

[5 minutes pass...]

Approval received from: alice@company.com ✅
Comment: "Dev metrics look good, approved"

Deploying to staging-cluster...
✅ Authenticated via OIDC
✅ Applied manifests to namespace: staging
✅ Rollout complete (5 pods running)

Post-deployment verification...
✅ Health checks passing
✅ Integration tests passed
✅ External API connectivity verified

Continuous verification (10 minutes)...
✅ Error rate: 0.02%
✅ p99 latency: 165ms
✅ Within baseline thresholds

Staging deployment: SUCCESS ✅
Time: 20 minutes (including approval wait)
```

---

### Deploy to Production (Simulated - Requires 2 Approvals)

```yaml
Deployment to production PENDING...

Custom deployment protection rules running...

Check 1: Staging validation
✅ Staging error rate: 0.02% (< 5% threshold)
✅ Staging p99 latency: 165ms (< 500ms threshold)
✅ Staging deployed: 1 hour 15 minutes ago (> 1 hour required)
✅ No incidents in staging

Check 2: Business hours
✅ Current time: 1:30 PM EST
✅ Deployment window: Mon-Fri 9am-5pm
✅ Not a holiday

Check 3: Incident status
✅ No P0 incidents
✅ No P1 incidents
✅ Safe to deploy

Check 4: Compliance
✅ All security scans passed
✅ Image signature verified
✅ Policies validated
✅ Change approved in code review

All gates passed ✅

Waiting for approvals:
- Required: 2 platform engineers
- Wait timer: 30 minutes minimum

[30 minutes pass...]

Approval 1: carol@company.com ✅
Comment: "Staging metrics healthy, approved"

Approval 2: david@company.com ✅
Comment: "Second approval, cleared for production"

Starting progressive deployment...

Phase 1: Canary 10%
- Deployed 1 canary pod (10% traffic)
- Observing for 5 minutes...
- Analysis:
  ✅ Error rate: 0.8% (< 5%)
  ✅ p99 latency: 187ms (< 500ms)
- Canary healthy, proceeding ✅

Phase 2: Canary 25%
- Scaled to 3 pods (25% traffic)
- Observing for 10 minutes...
- Analysis:
  ✅ Error rate: 1.2% (< 5%)
  ✅ p99 latency: 195ms (< 500ms)
  ✅ New endpoint /api/users/:id PUT working
- Canary healthy, proceeding ✅

Phase 3: Canary 50%
- Scaled to 5 pods (50% traffic)
- Observing for 10 minutes...
- Analysis:
  ✅ Error rate: 1.5% (< 5%)
  ✅ p99 latency: 201ms (< 500ms)
  ✅ Throughput stable
- Canary healthy, proceeding ✅

Phase 4: Full rollout
- Scaled to 10 pods (100% new version)
- Final verification (5 minutes)...
- All health checks passing ✅

Production deployment: SUCCESS ✅
Total time: 28 minutes (canary rollout)
Overall time: 1 hour 45 minutes (including approvals)
```

---

## Part 4: Verify Your Work

### Check Your Changes

```bash
# See what you changed
git diff main..feature/user-profile-update

# See your commit
git log --oneline -1

# See test results
cd services/user-service
npm test

# Should show 13 passing tests (6 new ones for PUT endpoint)
```

### Verify Files Changed

```bash
# List changed files
git diff --name-only main

# Should show:
# services/user-service/src/index.js
# services/user-service/src/index.test.js
```

---

## Summary: What You've Done

### ✅ Code Changes:
- Added `PUT /api/users/:id` endpoint (25 lines)
- Added validation for email format
- Added validation for required fields
- Added 404 handling for non-existent users
- Added 6 comprehensive test cases
- All tests passing (13/13)

### ✅ Security Gates (Simulated):
1. ✅ Local security checks
2. ✅ CodeQL SAST scanning
3. ✅ Semgrep security rules
4. ✅ Dependency scanning
5. ✅ Container scanning (Trivy)
6. ✅ Container scanning (Grype)
7. ✅ SBOM generation
8. ✅ Artifact signing (Cosign)
9. ✅ Dockerfile policy validation
10. ✅ Kubernetes policy validation
11. ✅ Image signature verification
12. ✅ Deployment gate checks (dev)
13. ✅ Deployment gate checks (staging)
14. ✅ Deployment gate checks (production)
15. ✅ Code review approval
16. ✅ Staging approval (1 reviewer)
17. ✅ Production approvals (2 reviewers)

### ✅ Deployment Journey:
- Dev: Automated deployment (5 min)
- Staging: 1 approval required (20 min total)
- Production: 2 approvals + progressive delivery (1h 45min total)

### ✅ Total Time (Simulated):
- Development: 30 minutes
- CI pipeline: 15 minutes
- Code review: 45 minutes
- Deployment to dev: 5 minutes
- Deployment to staging: 20 minutes
- Deployment to production: 1h 45min
- **Total: ~4 hours from code to production**

---

## Next Steps

### If You Want to See This in a Real GitHub Repo:

1. **Fork this repository** to your GitHub account
2. **Create the workflows** by copying from `services/user-service/.github/workflows/ci-cd.yml`
3. **Set up GitHub Environments**:
   - Go to Settings → Environments
   - Create: `dev`, `staging`, `production`
   - Configure protection rules as described in [GITHUB_ENVIRONMENTS.md](GITHUB_ENVIRONMENTS.md)
4. **Push your feature branch**:
   ```bash
   git push -u origin feature/user-profile-update
   ```
5. **Create a Pull Request** on GitHub
6. **Watch the CI pipeline run** for real!
7. **Merge and watch CD pipeline** deploy through environments

### Learn More:

- **[DAY_IN_THE_LIFE.md](DAY_IN_THE_LIFE.md)** - Narrative walkthrough with all details
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Set up full local environment
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Understand the full system

---

## Comparison: Real vs Simulated

| Aspect | In This Tutorial | In Real GitHub Repo |
|--------|------------------|---------------------|
| **Code changes** | ✅ Real (you actually did it) | ✅ Real |
| **Tests** | ✅ Real (npm test works) | ✅ Real |
| **Policy checks** | ✅ Real (conftest works) | ✅ Real |
| **CI pipeline** | 📝 Simulated (described) | ✅ Real (GitHub Actions runs) |
| **Container build** | 📝 Simulated | ✅ Real (Docker builds) |
| **Security scans** | 📝 Simulated | ✅ Real (CodeQL, Trivy run) |
| **Deployments** | 📝 Simulated | ✅ Real (to K8s clusters) |
| **Approvals** | 📝 Simulated | ✅ Real (reviewers approve) |
| **Canary rollout** | 📝 Simulated | ✅ Real (Argo Rollouts) |

---

## What You've Learned

### ✅ Developer Experience:
- How to add a feature with proper testing
- What validation and error handling looks like
- How to follow conventional commit standards

### ✅ Security & Governance:
- Multiple security scanning tools catch different issues
- Policies enforce standards (base images, security contexts)
- Every deployment requires signature verification
- Progressive delivery reduces risk

### ✅ Operational Reality:
- **17 security gates** for every deployment
- **Multiple approvals** create safety but add latency
- **Automated testing** catches bugs early
- **Progressive rollout** allows catching issues in 10% of traffic before full deployment

### ✅ Trade-offs:
- **Safety vs Speed**: 4 hours to production (vs 15 minutes with no governance)
- **Automation vs Control**: Automated pipelines with manual approval gates
- **Complexity vs Capability**: 24 tools provide comprehensive coverage but require maintenance

---

## The Bottom Line

You've just walked through adding a simple feature (a PUT endpoint) and experienced:

- ✅ **What works well**: Local testing, automated CI, clear security feedback
- ⚠️ **What adds friction**: Multiple approvals, long wait times, complex policy debugging
- ❌ **What's missing**: One-click rollback, unified observability, centralized config

**This is enterprise-grade CI/CD with GitHub-native tooling.**

**You've experienced it firsthand.**

**Now you can make an informed decision about whether this is the right approach for your organization.**

---

**Want to try this with a real GitHub repository?**

See the "Next Steps" section above to set up your own test environment!
