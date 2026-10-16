output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_arn" {
  value = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group EKS attaches to the control plane and managed nodes."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  # Referencing the node group makes consumers wait until nodes exist.
  value = aws_eks_node_group.default.node_group_name
}

output "pod_identity_trust_policy" {
  description = "Trust policy for IAM roles used through EKS Pod Identity."
  value       = data.aws_iam_policy_document.pod_identity_trust.json
}

output "addons_ready" {
  description = "Depend on this to wait for the core add-ons (including the Pod Identity agent)."
  value       = [for a in aws_eks_addon.core : a.arn]
}
