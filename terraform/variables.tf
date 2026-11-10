# terraform/variables.tf
# CloudSieve Pro — Terraform Configuration Variables

variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name prefix used for resource naming and tagging"
  type        = string
  default     = "cloudsieve-pro"
}

variable "environment" {
  description = "Deployment environment (production, staging, development)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
  default     = "ap-southeast-2a"
}

variable "instance_type" {
  description = "EC2 Instance type"
  type        = string
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Root EBS gp3 volume size in GB"
  type        = number
  default     = 20
}

variable "github_repo_url" {
  description = "Git clone URL of your repository/fork"
  type        = string
  default     = "https://github.com/am4352/cloudsieve-pro.git"
}

variable "github_branch" {
  description = "Git branch to clone and deploy"
  type        = string
  default     = "main"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block permitted to access SSH (port 22)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "existing_key_name" {
  description = "Name of an existing EC2 Key Pair in ap-southeast-2. If left empty, Terraform will generate a new key pair and output cloudsieve-key.pem locally."
  type        = string
  default     = ""
}

variable "enable_iam_role" {
  description = "Whether to create and attach an IAM role/instance profile to the EC2 instance (set to false if terraform-user lacks iam:CreateRole permission)"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_logs" {
  description = "Whether to create a CloudWatch Log Group for container logs (set to false if terraform-user lacks logs:CreateLogGroup permission)"
  type        = bool
  default     = false
}
