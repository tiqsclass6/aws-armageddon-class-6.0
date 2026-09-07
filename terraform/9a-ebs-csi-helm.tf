resource "helm_release" "ebs_csi_driver" {
  name       = "${var.cluster_name}-aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"

  depends_on = [
    aws_iam_role.ebs_csi,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
    aws_eks_node_group.private_nodes,
    null_resource.update_kubeconfig
  ]

  set = [
    {
      name  = "controller.serviceAccount.create"
      value = "true"
    },
    {
      name  = "controller.serviceAccount.name"
      value = "ebs-csi-controller-sa"
    },
    {
      name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.ebs_csi.arn
    },
    {
      name  = "controller.replicaCount"
      value = "2"
    }
  ]
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  depends_on = [helm_release.ebs_csi_driver]
}
