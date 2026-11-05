# terraform/providers.tf
# Additional Terraform Providers: Kubernetes + Helm
# These connect directly to the EKS cluster — no local kubectl required.
# All operations run on AWS infrastructure.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

# ── Kubernetes Provider (connects to EKS via AWS IAM) ──
provider "kubernetes" {
  host                   = var.enable_eks ? aws_eks_cluster.main[0].endpoint : ""
  cluster_ca_certificate = var.enable_eks ? base64decode(aws_eks_cluster.main[0].certificate_authority[0].data) : ""

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.aws_region]
    command     = "aws"
  }
}

# ── Helm Provider (connects to EKS via AWS IAM) ──
provider "helm" {
  kubernetes {
    host                   = var.enable_eks ? aws_eks_cluster.main[0].endpoint : ""
    cluster_ca_certificate = var.enable_eks ? base64decode(aws_eks_cluster.main[0].certificate_authority[0].data) : ""

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.aws_region]
      command     = "aws"
    }
  }
}
