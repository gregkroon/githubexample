# Real CI/CD Workflows - ALL 3 SERVICES ACTUALLY RUNNING

**These workflows run on EVERY push to `main` and actually deploy ALL 3 services.**

> 🔍 **Notice**: These workflow files MUST exist in this repo. Even with "reusable workflows", you can't avoid creating files in every repository. **[See why GitHub templates aren't like Harness →](../../docs/WHY_GITHUB_TEMPLATES_FAIL.md)**

---

## What's Here - EVERYTHING IS REAL

### ✅ Real Workflows (Run Automatically)

**User Service (Node.js)**

**[ci-user-service.yml](ci-user-service.yml)** - Runs on push to `main`
- Builds Docker image → Pushes to GHCR
- Scans for vulnerabilities (Trivy, Grype)
- Generates SBOM with Syft
- Signs image with Cosign
- Validates policies with Conftest
- **Time**: ~5-7 minutes

**[cd-user-service.yml](cd-user-service.yml)** - Runs after CI succeeds
- Creates Kind (Kubernetes) cluster
- Deploys user-service
- Runs smoke tests
- **Time**: ~3-4 minutes

---

**Payment Service (Go)**

**[ci-payment-service.yml](ci-payment-service.yml)** - Runs on push to `main`
- Tests with Go test suite
- Builds Docker image → Pushes to GHCR
- Scans for vulnerabilities (Trivy, Grype)
- Generates SBOM with Syft
- Signs image with Cosign
- Validates policies with Conftest
- **Time**: ~5-7 minutes

**[cd-payment-service.yml](cd-payment-service.yml)** - Runs after CI succeeds
- Creates Kind (Kubernetes) cluster
- Deploys payment-service
- Runs smoke tests
- **Time**: ~3-4 minutes

---

**Notification Service (Python)**

**[ci-notification-service.yml](ci-notification-service.yml)** - Runs on push to `main`
- Tests with pytest
- Builds Docker image → Pushes to GHCR
- Scans for vulnerabilities (Trivy, Grype)
- Generates SBOM with Syft
- Signs image with Cosign
- Validates policies with Conftest
- **Time**: ~5-7 minutes

**[cd-notification-service.yml](cd-notification-service.yml)** - Runs after CI succeeds
- Creates Kind (Kubernetes) cluster
- Deploys notification-service
- Runs smoke tests
- **Time**: ~3-4 minutes

---

**Manual Rollback**

**[rollback-manual.yml](rollback-manual.yml)** - Manual trigger only
- Shows the MANUAL rollback process
- Creates rollback commit
- Waits for CI/CD to re-run
- **Time**: 11+ minutes total
- **Compare to Harness**: < 60 seconds

---

## What's Different from `/platform/.github/workflows/`

| Location | Status | Purpose |
|----------|--------|---------|
| **`/.github/workflows/`** (here) | ✅ **ACTUALLY RUNS** | Real pipelines that execute on push |
| `/platform/.github/workflows/` | 📚 **REFERENCE ONLY** | Example reusable workflows for documentation |

**The workflows here prove everything WORKS.**

**The workflows in `/platform/` show what you'd need to build at scale.**

---

## Check If They're Running

Go to: https://github.com/gregkroon/githubexample/actions

You'll see **ALL 3 SERVICES** building and deploying:
- **CI - User Service** (runs on push to services/user-service/**)
- **CD - User Service** (runs after CI)
- **CI - Payment Service** (runs on push to services/payment-service/**)
- **CD - Payment Service** (runs after CI)
- **CI - Notification Service** (runs on push to services/notification-service/**)
- **CD - Notification Service** (runs after CI)
- **Manual Rollback** (workflow_dispatch only)

**This proves the operational burden scales linearly**: 3 services = 6 workflows × 1000 services = 6000 workflows to maintain.



## Try It Yourself

### 1. Fork the Repo

Fork this repository to your GitHub account.

### 2. Make a Change

```bash
# Edit something in user-service
echo "console.log('Test deployment');" >> services/user-service/src/index.js

git add .
git commit -m "Test real CI/CD"
git push origin main
```

### 3. Watch It Run

Go to your fork's Actions tab:
```
https://github.com/YOUR_USERNAME/githubexample/actions
```

Watch:
- CI workflow build and scan (7 min)
- CD workflow deploy to Kind (4 min)
- Total: ~11 minutes from push to deployed

### 4. Try Manual Rollback

After deployment completes:

1. Go to Actions tab
2. Select "Manual Rollback - User Service"
3. Click "Run workflow"
4. Enter a previous commit SHA
5. Watch the manual rollback process (11+ min)

**Compare to Harness**: Click "Rollback" button → < 60 seconds


---

**[← Back to README](../../README.md)** | **[See What's Missing](../../docs/GITHUB_GAPS_REAL.md)** | **[Harness Comparison](../../docs/HARNESS_COMPARISON.md)**
