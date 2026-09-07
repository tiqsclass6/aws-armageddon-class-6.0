output "eks_cluster_info" {
  description = "EKS cluster connection details"
  value = {
    name        = aws_eks_cluster.this.name
    endpoint    = aws_eks_cluster.this.endpoint
    arn         = aws_eks_cluster.this.arn
    id          = aws_eks_cluster.this.id
    region      = var.region
  }
}

output "eks_node_group_summary" {
  description = "Summary of EKS node group configuration"
  value = format(
    "Node group '%s' desired=%s type=%s min=%s max=%s",
    aws_eks_node_group.private_nodes.node_group_name,
    aws_eks_node_group.private_nodes.scaling_config[0].desired_size,
    join(", ", aws_eks_node_group.private_nodes.instance_types),
    aws_eks_node_group.private_nodes.scaling_config[0].min_size,
    aws_eks_node_group.private_nodes.scaling_config[0].max_size
  )
}

output "openid_connect_provider" {
  description = "IAM OIDC provider used for IRSA"
  value = {
    arn = aws_iam_openid_connect_provider.oidc_provider.arn
    url = aws_eks_cluster.this.identity[0].oidc[0].issuer
  }
}

output "ebs_csi_iam_role_arn" {
  description = "IRSA role ARN for the EBS CSI controller"
  value       = aws_iam_role.ebs_csi.arn
}

output "vpc_cni_iam_role_arn" {
  description = "IRSA role ARN for the VPC CNI aws-node service account"
  value       = aws_iam_role.vpc_cni.arn
}

output "next_step" {
  description = "Command to install Envoy, Prometheus, and Grafana"
  value       = "kubectl config current-context && ./scripts/install-monitoring.sh"
}
