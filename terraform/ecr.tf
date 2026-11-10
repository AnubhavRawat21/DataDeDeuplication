# terraform/ecr.tf
# Amazon ECR Repositories for CloudSieve Pro Backend and Frontend

variable "enable_ecr" {
  description = "Enable provisioning of Amazon ECR repositories (requires ecr:* IAM permissions)"
  type        = bool
  default     = false
}

resource "aws_ecr_repository" "backend" {
  count                = var.enable_ecr ? 1 : 0
  name                 = "cloudsieve-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "cloudsieve-backend-ecr"
  }
}

resource "aws_ecr_repository" "frontend" {
  count                = var.enable_ecr ? 1 : 0
  name                 = "cloudsieve-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "cloudsieve-frontend-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "backend_policy" {
  count      = var.enable_ecr ? 1 : 0
  repository = aws_ecr_repository.backend[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 15 images"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend_policy" {
  count      = var.enable_ecr ? 1 : 0
  repository = aws_ecr_repository.frontend[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 15 images"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "ecr_backend_url" {
  description = "URL of the cloudsieve-backend ECR repository"
  value       = var.enable_ecr ? aws_ecr_repository.backend[0].repository_url : "ECR not enabled"
}

output "ecr_frontend_url" {
  description = "URL of the cloudsieve-frontend ECR repository"
  value       = var.enable_ecr ? aws_ecr_repository.frontend[0].repository_url : "ECR not enabled"
}

