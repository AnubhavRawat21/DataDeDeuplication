# terraform/cicd.tf
# Cloud-Native CI/CD Pipeline Infrastructure for CloudSieve Pro
# ──────────────────────────────────────────────────────────────
# 1. GitHub OpenID Connect (OIDC) Provider in AWS IAM
#    Allows GitHub Actions to securely authenticate to AWS without long-lived keys.
# 2. IAM Role for GitHub Actions CI/CD with least-privilege scoping to the repository
# 3. CloudWatch Log Group for CI/CD tracking & auditing

variable "enable_cicd" {
  description = "Provision AWS IAM OIDC and Role for GitHub Actions CI/CD"
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "GitHub repository formatted as 'owner/repo'"
  type        = string
  default     = "am4352/cloudsieve-pro"
}

# ── 1. GitHub OIDC Provider in AWS IAM ──
data "tls_certificate" "github" {
  count = var.enable_cicd ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.enable_cicd ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c587612c62c9540ff93988f6159f80721262d18",
    data.tls_certificate.github[0].certificates[0].sha1_fingerprint
  ]

  tags = {
    Name = "${var.project_name}-github-oidc"
  }
}

# ── 2. IAM Role for GitHub Actions ──
data "aws_iam_policy_document" "github_actions_assume" {
  count = var.enable_cicd ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${var.github_repository}:*",
        "repo:${lower(var.github_repository)}:*"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count              = var.enable_cicd ? 1 : 0
  name               = "${var.project_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume[0].json

  tags = {
    Name = "${var.project_name}-github-actions-role"
  }
}

# IAM Policy for GitHub Actions: ECR, EKS, S3
resource "aws_iam_policy" "github_actions" {
  count       = var.enable_cicd ? 1 : 0
  name        = "${var.project_name}-github-actions-policy"
  description = "Allows GitHub Actions CI/CD to push to ECR, deploy to EKS, and publish artifacts to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.results.arn,
          "${aws_s3_bucket.results.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  count      = var.enable_cicd ? 1 : 0
  role       = aws_iam_role.github_actions[0].name
  policy_arn = aws_iam_policy.github_actions[0].arn
}

output "github_actions_role_arn" {
  description = "AWS IAM Role ARN assumed by GitHub Actions for zero-credential CI/CD"
  value       = var.enable_cicd ? aws_iam_role.github_actions[0].arn : "CI/CD role not enabled"
}

# ── 3. Patch aws-auth ConfigMap to grant GitHub Actions EKS access ──
# EKS cluster uses CONFIG_MAP auth mode (not API mode), so we patch
# aws-auth via a null_resource + local-exec using the EC2's kubeconfig.
# The patch is idempotent — eksctl will not duplicate entries.
resource "null_resource" "patch_aws_auth_github_actions" {
  count = (var.enable_cicd && var.enable_eks) ? 1 : 0

  triggers = {
    role_arn    = aws_iam_role.github_actions[0].arn
    cluster_arn = aws_eks_cluster.main[0].arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region ${var.aws_region} --name ${var.eks_cluster_name}
      kubectl patch configmap aws-auth -n kube-system --type merge -p '{
        "data": {
          "mapRoles": "- rolearn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-eks-node-role\n  groups:\n  - system:bootstrappers\n  - system:nodes\n  username: system:node:{{EC2PrivateDNSName}}\n- rolearn: ${aws_iam_role.github_actions[0].arn}\n  groups:\n  - system:masters\n  username: github-actions\n"
        }
      }'
      echo "aws-auth patched: GitHub Actions role has cluster-admin access"
    EOT
  }

  depends_on = [
    aws_iam_role.github_actions,
    aws_eks_node_group.main,
  ]
}

