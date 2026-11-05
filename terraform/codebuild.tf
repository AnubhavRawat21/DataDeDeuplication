# terraform/codebuild.tf
# AWS CodeBuild Projects for Docker image builds + EKS deployments
# ─────────────────────────────────────────────────────────────────
# All build, push, and deploy operations run on AWS — zero local tooling required.
#
# Projects:
#   1. cloudsieve-build  → Builds both Docker images and pushes to ECR
#   2. cloudsieve-deploy → Applies Kubernetes manifests to EKS

variable "enable_codebuild" {
  description = "Enable AWS CodeBuild projects for Docker build/push and EKS deployment"
  type        = bool
  default     = false
}

# ── IAM Role for CodeBuild ──
resource "aws_iam_role" "codebuild" {
  count = var.enable_codebuild ? 1 : 0
  name  = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-codebuild-role" }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  count = var.enable_codebuild ? 1 : 0
  name  = "${var.project_name}-codebuild-policy"
  role  = aws_iam_role.codebuild[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR — login, push, pull
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      # EKS — update kubeconfig + deploy
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      # CloudWatch Logs — build log streaming
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      # S3 — CodeBuild artifact cache
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      # CodeBuild reports
      {
        Effect   = "Allow"
        Action   = ["codebuild:CreateReportGroup", "codebuild:CreateReport", "codebuild:UpdateReport", "codebuild:BatchPutTestCases"]
        Resource = "*"
      }
    ]
  })
}

# ── CloudWatch Log Group for CodeBuild ──
resource "aws_cloudwatch_log_group" "codebuild_build" {
  count             = var.enable_codebuild ? 1 : 0
  name              = "/aws/codebuild/${var.project_name}-build"
  retention_in_days = 7

  tags = { Name = "${var.project_name}-codebuild-build-logs" }
}

resource "aws_cloudwatch_log_group" "codebuild_deploy" {
  count             = var.enable_codebuild ? 1 : 0
  name              = "/aws/codebuild/${var.project_name}-deploy"
  retention_in_days = 7

  tags = { Name = "${var.project_name}-codebuild-deploy-logs" }
}

# ── Project 1: Build & Push Docker images to ECR ──
resource "aws_codebuild_project" "build" {
  count         = var.enable_codebuild ? 1 : 0
  name          = "${var.project_name}-build"
  description   = "Builds backend and frontend Docker images and pushes to Amazon ECR"
  build_timeout = 30
  service_role  = aws_iam_role.codebuild[0].arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # required for Docker builds

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = "345794120758"
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ECR_BACKEND_REPO"
      value = var.enable_ecr ? aws_ecr_repository.backend[0].name : "cloudsieve-backend"
    }

    environment_variable {
      name  = "ECR_FRONTEND_REPO"
      value = var.enable_ecr ? aws_ecr_repository.frontend[0].name : "cloudsieve-frontend"
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "buildspec-build.yml"

    git_submodules_config {
      fetch_submodules = false
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild_build[0].name
      stream_name = "build-log"
    }
  }

  tags = { Name = "${var.project_name}-build" }
}

# ── Project 2: Deploy Kubernetes Manifests to EKS ──
resource "aws_codebuild_project" "deploy" {
  count         = var.enable_codebuild ? 1 : 0
  name          = "${var.project_name}-deploy"
  description   = "Deploys Kubernetes manifests to Amazon EKS cluster"
  build_timeout = 20
  service_role  = aws_iam_role.codebuild[0].arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = var.eks_cluster_name
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "buildspec-deploy.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild_deploy[0].name
      stream_name = "deploy-log"
    }
  }

  tags = { Name = "${var.project_name}-deploy" }
}

# ── GitHub Webhook for auto-trigger on push to main ──
resource "aws_codebuild_webhook" "build" {
  count        = var.enable_codebuild ? 1 : 0
  project_name = aws_codebuild_project.build[0].name

  build_type = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "refs/heads/main"
    }
  }
}

# ── Outputs ──
output "codebuild_build_project" {
  description = "CodeBuild project for Docker build and ECR push"
  value       = var.enable_codebuild ? aws_codebuild_project.build[0].name : "CodeBuild not enabled"
}

output "codebuild_deploy_project" {
  description = "CodeBuild project for EKS deployment"
  value       = var.enable_codebuild ? aws_codebuild_project.deploy[0].name : "CodeBuild not enabled"
}
