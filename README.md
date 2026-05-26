# Secure Kubernetes Observability Platform

This repo contains a working baseline for a secure application platform with:

- FastAPI backend with health, readiness, user, and Prometheus metrics endpoints
- React dashboard for service posture and user registry workflows
- Docker Compose for local development
- Helm charts for Kubernetes deployment
- Terraform for AWS EKS infrastructure and release installation
- Kyverno policies for secure workload defaults

## Quick Start

```bash
make docker-up
```

Then open:

- Web: http://localhost:5000
- API: http://localhost:8000
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

## Repository Layout

```text
backend/                 FastAPI service
frontend/                React dashboard served by Nginx
helm/app-platform/       Application Helm chart
helm/observability/      Values for kube-prometheus-stack
helm/security-policies/  Kyverno policy Helm chart
kubernetes/              Kind and namespace manifests
observability/           Local Prometheus, Grafana, Loki, Tempo configs
policies/kyverno/        Cluster policy manifests
terraform/               AWS EKS Terraform baseline
```

## Local Commands

```bash
make help
make docker-up
make logs
make test
make docker-down
```

## Kubernetes Commands

```bash
make k8s-setup
make install-security
make install-observability
make install-apps
make port-forward
```

See [docs/SETUP.md](docs/SETUP.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for more detail.
