# EKS Cluster Outputs
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.EKS-BASE-CONTROL-PLANE.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.EKS-BASE-CONTROL-PLANE.cluster_object.endpoint
}

output "cluster_certificate_authority" {
  description = "EKS cluster CA certificate (base64 encoded)"
  value       = module.EKS-BASE-CONTROL-PLANE.cluster_object.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.EKS-BASE-CONTROL-PLANE.cluster_security_group_id
}

# OIDC Outputs (for IRSA)
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.EKS-BASE-CONTROL-PLANE.oidc_openid_connect
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = module.EKS-BASE-CONTROL-PLANE.oidc_openid_connect_url
}

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.VPC-BASE.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.VPC-BASE.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.VPC-BASE.public_subnet_ids
}
