variable "aws_region" {
  description = "AWS region for the EKS cluster."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "secure-observability-platform"
}

variable "environment" {
  description = "Environment label applied to provisioned resources."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the platform VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 3
}

variable "cluster_version" {
  description = "Kubernetes version for EKS."
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "EC2 instance types for the default managed node group."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_desired_size" {
  description = "Desired worker node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum worker node count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum worker node count."
  type        = number
  default     = 4
}

variable "platform_namespace" {
  description = "Namespace for application workloads."
  type        = string
  default     = "platform"
}

variable "monitoring_namespace" {
  description = "Namespace for monitoring workloads."
  type        = string
  default     = "monitoring"
}

variable "kyverno_namespace" {
  description = "Namespace for Kyverno."
  type        = string
  default     = "kyverno"
}

variable "api_image_repository" {
  description = "Container image repository for the backend API."
  type        = string
  default     = "ghcr.io/your-org/openai-codex-test-api"
}

variable "web_image_repository" {
  description = "Container image repository for the frontend."
  type        = string
  default     = "ghcr.io/your-org/openai-codex-test-web"
}

variable "image_tag" {
  description = "Container image tag for app releases."
  type        = string
  default     = "0.1.0"
}

variable "tags" {
  description = "Additional tags applied to AWS resources."
  type        = map(string)
  default     = {}
}

