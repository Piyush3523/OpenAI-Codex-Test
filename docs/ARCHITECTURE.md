# Architecture

The platform is a small, secure-by-default Kubernetes application stack for application and cluster observability.

## Components

| Component | Path | Purpose |
| --- | --- | --- |
| Backend API | `backend/` | FastAPI service with health, readiness, user registry, and Prometheus metrics |
| Frontend | `frontend/` | React operational dashboard served by unprivileged Nginx |
| Local stack | `docker-compose.yml` | Postgres, Redis, API, web, Prometheus, Grafana, Loki, Tempo, Alertmanager |
| App Helm chart | `helm/app-platform/` | API, web, Postgres, Redis, probes, PDBs, network policies |
| Policy Helm chart | `helm/security-policies/` | Kyverno policies scoped to the platform namespace |
| Observability values | `helm/observability/` | kube-prometheus-stack values and annotation scraping |
| Terraform | `terraform/` | AWS VPC, EKS, namespaces, Kyverno, monitoring, and app releases |

## Request Flow

```text
Browser
  -> Web service / Nginx
  -> /api proxy
  -> FastAPI backend
  -> Postgres and Redis
```

Prometheus scrapes `/metrics` from the API. Grafana is provisioned with Prometheus, Loki, and Tempo data sources for local development.

## Security Baseline

Application workloads are configured with:

- non-root users
- dropped Linux capabilities
- disabled privilege escalation
- read-only root filesystems
- resource requests and limits
- readiness and liveness probes
- namespace Pod Security Standards
- Kyverno enforcement for platform workloads
- NetworkPolicy isolation between web, API, Postgres, Redis, DNS, and monitoring

## Deployment Model

Local development uses Docker Compose. Kubernetes development uses Kind plus Helm. Cloud deployment uses Terraform to provision EKS and install the Helm releases.

The Terraform baseline assumes AWS because no cloud provider was specified. The Helm charts are cloud portable and can be installed on any conformant Kubernetes cluster.

