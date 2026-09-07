variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region. Balerica HQ is Sao Paulo (sa-east-1); override if the lab should run there."
}

variable "aws_profile" {
  type        = string
  default     = null
  description = "Optional AWS CLI profile. Leave null to use environment credentials."
}

variable "cluster_name" {
  type        = string
  default     = "balerica-task1"
  description = "EKS cluster name"
  nullable    = false
}

variable "vpc_cidr" {
  type        = string
  default     = "10.100.0.0/16"
  description = "VPC CIDR"
}

variable "subnet_cidr_blocks" {
  description = "CIDR blocks for public and private subnets across two AZs"
  type = object({
    private_zone1 = string
    private_zone2 = string
    public_zone1  = string
    public_zone2  = string
  })
  default = {
    private_zone1 = "10.100.0.0/19"
    private_zone2 = "10.100.32.0/19"
    public_zone1  = "10.100.64.0/19"
    public_zone2  = "10.100.96.0/19"
  }
}

variable "enable_kubeconfig" {
  type        = bool
  default     = true
  description = "Update local kubeconfig after cluster create"
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs allowed to reach the EKS public API. Restrict to your IP/32 for least privilege."
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "Worker instance types. t3.small is too small for kube-prometheus-stack plus Envoy."
}

variable "node_desired_size" {
  type        = number
  default     = 3
}

variable "node_min_size" {
  type        = number
  default     = 2
}

variable "node_max_size" {
  type        = number
  default     = 5
}

locals {
  zone1 = "${var.region}a"
  zone2 = "${var.region}b"

  common_tags = {
    Project    = "Armageddon-Task-1"
    Owner      = "Balerica"
    HQ         = "Sao-Paulo"
    ManagedBy  = "Terraform"
    Task       = "network-observability"
  }
}
