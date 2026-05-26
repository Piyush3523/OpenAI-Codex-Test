provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  common_tags = merge(
    {
      Project     = "OpenAI-Codex-Test"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for index, az in local.azs : cidrsubnet(var.vpc_cidr, 4, index)]
  public_subnets  = [for index, az in local.azs : cidrsubnet(var.vpc_cidr, 8, index + 48)]

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment != "prod"
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true

  enable_irsa = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }

  tags = local.common_tags
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

resource "kubernetes_namespace" "platform" {
  metadata {
    name = var.platform_namespace
    labels = {
      name                                 = var.platform_namespace
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      name = var.monitoring_namespace
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = var.kyverno_namespace
    labels = {
      name = var.kyverno_namespace
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  namespace  = kubernetes_namespace.kyverno.metadata[0].name

  depends_on = [kubernetes_namespace.kyverno]
}

resource "helm_release" "security_policies" {
  name      = "platform-policies"
  chart     = "${path.module}/../helm/security-policies"
  namespace = kubernetes_namespace.kyverno.metadata[0].name

  set {
    name  = "targetNamespace"
    value = kubernetes_namespace.platform.metadata[0].name
  }

  depends_on = [
    helm_release.kyverno,
    kubernetes_namespace.platform,
  ]
}

resource "helm_release" "observability" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    file("${path.module}/../helm/observability/values.yaml"),
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

resource "helm_release" "app_platform" {
  name      = "app-platform"
  chart     = "${path.module}/../helm/app-platform"
  namespace = kubernetes_namespace.platform.metadata[0].name

  values = [
    file("${path.module}/../helm/app-platform/values.yaml"),
  ]

  set {
    name  = "api.image.repository"
    value = var.api_image_repository
  }

  set {
    name  = "api.image.tag"
    value = var.image_tag
  }

  set {
    name  = "web.image.repository"
    value = var.web_image_repository
  }

  set {
    name  = "web.image.tag"
    value = var.image_tag
  }

  depends_on = [
    helm_release.security_policies,
    helm_release.observability,
    kubernetes_namespace.platform,
  ]
}
