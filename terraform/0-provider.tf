terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Optional remote state. Uncomment after creating the bucket.
  # backend "s3" {
  #   bucket  = "your-terraform-state-bucket"
  #   key     = "armageddon/task-1/terraform.tfstate"
  #   region  = "us-east-1"
  #   encrypt = true
  # }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.this.name
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
