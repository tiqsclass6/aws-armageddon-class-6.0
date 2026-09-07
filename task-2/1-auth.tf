terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use latest version if possible
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

  }

  backend "s3" {
    bucket  = "armageddon-tiqs-state-files"
    key     = "armageddon/class6/theo-labs/task-2.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}


provider "aws" {
  region  = var.region
  profile = "default"
}