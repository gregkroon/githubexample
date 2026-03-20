# Developer Onboarding Guide

## Welcome to the Platform

This guide walks through how to onboard a new service to our GitHub-native CI/CD platform.

**Estimated time**: 2-4 hours (first time), 30 minutes (once familiar)

---

## Prerequisites

Before you begin, ensure you have:

- [ ] GitHub account with access to `yourorg` organization
- [ ] Member of appropriate team (for deployment approvals)
- [ ] Access to target Kubernetes cluster (for debugging)
- [ ] Familiarity with Docker and Kubernetes basics
- [ ] Read [ARCHITECTURE.md](ARCHITECTURE.md)

---

## Step 1: Create Service Repository

### 1.1 Create Repository from Template

**Option A**: Use GitHub UI
1. Go to https://github.com/yourorg/service-template
2. Click "Use this template"
3. Name: `your-service-name` (e.g., `user-service`)
4. Initialize with template files

**Option B**: Use GitHub CLI
```bash
gh repo create yourorg/your-service-name --template yourorg/service-template --private
```

### 1.2 Verify Template Files

Your new repo should contain:
```
your-service-name/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # ✅ Pre-configured workflow
├── Dockerfile                  # ⚠️ Update for your language
├── k8s/
│   ├── deployment.yaml         # ⚠️ Update service name
│   └── service.yaml            # ⚠️ Update service name
├── src/                        # ⚠️ Your application code
└── README.md
```

---

## Step 2: Configure GitHub Repository Settings

### 2.1 Branch Protection

Protect the `main` branch:

```bash
# Using GitHub CLI
gh api repos/yourorg/your-service-name/branches/main/protection \
  -X PUT \
  -F required_status_checks[strict]=true \
  -F required_status_checks[contexts][]=CI Build & Scan \
  -F required_status_checks[contexts][]=Policy Validation \
  -F required_pull_request_reviews[required_approving_review_count]=1 \
  -F enforce_admins=true
```

Or via GitHub UI:
1. Settings → Branches → Add rule
2. Branch name pattern: `main`
3. ✅ Require pull request before merging
4. ✅ Require status checks to pass
   - Select: "CI Build & Scan"
   - Select: "Policy Validation"
5. ✅ Require linear history
6. Save

### 2.2 Enable GitHub Advanced Security (if available)

1. Settings → Security & analysis
2. ✅ Enable Dependency graph
3. ✅ Enable Dependabot alerts
4. ✅ Enable Dependabot security updates
5. ✅ Enable Code scanning (CodeQL)
6. ✅ Enable Secret scanning

---

## Step 3: Configure GitHub Environments

You need to create 3 environments: `dev`, `staging`, `production`.

### 3.1 Create Environments via UI

For each environment:

1. Settings → Environments → New environment
2. Name: `dev` (then repeat for `staging`, `production`)

#### Dev Environment

- **Protection rules**: None (auto-deploy)
- **Secrets**:
  - `KUBE_CONFIG`: (if not using OIDC)
- **Variables**:
  - `CLUSTER_NAME`: `dev-cluster`
  - `NAMESPACE`: `dev`

#### Staging Environment

- **Protection rules**:
  - ✅ Required reviewers: Select "tech-leads" team (1 required)
  - ✅ Wait timer: 300 seconds (5 minutes)
- **Secrets**:
  - `KUBE_CONFIG`: (if not using OIDC)
- **Variables**:
  - `CLUSTER_NAME`: `staging-cluster`
  - `NAMESPACE`: `staging`

#### Production Environment

- **Protection rules**:
  - ✅ Required reviewers: Select "platform-engineering" team (2 required)
  - ✅ Wait timer: 1800 seconds (30 minutes)
  - ✅ Deployment branches: `main` only
- **Custom deployment protection rules**:
  - Name: `deployment-gate`
  - URL: `https://deployment-gates.example.com/validate/production`
- **Secrets**:
  - `KUBE_CONFIG`: (if not using OIDC)
- **Variables**:
  - `CLUSTER_NAME`: `prod-cluster`
  - `NAMESPACE`: `production`

### 3.2 Automated Environment Setup (Recommended)

**Using our platform automation**:

```bash
# Clone platform tools
git clone https://github.com/yourorg/platform-tools.git
cd platform-tools

# Run environment setup script
./scripts/setup-environments.sh --repo yourorg/your-service-name

# This will:
# - Create 3 environments
# - Configure protection rules
# - Set up secrets and variables
# - Enable required status checks
```

---

## Step 4: Update Application Code

### 4.1 Dockerfile

Ensure your Dockerfile follows our security standards:

**Required**:
- ✅ Use approved base image (see `platform/policies/docker/dockerfile.rego`)
- ✅ Run as non-root user
- ✅ Include HEALTHCHECK

**Example for Node.js**:
```dockerfile
FROM node:20-alpine@sha256:1a24f8e4c96d7d5e5b1d2d5c7d5e5f5a5b5c5d5e5f5a5b5c5d5e5f5a5b5c5d5e

# Non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY --chown=nodejs:nodejs src/ ./src/

USER nodejs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); });"

CMD ["node", "src/index.js"]
```

**Validate locally**:
```bash
# Test policy compliance
docker run --rm -v $(pwd):/project openpolicyagent/conftest test Dockerfile \
  --policy platform/policies/docker \
  --namespace docker
```

### 4.2 Kubernetes Manifests

Update `k8s/deployment.yaml`:

**Required changes**:
```yaml
metadata:
  name: YOUR-SERVICE-NAME  # ⚠️ Update this
  labels:
    app: YOUR-SERVICE-NAME  # ⚠️ Update this

spec:
  selector:
    matchLabels:
      app: YOUR-SERVICE-NAME  # ⚠️ Update this

  template:
    metadata:
      labels:
        app: YOUR-SERVICE-NAME  # ⚠️ Update this
    spec:
      serviceAccountName: YOUR-SERVICE-NAME  # ⚠️ Update this
      containers:
      - name: YOUR-SERVICE-NAME  # ⚠️ Update this
        image: ghcr.io/yourorg/YOUR-SERVICE-NAME:latest  # ⚠️ Update this
```

**Security requirements** (already in template):
- ✅ `runAsNonRoot: true`
- ✅ `allowPrivilegeEscalation: false`
- ✅ `readOnlyRootFilesystem: true`
- ✅ `capabilities.drop: [ALL]`
- ✅ Resource limits defined
- ✅ Liveness and readiness probes

**Validate locally**:
```bash
conftest test k8s/*.yaml \
  --policy platform/policies/kubernetes \
  --namespace kubernetes
```

### 4.3 Application Health Endpoints

Your application MUST expose:

```
GET /health     → {"status": "healthy", "service": "your-service", "version": "1.0.0"}
GET /ready      → {"ready": true}
GET /metrics    → Prometheus-formatted metrics
```

**Example implementation**:

**Node.js/Express**:
```javascript
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'your-service', version: '1.0.0' });
});

app.get('/ready', (req, res) => {
  // Check database connection, etc.
  const ready = checkDependencies();
  res.json({ ready });
});
```

**Go**:
```go
http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
    json.NewEncoder(w).Encode(map[string]string{
        "status": "healthy",
        "service": "your-service",
        "version": "1.0.0",
    })
})
```

---

## Step 5: Update CI/CD Workflow

Edit `.github/workflows/ci-cd.yml`:

### 5.1 Update Service Name

```yaml
jobs:
  ci:
    uses: yourorg/platform/.github/workflows/ci-build-scan.yml@v2.3.0
    with:
      service-name: YOUR-SERVICE-NAME  # ⚠️ Update this
      language: nodejs                 # ⚠️ Update to: nodejs, go, python
```

### 5.2 Configure Deployment Strategy

**Choose deployment model**:

**Option A**: Direct deployment (faster, simpler)
```yaml
deploy-production:
  uses: yourorg/platform/.github/workflows/cd-deploy-direct.yml@v2.3.0
  with:
    service-name: YOUR-SERVICE-NAME
    environment: production
    deployment-strategy: rolling
```

**Option B**: GitOps + Progressive Delivery (production-grade)
```yaml
deploy-production:
  uses: yourorg/platform/.github/workflows/cd-deploy-gitops.yml@v2.3.0
  with:
    service-name: YOUR-SERVICE-NAME
    environment: production
    progressive-delivery: true  # Enables canary deployment
```

---

## Step 6: First Deployment

### 6.1 Test Locally

```bash
# Build Docker image
docker build -t your-service:test .

# Run container
docker run -p 3000:3000 your-service:test

# Test health endpoints
curl http://localhost:3000/health
curl http://localhost:3000/ready
```

### 6.2 Create Feature Branch

```bash
git checkout -b feature/initial-implementation
# Make your changes
git add .
git commit -m "feat: initial service implementation"
git push origin feature/initial-implementation
```

### 6.3 Open Pull Request

1. Go to GitHub → Pull Requests → New
2. Base: `main`, Compare: `feature/initial-implementation`
3. Title: "feat: initial service implementation"
4. Description: Explain what the service does

**CI will automatically run**:
- ✅ Code quality checks
- ✅ SAST scanning (CodeQL, Semgrep)
- ✅ Container build
- ✅ Container scanning (Trivy)
- ✅ Policy validation (OPA)

### 6.4 Review CI Results

Check the "Checks" tab on your PR:

**If all green**:
- ✅ Merge the PR

**If failures**:
- ❌ Fix issues and push new commits
- CI will re-run automatically

Common failures:
- **CodeQL**: Security vulnerabilities in code
- **Trivy**: Vulnerable dependencies in container
- **Policy validation**: Dockerfile or K8s manifest doesn't meet standards

---

## Step 7: Monitor Deployment

### 7.1 Watch GitHub Actions

After merging:

1. Go to Actions tab
2. Watch the workflow run

**Expected flow**:
```
1. CI Build & Scan (5-10 minutes)
   ├── Code quality ✅
   ├── Build image ✅
   ├── Scan image ✅
   ├── Sign image ✅
   └── Policy validation ✅

2. Deploy to Dev (2-5 minutes)
   └── Auto-deployed ✅

3. Deploy to Staging (waiting for approval)
   └── ⏸️ Requires 1 tech lead approval

4. Deploy to Production (waiting)
   └── ⏸️ Requires 2 platform engineer approvals + 30min timer
```

### 7.2 Approve Staging Deployment

If you're a tech lead:
1. Go to the workflow run
2. Review deployment details
3. Click "Review deployments"
4. Select "staging"
5. Approve

### 7.3 Monitor in Kubernetes

```bash
# Watch deployment progress
kubectl get pods -n dev -l app=YOUR-SERVICE-NAME -w

# Check pod logs
kubectl logs -n dev -l app=YOUR-SERVICE-NAME --tail=100 -f

# Check deployment status
kubectl rollout status deployment/YOUR-SERVICE-NAME -n dev
```

### 7.4 Verify Deployment

```bash
# Port-forward to test
kubectl port-forward -n dev svc/YOUR-SERVICE-NAME 8080:80

# Test health endpoint
curl http://localhost:8080/health
```

---

## Step 8: Production Deployment

### 8.1 Request Production Approval

**Before requesting approval**:
- ✅ Verify staging deployment is healthy
- ✅ Run smoke tests in staging
- ✅ Check error rates in staging (Grafana dashboard)
- ✅ Verify no active incidents

### 8.2 Submit Change Request

**In regulated environments**:
1. Create Jira ticket for production deployment
2. Get approval from change management board
3. Link ticket in deployment approval

### 8.3 Approve Production Deployment

Two platform engineers must approve:
1. Go to workflow run
2. Click "Review deployments"
3. Select "production"
4. Add comment: "Approved - all staging checks passed"
5. Approve

**Deployment gate will validate**:
- ✅ Staging metrics are healthy
- ✅ No active P0/P1 incidents
- ✅ Within business hours
- ✅ All compliance checks passed

### 8.4 Monitor Production Deployment

**If using progressive delivery** (GitOps model):

```
1. Canary deployed (10% traffic)
   └── Metrics monitored for 5 minutes

2. If metrics are good:
   └── Increase to 25% traffic
   └── Monitor for 10 minutes

3. If metrics are good:
   └── Increase to 50% traffic
   └── Monitor for 10 minutes

4. If metrics are good:
   └── Promote to 100% (full rollout)
```

**Watch Argo Rollouts**:
```bash
kubectl argo rollouts get rollout YOUR-SERVICE-NAME -n production -w
```

---

## Step 9: Post-Deployment

### 9.1 Verify Production

```bash
# Check deployment status
kubectl get rollout YOUR-SERVICE-NAME -n production

# Check pods
kubectl get pods -n production -l app=YOUR-SERVICE-NAME

# Check logs
kubectl logs -n production -l app=YOUR-SERVICE-NAME --tail=100
```

### 9.2 Monitor Metrics

1. Go to Grafana: https://grafana.example.com
2. Dashboard: "Service Health"
3. Select your service
4. Watch:
   - Request rate
   - Error rate
   - Latency (p50, p95, p99)

### 9.3 Set Up Alerts (Optional)

Create PagerDuty integration:
```yaml
# In k8s/prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: YOUR-SERVICE-NAME-alerts
spec:
  groups:
  - name: YOUR-SERVICE-NAME
    rules:
    - alert: HighErrorRate
      expr: |
        sum(rate(http_requests_total{service="YOUR-SERVICE-NAME",status=~"5.."}[5m])) /
        sum(rate(http_requests_total{service="YOUR-SERVICE-NAME"}[5m])) > 0.05
      for: 5m
      annotations:
        summary: "High error rate detected"
```

---

## Troubleshooting

### Build Failures

**"Unapproved base image"**:
- Use only approved images from `platform/policies/docker/dockerfile.rego`
- Request new base image approval: Slack #platform-team

**"Container has critical vulnerabilities"**:
- Update dependencies in `package.json` / `go.mod` / `requirements.txt`
- Run `npm audit fix` or equivalent

**"Dockerfile policy violation"**:
- Ensure `USER` directive sets non-root user
- Add `HEALTHCHECK` instruction

### Deployment Failures

**"Image signature verification failed"**:
- CI pipeline failed to sign image
- Re-run CI workflow

**"Deployment gate rejected"**:
- Check rejection reason in workflow logs
- Common reasons:
  - Staging has high error rate
  - Active incident in production
  - Outside business hours

**"ArgoCD out of sync"**:
```bash
# Manually sync
argocd app sync YOUR-SERVICE-NAME-production

# Check sync status
argocd app get YOUR-SERVICE-NAME-production
```

**"Pods in CrashLoopBackOff"**:
```bash
# Check logs
kubectl logs -n production -l app=YOUR-SERVICE-NAME --previous

# Common issues:
# - Missing environment variables
# - Database connection failed
# - Port already in use
```

### Policy Violations

**Check policy violations**:
```bash
# Test Dockerfile
conftest test Dockerfile --policy platform/policies/docker

# Test Kubernetes manifests
conftest test k8s/*.yaml --policy platform/policies/kubernetes
```

**Request policy exception**:
1. Create GitHub issue in `platform` repo
2. Explain why exception is needed
3. Platform team will review

---

## Best Practices

### 1. Commit Messages

Use conventional commits:
```
feat: add new endpoint for user profile
fix: resolve memory leak in background worker
chore: update dependencies
docs: update API documentation
```

### 2. PR Size

- Keep PRs small (< 500 lines changed)
- One feature per PR
- Easier to review and rollback

### 3. Testing

```bash
# Run tests before pushing
npm test  # or equivalent

# Ensure tests pass locally
# CI will fail if tests fail
```

### 4. Deployment Timing

**Production deployments**:
- Tuesday-Thursday (avoid Monday and Friday)
- 10 AM - 2 PM (business hours)
- Avoid deployments before holidays
- Have rollback plan ready

### 5. Monitoring

After deployment:
- Watch metrics for 30 minutes
- Check error logs
- Monitor user feedback

---

## Getting Help

**Slack Channels**:
- `#platform-team` - General platform questions
- `#deployments` - Deployment issues
- `#incidents` - Production incidents

**Documentation**:
- [Architecture](ARCHITECTURE.md)
- [Operational Burden](OPERATIONAL_BURDEN.md)
- [Gaps Analysis](GAPS_ANALYSIS.md)

**On-Call**:
- Platform engineering on-call: `/pd trigger platform-oncall`

---

## Summary Checklist

Before your first production deployment:

- [ ] Repository created from template
- [ ] Branch protection enabled
- [ ] GitHub Environments configured (dev, staging, prod)
- [ ] Dockerfile follows security standards
- [ ] Kubernetes manifests validated
- [ ] Health endpoints implemented
- [ ] CI/CD workflow updated with service name
- [ ] PR merged to main
- [ ] Dev deployment successful
- [ ] Staging deployment successful
- [ ] Staging metrics look healthy
- [ ] Production approvals obtained
- [ ] Production deployment successful
- [ ] Metrics monitored post-deployment

---

**Welcome to the platform! 🚀**

**Now go build something amazing.**

**And when deployments break at 2 AM, remember:**
**The platform team is on-call and ready to help.**
