# Getting Started: Hands-On Guide

This guide walks you through **actually using** this reference implementation - not just reading about it, but experiencing the complexity firsthand.

**Time required**: 2-4 hours for full setup

---

## Overview: What You'll Do

By the end of this guide, you'll have:

1. ✅ Cloned the reference implementation
2. ✅ Set up a local Kubernetes cluster
3. ✅ Tested policy enforcement (OPA/Conftest)
4. ✅ Built and scanned a container locally
5. ✅ Deployed a service to local Kubernetes
6. ✅ (Optional) Set up a test GitHub repository with workflows
7. ✅ Experienced the operational complexity firsthand

---

## Part 1: Local Environment Setup

### Prerequisites

**Required Tools** (install these first):

```bash
# 1. Docker Desktop (includes Kubernetes)
# Download from: https://www.docker.com/products/docker-desktop

# 2. kubectl (Kubernetes CLI)
brew install kubectl

# 3. Conftest (Policy testing)
brew install conftest

# 4. Trivy (Container scanning)
brew install aquasecurity/trivy/trivy

# 5. Cosign (Artifact signing)
brew install cosign

# 6. Node.js (for user-service)
brew install node

# 7. Go (for payment-service)
brew install go

# 8. Python (for notification-service)
brew install python@3.11

# 9. Helm (for Kubernetes deployments)
brew install helm

# 10. ArgoCD CLI (optional, for GitOps)
brew install argocd
```

**Verify installations**:

```bash
docker --version
kubectl version --client
conftest --version
trivy --version
cosign version
node --version
go version
python3 --version
helm version
```

---

### Clone the Repository

```bash
# Clone the repo
git clone https://github.com/gregkroon/githubexample.git
cd githubexample

# Explore the structure
ls -la
```

---

## Part 2: Test Policy Enforcement

Let's experience the **first pain point**: Policy enforcement.

### Step 1: Test Dockerfile Policies

```bash
# Navigate to user-service
cd services/user-service

# Test the Dockerfile against policies
conftest test Dockerfile \
  --policy ../../platform/policies/docker \
  --namespace docker

# Expected output: ✅ All policies pass
```

**Try breaking a policy**:

```bash
# Edit Dockerfile - remove the USER directive (line 18)
# Open in your editor and comment out: USER nodejs

# Test again
conftest test Dockerfile \
  --policy ../../platform/policies/docker \
  --namespace docker

# Expected output: ❌ Policy violation - "must specify non-root USER"
```

**Fix it**:

```bash
# Uncomment the USER line
# Test again - should pass
```

### Step 2: Test Kubernetes Policies

```bash
# Test Kubernetes manifests
conftest test k8s/deployment.yaml \
  --policy ../../platform/policies/kubernetes \
  --namespace kubernetes

# Expected output: ❌ Multiple violations because we haven't updated image digest
```

**Why does it fail?** The policy requires:
- Image must use digest (not tag)
- All security contexts must be set
- Resource limits must be defined

**See the actual policy**:

```bash
cat ../../platform/policies/kubernetes/security.rego | grep -A 10 "deny.*digest"
```

---

## Part 3: Build and Scan Locally

Experience the **CI pipeline** locally.

### Step 1: Build Container Image

```bash
# Still in services/user-service
docker build -t user-service:local .

# Verify image was created
docker images | grep user-service
```

### Step 2: Scan for Vulnerabilities

```bash
# Scan with Trivy
trivy image user-service:local

# You'll see a detailed report of vulnerabilities
# This is what runs in CI for EVERY build
```

### Step 3: Run the Service Locally

```bash
# Install dependencies
npm install

# Run tests
npm test

# Start the service
npm start

# In another terminal, test the endpoints
curl http://localhost:3000/health
curl http://localhost:3000/api/users
curl http://localhost:3000/metrics
```

**Stop the service** (Ctrl+C)

---

## Part 4: Deploy to Local Kubernetes

Experience the **deployment complexity**.

### Step 1: Enable Kubernetes in Docker Desktop

1. Open Docker Desktop
2. Settings → Kubernetes
3. ✅ Enable Kubernetes
4. Click "Apply & Restart"
5. Wait for Kubernetes to start (green indicator)

**Verify**:

```bash
kubectl cluster-info
kubectl get nodes
```

### Step 2: Create Namespace

```bash
kubectl create namespace dev
kubectl config set-context --current --namespace=dev
```

### Step 3: Update Kubernetes Manifests

The manifests reference images in GHCR. Let's use our local image:

```bash
# Edit k8s/deployment.yaml
# Change line with image: from
#   image: ghcr.io/yourorg/user-service:latest
# to:
#   image: user-service:local
#   imagePullPolicy: Never  # Use local image

# Also comment out the image digest requirement temporarily
```

Or use this command:

```bash
sed -i '' 's|image: ghcr.io.*user-service.*|image: user-service:local\n        imagePullPolicy: Never|' k8s/deployment.yaml
```

### Step 4: Deploy to Kubernetes

```bash
# Apply the manifests
kubectl apply -f k8s/

# Watch the deployment
kubectl get pods -w

# Wait for pod to be Running (Ctrl+C to stop watching)
```

### Step 5: Test the Deployed Service

```bash
# Port forward to access the service
kubectl port-forward svc/user-service 8080:80

# In another terminal, test
curl http://localhost:8080/health
curl http://localhost:8080/api/users
```

### Step 6: View Logs

```bash
kubectl logs -l app=user-service --tail=50 -f
```

### Step 7: Inspect the Deployment

```bash
# See all resources
kubectl get all

# Describe the deployment
kubectl describe deployment user-service

# Check security context (see all the security configs)
kubectl get pod -l app=user-service -o jsonpath='{.items[0].spec.containers[0].securityContext}' | jq
```

**Notice**: All those security settings you saw in the Kubernetes policy? They're applied here.

---

## Part 5: Experience the Operational Burden

Now let's experience what goes wrong.

### Scenario 1: Policy Violation

```bash
# Edit k8s/deployment.yaml
# Change runAsNonRoot: true to runAsNonRoot: false

# Try to apply
kubectl apply -f k8s/deployment.yaml

# Kubernetes will accept it (no policy enforcement at apply time)
# But Conftest should catch it:
conftest test k8s/deployment.yaml \
  --policy ../../platform/policies/kubernetes \
  --namespace kubernetes

# ❌ Policy violation detected
```

**This exposes a problem**: Policies run in CI, not at deployment time. A developer could bypass them.

### Scenario 2: Resource Issues

```bash
# Edit k8s/deployment.yaml
# Change memory limit from 256Mi to 10Mi (unreasonably low)

kubectl apply -f k8s/deployment.yaml

# Watch what happens
kubectl get pods -w

# Pod will crash loop because Node.js needs more than 10Mi
kubectl describe pod -l app=user-service | grep -A 10 "State:"
```

**Fix it**:

```bash
# Change memory limit back to 256Mi
kubectl apply -f k8s/deployment.yaml
```

### Scenario 3: Image Pull Failure

```bash
# Edit k8s/deployment.yaml
# Change image to: ghcr.io/yourorg/nonexistent:latest

kubectl apply -f k8s/deployment.yaml

# Watch it fail
kubectl get pods

# See the error
kubectl describe pod -l app=user-service | grep -A 5 "Events:"

# ❌ ImagePullBackOff - can't pull image
```

**This is what happens when GHCR has issues or rate limits.**

---

## Part 6: Test Progressive Delivery (Advanced)

This shows the **complexity of canary deployments**.

### Step 1: Install Argo Rollouts

```bash
# Install Argo Rollouts controller
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Verify it's running
kubectl get pods -n argo-rollouts
```

### Step 2: Install Prometheus (for Analysis)

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace \
  --set server.service.type=NodePort

# Verify
kubectl get pods -n monitoring
```

### Step 3: Deploy with Rollout

```bash
# Use the rollout configuration
kubectl apply -f ../../gitops/apps/prod/user-service/rollout.yaml

# Watch the rollout
kubectl argo rollouts get rollout user-service -w

# This will fail because we don't have Istio installed
# This demonstrates the complexity: need Rollouts + Istio + Prometheus
```

**To actually make this work**, you'd need:
1. Istio service mesh (complex installation)
2. VirtualService configuration
3. Prometheus with correct metrics
4. AnalysisTemplate configuration

**This is exactly the operational burden we documented.**

---

## Part 7: Set Up Test GitHub Repository (Optional)

Experience the **full CI/CD pipeline**.

### Step 1: Create a Test Repository

```bash
# Create a new repo on GitHub (use web interface)
# Name it: test-user-service

# Clone it locally
cd ~/
git clone https://github.com/gregkroon/test-user-service.git
cd test-user-service
```

### Step 2: Copy Service Files

```bash
# Copy user-service files
cp -r ~/githubexample/services/user-service/* .

# Initialize git
git add .
git commit -m "Initial commit"
git push
```

### Step 3: Configure GitHub Environments

1. Go to your repo on GitHub
2. Settings → Environments
3. Create environment: `dev`
4. Create environment: `staging`
   - Add protection rule: Require 1 reviewer (add yourself)
5. Create environment: `production`
   - Add protection rule: Require 2 reviewers
   - Add wait timer: 300 seconds

### Step 4: Update Workflow

```bash
# Edit .github/workflows/ci-cd.yml
# Update the workflow to use your organization name instead of "yourorg"

# Search and replace
sed -i '' 's/yourorg/gregkroon/g' .github/workflows/ci-cd.yml

# Commit and push
git add .github/workflows/ci-cd.yml
git commit -m "Update workflow with correct org name"
git push
```

### Step 5: Create Pull Request

```bash
# Create a feature branch
git checkout -b feature/test-deployment

# Make a small change
echo "console.log('Testing CI/CD');" >> src/index.js

# Commit and push
git add src/index.js
git commit -m "feat: test CI/CD pipeline"
git push -u origin feature/test-deployment
```

**On GitHub**:
1. Open a Pull Request
2. Watch the CI workflow run
3. See all the security scans execute
4. Merge the PR
5. Watch the CD workflow deploy to dev → staging → production

**You'll experience**:
- Waiting for workflows to complete (5-15 minutes)
- Approval gates
- Policy enforcement
- The full deployment pipeline

---

## Part 8: Clean Up

### Remove Kubernetes Resources

```bash
# Delete user-service
kubectl delete -f ~/githubexample/services/user-service/k8s/

# Delete Argo Rollouts
kubectl delete -f ~/githubexample/gitops/apps/prod/user-service/rollout.yaml

# Delete Prometheus
helm uninstall prometheus -n monitoring

# Delete Argo Rollouts controller
kubectl delete -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Delete namespaces
kubectl delete namespace dev
kubectl delete namespace monitoring
kubectl delete namespace argo-rollouts
```

### Disable Kubernetes (Optional)

If you want to free up resources:
1. Docker Desktop → Settings → Kubernetes
2. ❌ Disable Kubernetes
3. Apply & Restart

---

## What You've Experienced

### ✅ You've Seen:

1. **Policy enforcement complexity**
   - Conftest requires running before every deployment
   - Policies can be bypassed if not enforced externally
   - False positives require constant tuning

2. **Build and scan overhead**
   - Every build runs 4+ security scans
   - Scan time: 3-10 minutes per build
   - Must handle vulnerabilities before deployment

3. **Kubernetes complexity**
   - Manifests require dozens of security settings
   - Debugging requires understanding pods, deployments, services
   - Errors can occur at multiple layers

4. **Progressive delivery complexity**
   - Requires 4 separate tools (Rollouts, Istio, Prometheus, GitHub Actions)
   - Configuration spread across multiple files
   - Setup time: days to weeks

5. **Integration points**
   - Each component can fail independently
   - Debugging requires checking multiple systems
   - Local testing doesn't guarantee production success

### ❌ You've Experienced:

- **Policy violations** - and how easy they are to bypass
- **Resource constraints** - and how they cause crashes
- **Image pull failures** - simulating registry issues
- **Configuration sprawl** - multiple files to maintain
- **Tool dependencies** - 10+ tools just for local testing

---

## Comparison Exercise

### Time Spent:

- **Setup**: 1-2 hours (installing tools, configuring)
- **Policy testing**: 15 minutes
- **Building/scanning**: 10 minutes
- **Deploying**: 30 minutes
- **Debugging issues**: 30-60 minutes
- **Total**: **3-4 hours** for ONE service

### Now Multiply By:

- **1000 repositories**
- **3 environments each**
- **Daily deployments**
- **Multiple developers**

**This is the operational burden we documented.**

---

## Alternative: Dedicated CD Platform

**With Harness or Spinnaker**:

1. Deploy platform: 2 hours
2. Configure pipeline template: 1 hour
3. Deploy first service: 15 minutes
4. Deploy additional services: 5 minutes each (use template)
5. Built-in: policy enforcement, progressive delivery, rollback

**Total for 1000 services**: ~2 weeks (mostly configuration)

---

## Key Takeaways

After going through this hands-on guide, you should understand:

1. **GitHub Actions for CI is excellent** - the build/test/scan works well
2. **Deployment at scale is complex** - 10+ tools to configure and maintain
3. **Policy enforcement has gaps** - can be bypassed without external enforcement
4. **Progressive delivery requires significant setup** - not out-of-box
5. **Operational burden is real** - you felt it in 3-4 hours for one service

---

## Next Steps

### To Learn More:

1. Read [OPERATIONAL_BURDEN.md](OPERATIONAL_BURDEN.md) - see the day-to-day reality
2. Read [GAPS_ANALYSIS.md](GAPS_ANALYSIS.md) - understand missing features
3. Read [TOOL_INVENTORY.md](TOOL_INVENTORY.md) - see all 24 tools required

### To Go Deeper:

1. Set up ArgoCD completely (follow ArgoCD docs)
2. Install Istio for traffic splitting
3. Configure Prometheus with actual service metrics
4. Build the custom deployment gate webhook
5. Implement DORA metrics collector

**Estimated time**: 4-6 weeks full-time

---

## Questions to Ask Your Team

After completing this guide:

1. How many hours did this take you?
2. How confident are you in debugging issues?
3. How would this scale to 1000 repositories?
4. Who on your team has expertise in all these tools?
5. What's the bus factor if that person leaves?
6. Is building and maintaining this worth it vs using a platform?

---

## Conclusion

**You've now experienced firsthand** what this reference implementation exposes:

- The technical complexity is **manageable**
- The operational burden at scale is **significant**
- The time investment is **substantial**
- The expertise required is **deep**

**The question isn't "Can we do it?"**

**The question is "Should we do it?"**

And after going through this guide, you have the experience to make that decision.

---

**Welcome to the reality of GitHub-native CI/CD at enterprise scale.** 🚀
