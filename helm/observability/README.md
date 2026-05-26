# Observability Helm Values

These values are intended for `prometheus-community/kube-prometheus-stack`.

```bash
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm/observability/values.yaml
```

The values enable annotation-based pod scraping so the API can be collected even when the app chart is installed without a ServiceMonitor CRD.

