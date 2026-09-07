# 12b-alb-controller.tf
# IAM Role for AWS Load Balancer Controller (IRSA)
resource "aws_iam_role" "alb_controller" {
  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.oidc_provider.arn
        }
        Condition = {
          StringEquals = {
            "${local.extracted}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-alb-controller-irsa"
  }
}

# Attach ALB Controller Policy
resource "aws_iam_role_policy_attachment" "alb_controller_policy_attach" {
  policy_arn = aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.alb_controller.name
}

# Helm Release – AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  depends_on = [
    aws_iam_role.alb_controller,
    aws_iam_openid_connect_provider.oidc_provider,
    aws_eks_cluster.demo,
    aws_eks_node_group.private-nodes,
    null_resource.update_kubeconfig,
    helm_release.ebs_csi_driver
  ]

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  timeout         = 900
  wait            = true
  cleanup_on_fail = true
  atomic          = false

  set = [
    # REQUIRED
    {
      name  = "clusterName"
      value = aws_eks_cluster.demo.name
    },

    # Region and VPC are required for ALB Controller to auto-discover subnets and security groups
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = aws_vpc.main.id
    },

    # IRSA
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.alb_controller.arn
    },

    # Optional – disable unused features for lab simplicity
    {
      name  = "enableShield"
      value = "false"
    },
    {
      name  = "enableWaf"
      value = "false"
    },
    {
      name  = "enableWafv2"
      value = "false"
    },
  ]
}