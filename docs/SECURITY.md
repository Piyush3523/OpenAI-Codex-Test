# Secure Kubernetes Observability Platform - Security Guide

Complete guide on security best practices, policies, and hardening techniques used in this platform.

---

## 📋 Table of Contents

- [Security Overview](#security-overview)
- [Container Security](#container-security)
- [Kubernetes Security](#kubernetes-security)
- [Network Security](#network-security)
- [Access Control](#access-control)
- [Secret Management](#secret-management)
- [Audit & Compliance](#audit--compliance)
- [Incident Response](#incident-response)

---

## 🔒 Security Overview

### Defense in Depth Strategy

```
Layer 1: Build Time      (Image Security, Scanning)
        ↓
Layer 2: Registry        (Access Control, Image Signing)
        ↓
Layer 3: Admission       (Policy Enforcement)
        ↓
Layer 4: Runtime         (Pod Security, RBAC)
        ↓
Layer 5: Network         (Microsegmentation, TLS)
        ↓
Layer 6: Data            (Encryption, Secrets)
```

---

## 📦 Container Security

### 1. Secure Container Images

#### Base Image Selection

```dockerfile
# Good - Minimal, distroless images
FROM python:3.11-slim-bullseye
# OR
FROM gcr.io/distroless/python3-nonroot

# Bad - Large, full-featured images
FROM ubuntu:latest
FROM centos:latest
```

**Guidelines**:
- Use specific version tags, never `latest`
- Prefer distroless or minimal images
- Regularly update base images
- Scan for vulnerabilities

#### Multi-Stage Builds

```dockerfile
# Good - Smaller final image
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY app.py .
ENV PATH=/root/.local/bin:$PATH
USER nobody
CMD ["python", "app.py"]

# Bad - Large image with build artifacts
FROM python:3.11
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
CMD ["python", "app.py"]
```

**Benefits**:
- Smaller image size (50-80% reduction)
- Fewer vulnerabilities
- Faster deployment

#### Non-Root User

```dockerfile
# Good
FROM python:3.11-slim
RUN useradd -m -u 1000 appuser
WORKDIR /app
COPY --chown=appuser:appuser . .
USER appuser
CMD ["python", "app.py"]

# Bad - Running as root
FROM python:3.11-slim
COPY . /app
WORKDIR /app
CMD ["python", "app.py"]
```

### 2. Vulnerability Scanning with Trivy

#### Scanning Process

```bash
# Scan local image
trivy image python:3.11-slim

# Scan with severity filter
trivy image --severity HIGH,CRITICAL python:3.11-slim

# Generate SBOM (Software Bill of Materials)
trivy image --format cyclonedx --output sbom.json python:3.11-slim

# Scan filesystem
trivy filesystem /path/to/app

# Scan Git repository
trivy repo https://github.com/owner/repo
```

#### CI/CD Integration

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build image
        run: docker build -t app:${{ github.sha }} .
      
      - name: Run Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: app:${{ github.sha }}
          format: sarif
          output: trivy-results.sarif
          severity: HIGH,CRITICAL
      
      - name: Upload to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: trivy-results.sarif
      
      - name: Fail on critical vulnerabilities
        run: |
          if grep -q '"severity":"CRITICAL"' trivy-results.sarif; then
            echo "Critical vulnerabilities found"
            exit 1
          fi
```

---

## ☸️ Kubernetes Security

### 1. Pod Security Standards

#### Security Context Best Practices

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: platform
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: app:latest
    imagePullPolicy: Always
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE  # Only if needed
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    livenessProbe:
      httpGet:
        path: /health
        port: 8000
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /ready
        port: 8000
      initialDelaySeconds: 5
      periodSeconds: 5
  volumes:
  - name: tmp
    emptyDir: {}
```

**Key Settings**:

| Setting | Value | Reason |
|---------|-------|--------|
| `runAsNonRoot` | true | Prevent container escape privilege escalation |
| `runAsUser` | 1000+ | Use non-root UID |
| `readOnlyRootFilesystem` | true | Prevent unauthorized file modifications |
| `allowPrivilegeEscalation` | false | Prevent privilege escalation |
| `capabilities.drop` | ALL | Remove unnecessary capabilities |
| `seccompProfile` | RuntimeDefault | Enable seccomp filtering |

### 2. RBAC (Role-Based Access Control)

#### Service Account Best Practices

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-service
  namespace: platform

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-service-role
  namespace: platform
rules:
# Only grant necessary permissions
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
  resourceNames: ["api-config"]  # Specific resource
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["db-credentials"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: api-service-binding
  namespace: platform
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: api-service-role
subjects:
- kind: ServiceAccount
  name: api-service
  namespace: platform
```

#### Pod Automation Prevention

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: restrict-automation
  namespace: platform
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["list", "watch"]  # No get, create, delete
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["list"]
```

### 3. Resource Quotas & Limits

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: platform-quota
  namespace: platform
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    pods: "100"
    services.nodeports: "10"
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high", "medium"]

---
apiVersion: v1
kind: LimitRange
metadata:
  name: platform-limits
  namespace: platform
spec:
  limits:
  - type: Container
    min:
      cpu: "10m"
      memory: "32Mi"
    max:
      cpu: "1000m"
      memory: "1Gi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
  - type: Pod
    min:
      cpu: "10m"
      memory: "32Mi"
    max:
      cpu: "2000m"
      memory: "2Gi"
```

---

## 🌐 Network Security

### 1. Network Policies (Microsegmentation)

#### Default Deny Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: platform
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

#### Allow Specific Traffic

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: platform
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-api
  namespace: platform
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: ingress-controller
    ports:
    - protocol: TCP
      port: 8000
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8000
```

### 2. TLS/SSL Encryption

#### Certificate Management

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: api-tls
  namespace: platform
spec:
  secretName: api-tls-secret
  commonName: api.platform.svc.cluster.local
  dnsNames:
  - api.platform.svc.cluster.local
  - api.example.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
duration: 2160h  # 90d
renewBefore: 720h  # 30d
```

#### Ingress with TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
  namespace: platform
spec:
  tls:
  - hosts:
    - api.example.com
    secretName: api-tls-secret
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 8000
```

---

## 🔐 Access Control

### 1. RBAC Best Practices

```yaml
# Create specific roles for different needs
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: platform
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch", "patch", "update"]
- apiGroups: [""]
  resources: ["pods", "pods/logs"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: operator-role
  namespace: platform
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-only-role
  namespace: platform
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
```

### 2. Disable Anonymous Access

```yaml
apiVersion: v1
kind: KubeProxyConfiguration
metadata:
  name: kubeproxy
mode: ipvs
clientConnection:
  acceptContentTypes: "application/vnd.kubernetes.protobuf,application/json"
  contentType: "application/vnd.kubernetes.protobuf"
  burst: 200
  kubeconfig: /etc/kubernetes/kubeproxy.conf
  qps: 100
```

---

## 🔑 Secret Management

### 1. Kubernetes Secrets Best Practices

```yaml
# Create secrets via kubectl (not in YAML files)
kubectl create secret generic db-credentials \
  --from-literal=username=dbuser \
  --from-literal=password=$(openssl rand -base64 32) \
  -n platform

# Reference secret in pod
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: platform
spec:
  containers:
  - name: app
    image: app:latest
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
```

### 2. Encryption at Rest

```bash
# Enable encryption at rest in kubeadm config
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
etcd:
  local:
    serverCertSANs:
    - "127.0.0.1"
    peerCertSANs:
    - "127.0.0.1"
    extraArgs:
      cipher-suites: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
  encryption:
    resources:
    - secrets
    provider:
    - aescbc:
        keys:
        - name: key1
          secret: <BASE64_ENCODED_32_BYTE_KEY>
    - identity: {}
```

### 3. External Secret Management

```yaml
# Using External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-store
  namespace: platform
spec:
  provider:
    vault:
      server: https://vault.example.com:8200
      path: secret
      auth:
        kubernetes:
          mountPath: kubernetes
          role: app-role

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
  namespace: platform
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-store
    kind: SecretStore
  target:
    name: db-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: db
      property: username
  - secretKey: password
    remoteRef:
      key: db
      property: password
```

---

## 📋 Audit & Compliance

### 1. Audit Logging

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# All requests at Metadata level
- level: Metadata
  omitStages:
  - RequestReceived
  
# Secret data should not be logged
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
  omitStages:
  - RequestReceived

# Pod exec should be logged at RequestResponse level
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods/exec", "pods/portforward"]

# Default - log at Metadata level
- level: Metadata
  omitStages:
  - RequestReceived
```

### 2. Kyverno Policies

#### Require Resource Limits

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: enforce
  rules:
  - name: validate-resources
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: CPU and memory limits required
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: ?*
                cpu: ?*
```

#### Require Security Context

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-security-context
spec:
  validationFailureAction: enforce
  rules:
  - name: validate-runAsNonRoot
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: Must run as non-root
      pattern:
        spec:
          containers:
          - securityContext:
              runAsNonRoot: true

  - name: validate-allowPrivilegeEscalation
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: Privilege escalation not allowed
      pattern:
        spec:
          containers:
          - securityContext:
              allowPrivilegeEscalation: false
```

#### Restrict Image Registries

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-registries
spec:
  validationFailureAction: enforce
  rules:
  - name: validate-registry
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: Only images from approved registries allowed
      pattern:
        spec:
          containers:
          - image: gcr.io/* | ghcr.io/* | quay.io/*
```

---

## 🚨 Incident Response

### 1. Security Event Monitoring

```bash
# View audit logs
kubectl get events -A --sort-by='.lastTimestamp'

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# View pod logs for errors
kubectl logs <pod-name> -n <namespace> --previous

# Check security policies violations
kubectl get clusterpolicies
kubectl describe clusterpolicy <policy-name>
```

### 2. Incident Checklist

**On Security Incident**:
1. [ ] Isolate affected pods/nodes
2. [ ] Collect logs and evidence
3. [ ] Review audit logs
4. [ ] Check recent deployments
5. [ ] Review RBAC changes
6. [ ] Verify network policies
7. [ ] Check for secret exposure
8. [ ] Notify security team
9. [ ] Plan remediation
10. [ ] Post-incident review

### 3. Pod Termination (If Compromised)

```bash
# Immediately delete potentially compromised pod
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force

# Restart deployment (Kubernetes will respawn pods)
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# Review recent changes
kubectl rollout history deployment/<deployment-name> -n <namespace>

# Revert if necessary
kubectl rollout undo deployment/<deployment-name> -n <namespace>
```

---

## ✅ Security Checklist

Before deployment:

- [ ] Base images scanned for vulnerabilities
- [ ] Non-root user configured
- [ ] Read-only root filesystem
- [ ] Resource limits defined
- [ ] RBAC policies configured
- [ ] Network policies defined
- [ ] Secrets not in Git
- [ ] TLS/SSL enabled
- [ ] Audit logging enabled
- [ ] Pod security policies enforced
- [ ] Regular backups configured
- [ ] Incident response plan documented

---

## 📚 Security Resources

- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)
- [OWASP Top 10 for Kubernetes](https://owasp.org/www-project-kubernetes-top-ten/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Kyverno Documentation](https://kyverno.io/docs/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)

---

**Security is a journey, not a destination. Keep learning and improving!** 🛡️
