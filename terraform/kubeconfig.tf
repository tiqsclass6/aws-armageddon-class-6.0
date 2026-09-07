resource "null_resource" "update_kubeconfig" {
  count = var.enable_kubeconfig ? 1 : 0

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
  }

  triggers = {
    cluster_name = aws_eks_cluster.this.name
    endpoint     = aws_eks_cluster.this.endpoint
  }

  depends_on = [aws_eks_cluster.this]
}
