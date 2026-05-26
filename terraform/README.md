# Terraform

This Terraform baseline provisions:

- AWS VPC with public and private subnets
- EKS cluster with one managed node group
- `platform`, `monitoring`, and `kyverno` namespaces
- Kyverno
- platform Kyverno policies
- kube-prometheus-stack
- the local `helm/app-platform` chart

## Usage

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Before applying the app release, publish backend and frontend images and override:

```bash
terraform apply \
  -var api_image_repository=ghcr.io/your-org/openai-codex-test-api \
  -var web_image_repository=ghcr.io/your-org/openai-codex-test-web \
  -var image_tag=0.1.0
```

After apply:

```bash
aws eks update-kubeconfig --region us-east-1 --name secure-observability-platform
make port-forward
```
