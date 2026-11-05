# terraform/s3.tf
# S3 Bucket for CloudSieve Pro outputs and artifacts storage

resource "aws_s3_bucket" "results" {
  bucket        = "${var.project_name}-results-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-results"
  }
}

resource "aws_s3_bucket_versioning" "results" {
  bucket = aws_s3_bucket.results.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "results" {
  bucket = aws_s3_bucket.results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "results" {
  bucket = aws_s3_bucket.results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Policy for S3 output storage access
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-results-access"
  description = "Allows read and write access to CloudSieve Pro results S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

# Attach to EKS worker node role so Kubernetes pods can stream outputs directly to S3
resource "aws_iam_role_policy_attachment" "eks_s3_access" {
  count      = var.enable_eks ? 1 : 0
  role       = aws_iam_role.eks_node_role[0].name
  policy_arn = aws_iam_policy.s3_access.arn
}

output "s3_results_bucket" {
  description = "Amazon S3 bucket name for pipeline result CSVs and artifacts"
  value       = aws_s3_bucket.results.id
}

