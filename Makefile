.PHONY: help docker-up docker-down logs logs-api logs-web logs-db test k8s-setup k8s-delete install-observability install-security install-apps deploy-all port-forward

KIND_CLUSTER ?= k8s-platform
NAMESPACE ?= platform

help:
	@echo "Available commands:"
	@echo "  make docker-up              Start local platform"
	@echo "  make docker-down            Stop local platform"
	@echo "  make logs                   Stream all local logs"
	@echo "  make logs-api               Stream API logs"
	@echo "  make logs-web               Stream web logs"
	@echo "  make logs-db                Stream database logs"
	@echo "  make test                   Run backend tests"
	@echo "  make k8s-setup              Create Kind cluster and namespaces"
	@echo "  make install-security       Install Kyverno and policies"
	@echo "  make install-observability  Install kube-prometheus-stack"
	@echo "  make install-apps           Install app Helm chart"
	@echo "  make deploy-all             Install full Kubernetes stack"
	@echo "  make port-forward           Forward local service ports"

docker-up:
	docker compose up -d --build

docker-down:
	docker compose down

logs:
	docker compose logs -f

logs-api:
	docker compose logs -f api

logs-web:
	docker compose logs -f web

logs-db:
	docker compose logs -f postgres

test:
	cd backend && python -m pytest

k8s-setup:
	kind create cluster --name $(KIND_CLUSTER) --config kubernetes/kind-config.yaml
	kubectl apply -f kubernetes/namespaces.yaml

k8s-delete:
	kind delete cluster --name $(KIND_CLUSTER)

install-observability:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --values helm/observability/values.yaml

install-security:
	helm repo add kyverno https://kyverno.github.io/kyverno/
	helm repo update
	helm upgrade --install kyverno kyverno/kyverno --namespace kyverno --create-namespace
	helm upgrade --install platform-policies helm/security-policies --namespace kyverno --set targetNamespace=$(NAMESPACE)

install-apps:
	helm upgrade --install app-platform helm/app-platform --namespace $(NAMESPACE) --create-namespace --values helm/app-platform/values.yaml

deploy-all: install-security install-observability install-apps

port-forward:
	kubectl port-forward svc/app-platform-web 5000:8080 -n $(NAMESPACE) &
	kubectl port-forward svc/app-platform-api 8000:8000 -n $(NAMESPACE) &
	kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring &
	kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring &
