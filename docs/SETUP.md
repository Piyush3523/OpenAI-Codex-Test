# Installation & Setup Guide

Complete step-by-step guide for setting up the Secure Kubernetes Observability Platform.

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [Kubernetes Setup](#kubernetes-setup)
- [Helm Installation](#helm-installation)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## ✅ Prerequisites

### System Requirements
- **OS**: Linux, macOS, or Windows with WSL2
- **CPU**: 4 cores minimum (8 recommended)
- **RAM**: 8GB minimum (16GB recommended)
- **Disk**: 30GB free space minimum

### Software Prerequisites

**Install Docker & Docker Compose**:
```bash
# macOS (using Homebrew)
brew install docker docker-compose

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io docker-compose

# Verify installation
docker --version
docker-compose --version
```

**Install Kubernetes Tools**:
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(uname -s | tr '[:upper:]' '[:lower:]')/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Kind (Kubernetes in Docker)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-$(uname)-amd64
chmod +x kind
sudo mv kind /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
kubectl version --client
kind version
helm version
```

**Optional Tools**:
```bash
# Install Make (for running Makefile commands)
# macOS
brew install make

# Ubuntu/Debian
sudo apt-get install build-essential

# Install Trivy (security scanning)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
```

---

## 🐳 Local Development Setup

### 1. Clone Repository

```bash
# Clone the repository
git clone https://github.com/Piyush3523/OpenAI-Codex-Test.git
cd OpenAI-Codex-Test

# List available commands
make help
```

### 2. Start Services with Docker Compose

```bash
# Start all services in background
make docker-up

# Or directly with docker-compose
docker-compose up -d

# Watch startup progress
docker-compose logs -f

# Wait for all services to be healthy (2-3 minutes)
sleep 60
```

### 3. Verify All Services

```bash
# Check service status
docker-compose ps

# Expected output:
# NAME              STATUS           PORTS
# postgres          Up 2 minutes      5432/tcp
# redis             Up 2 minutes      6379/tcp
# api               Up 2 minutes      8000/tcp
# web               Up 2 minutes      5000/tcp
# prometheus        Up 2 minutes      9090/tcp
# grafana           Up 2 minutes      3000/tcp
# loki              Up 2 minutes      3100/tcp
# tempo             Up 2 minutes      3200/tcp
# alertmanager      Up 2 minutes      9093/tcp
```

### 4. Access Local Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **API** | http://localhost:8000 | - |
| **Web App** | http://localhost:5000 | - |
| **Grafana** | http://localhost:3000 | admin / admin |
| **Prometheus** | http://localhost:9090 | - |
| **Loki** | http://localhost:3100 | - |
| **Tempo** | http://localhost:3200 | - |
| **AlertManager** | http://localhost:9093 | - |

### 5. Test API

```bash
# Health check
curl http://localhost:8000/health

# Expected response:
# {"status": "healthy", "timestamp": "2024-01-15T10:30:00Z"}

# Get metrics
curl http://localhost:8000/metrics

# Create a test user
curl -X POST http://localhost:8000/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'
```

### 6. View Logs

```bash
# View logs from all services
make logs

# View specific service logs
make logs-api
make logs-web
make logs-worker
make logs-db
```

---

## ☸️ Kubernetes Setup

### 1. Create Kind Cluster

```bash
# Create cluster (this creates a local Kubernetes cluster in Docker)
make k8s-setup

# Or manually:
kind create cluster --name k8s-platform --config=kubernetes/kind-config.yaml

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

### 2. Verify Cluster Access

```bash
# Check kubeconfig
cat ~/.kube/config | grep kind

# Test API access
kubectl get pods --all-namespaces

# Get cluster info
kubectl version
kubectl get nodes -o wide
```

### 3. Create Namespaces

```bash
# Create required namespaces
kubectl apply -f kubernetes/namespaces.yaml

# Verify namespaces
kubectl get namespaces

# Expected output:
# NAME              STATUS   AGE
# platform          Active   2m
# monitoring        Active   2m
# kyverno           Active   2m
# kube-system       Active   5m
# default           Active   5m
```

---

## 🎯 Helm Installation

### 1. Add Helm Repositories

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Add Grafana repository
helm repo add grafana https://grafana.github.io/helm-charts

# Add Kyverno repository
helm repo add kyverno https://kyverno.github.io/kyverno/

# Update repositories
helm repo update
```

### 2. Install Observability Stack

```bash
# Install Prometheus, Grafana, Loki, Tempo
make install-observability

# Or manually:
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm/observability/values.yaml

# Wait for installation
kubectl wait --for=condition=ready pod \
  -l release=prometheus \
  -n monitoring \
  --timeout=300s
```

### 3. Install Security Policies

```bash
# Install Kyverno
make install-security

# Or manually:
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace

# Apply security policies
kubectl apply -f policies/kyverno/

# Verify policies
kubectl get clusterpolicies
kubectl get policies -A
```

### 4. Deploy Applications

```bash
# Deploy application platform
make install-apps

# Or manually:
helm install app-platform helm/app-platform \
  --namespace platform \
  --create-namespace \
  --values helm/app-platform/values.yaml

# Verify deployments
kubectl get deployments -n platform
kubectl get pods -n platform
```

### 5. Complete Deployment

```bash
# Deploy entire platform at once
make deploy-all

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod \
  --all \
  -n platform \
  --timeout=300s

kubectl wait --for=condition=ready pod \
  --all \
  -n monitoring \
  --timeout=300s
```

---

## ✅ Verification

### 1. Check All Pods

```bash
# Get all pods across namespaces
kubectl get pods --all-namespaces

# Get detailed pod info
kubectl get pods -n platform -o wide
kubectl get pods -n monitoring -o wide
```

### 2. Check Services

```bash
# List all services
kubectl get services --all-namespaces

# Get service endpoints
kubectl get endpoints -A
```

### 3. Check Helm Releases

```bash
# List Helm releases
helm list --all-namespaces

# Check Helm release status
helm status app-platform -n platform
helm status prometheus -n monitoring
```

### 4. Port Forward & Access Services

```bash
# Set up port forwarding
make port-forward

# In another terminal, access services:

# Grafana
open http://localhost:3000

# Prometheus
open http://localhost:9090

# API
curl http://localhost:8000/health

# Web app
open http://localhost:5000
```

### 5. Check Metrics in Prometheus

```bash
# Access Prometheus UI
# http://localhost:9090

# Search for metrics:
# - up (target health)
# - container_cpu_usage_seconds_total (CPU usage)
# - container_memory_usage_bytes (Memory usage)
# - http_requests_total (API requests)
```

### 6. Check Grafana Dashboards

```bash
# Access Grafana
# http://localhost:3000
# Login: admin / admin

# Available dashboards:
# - Kubernetes Cluster Monitoring
# - Pod/Container Overview
# - Application Performance
# - Node Exporter
```

---

## 🔧 Troubleshooting

### Issue: Services Not Starting

```bash
# Check Docker daemon
docker ps

# Check container logs
docker-compose logs -f service-name

# Restart services
docker-compose restart

# Full reset
docker-compose down -v
docker-compose up -d
```

### Issue: Pod CrashLoopBackOff

```bash
# Check pod logs
kubectl logs <pod-name> -n <namespace>

# Get pod events
kubectl describe pod <pod-name> -n <namespace>

# Check resource limits
kubectl top pods -n <namespace>

# Check pod status
kubectl get pods -n <namespace> -o wide
```

### Issue: Persistent Volume Issues

```bash
# Check PVCs
kubectl get pvc -A

# Check PVs
kubectl get pv

# Describe problematic PVC
kubectl describe pvc <pvc-name> -n <namespace>
```

### Issue: Network Connectivity

```bash
# Test DNS resolution
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup api.platform.svc.cluster.local

# Test service connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl http://api.platform:8000/health

# Check network policies
kubectl get networkpolicies -A
kubectl describe networkpolicy <policy-name> -n <namespace>
```

### Issue: High Memory Usage

```bash
# Check memory usage
kubectl top nodes
kubectl top pods -A --sort-by=memory

# Increase limits in values.yaml
# Reinstall or upgrade the chart
helm upgrade <release-name> <chart> -n <namespace> -f values.yaml
```

### Issue: Prometheus Scrape Failures

```bash
# Access Prometheus UI
# http://localhost:9090/targets

# Check for red targets (failed scrapes)
# Click on target to see error message

# Check service endpoints
kubectl get endpoints -n <namespace>

# Verify service selectors
kubectl get services -n <namespace> -o wide
```

---

## 🚀 Next Steps

1. **Explore Dashboards**: Visit Grafana at http://localhost:3000
2. **Check Metrics**: Visit Prometheus at http://localhost:9090
3. **Review Architecture**: Read [docs/ARCHITECTURE.md](ARCHITECTURE.md)
4. **Security**: Review [docs/SECURITY.md](SECURITY.md)
5. **Development**: Start developing with local Docker Compose setup
6. **Deploy to Kubernetes**: Use the provided Helm charts

---

## 📚 Common Commands Reference

```bash
# Docker Compose
docker-compose up -d                    # Start services
docker-compose down                     # Stop services
docker-compose logs -f                  # View logs
docker-compose exec api bash            # Shell into container

# Kubernetes
kubectl get pods -A                     # List pods
kubectl describe pod <name> -n <ns>    # Describe pod
kubectl logs <pod> -n <namespace>      # View logs
kubectl exec -it <pod> -n <ns> bash    # Shell into pod
kubectl apply -f file.yaml              # Apply manifest
kubectl delete -f file.yaml             # Delete manifest
kubectl port-forward <pod> 8000:8000   # Port forward

# Helm
helm install <name> <chart> -n <ns>    # Install chart
helm list -A                            # List releases
helm status <name> -n <namespace>      # Check status
helm upgrade <name> <chart> -n <ns>    # Upgrade release
helm uninstall <name> -n <namespace>   # Uninstall release

# Make
make help                               # Show all commands
make docker-up                          # Start Docker Compose
make k8s-setup                          # Create Kind cluster
make deploy-all                         # Full deployment
make port-forward                       # Set up port forwarding
```

---

## 📞 Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review service logs
3. Check Kubernetes events
4. Open a GitHub issue
5. Contact the maintainers

---

**Happy Deploying! 🚀**
