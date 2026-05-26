output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint."
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "platform_namespace" {
  description = "Application namespace."
  value       = kubernetes_namespace.platform.metadata[0].name
}

output "grafana_port_forward" {
  description = "Port-forward command for Grafana."
  value       = "kubectl port-forward svc/prometheus-grafana 3000:80 -n ${var.monitoring_namespace}"
}

