data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    sid     = "EbsCsiIrsa"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc_provider.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_id}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_id}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_policy" "ebs_csi" {
  name        = "${var.cluster_name}-ebs-csi"
  description = "Least-privilege EBS CSI driver policy (pinned local copy, not fetched from master)"
  policy      = file("${path.module}/policies/ebs-csi-iam-policy.json")
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = aws_iam_policy.ebs_csi.arn
  role       = aws_iam_role.ebs_csi.name
}
