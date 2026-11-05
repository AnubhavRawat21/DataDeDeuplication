# ──────────────────────────────────────────────────────────────
# CloudSieve Pro — AWS Infrastructure as Code (Terraform)
# Region: ap-southeast-2 (Sydney)
# Provider configuration is in providers.tf
# ──────────────────────────────────────────────────────────────

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ── 1. Fetch Latest Ubuntu 22.04 LTS AMI ──
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── 2. VPC & Networking ──
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ── 3. Security Groups ──
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for CloudSieve Pro EC2 instance"
  vpc_id      = aws_vpc.main.id

  # HTTP (Frontend / Nginx Reverse Proxy)
  ingress {
    description = "HTTP Public Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (TLS/SSL)
  ingress {
    description = "HTTPS Public Access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FastAPI Backend Port (Direct Access / Docs)
  ingress {
    description = "FastAPI Backend Direct Access"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH Access
  ingress {
    description = "SSH Administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # All Outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ── 4. Optional IAM Role & Instance Profile ──
resource "aws_iam_role" "ec2_role" {
  count = var.enable_iam_role ? 1 : 0
  name  = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  count      = var.enable_iam_role ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count      = var.enable_iam_role ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.enable_iam_role ? 1 : 0
  name  = "${var.project_name}-instance-profile"
  role  = aws_iam_role.ec2_role[0].name
}

# ── 5. SSH Key Pair Management ──
resource "tls_private_key" "generated" {
  count     = var.existing_key_name == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  count      = var.existing_key_name == "" ? 1 : 0
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.generated[0].public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  count           = var.existing_key_name == "" ? 1 : 0
  content         = tls_private_key.generated[0].private_key_pem
  filename        = "${path.module}/cloudsieve-key.pem"
  file_permission = "0400"
}

locals {
  key_name = var.existing_key_name != "" ? var.existing_key_name : aws_key_pair.generated[0].key_name
}

# ── 6. CloudWatch Metric Alarms & Optional Logs ──
resource "aws_cloudwatch_log_group" "app_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/${var.project_name}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-log-group"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when EC2 CPU utilization exceeds 80% for 10 minutes"

  dimensions = {
    InstanceId = aws_instance.server.id
  }

  tags = {
    Name = "${var.project_name}-high-cpu"
  }
}

resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "${var.project_name}-status-check-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Alarm when EC2 instance or system status checks fail"

  dimensions = {
    InstanceId = aws_instance.server.id
  }

  tags = {
    Name = "${var.project_name}-status-check"
  }
}

# ── 7. EC2 Compute Instance ──
resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = var.enable_iam_role ? aws_iam_instance_profile.ec2_profile[0].name : null
  key_name               = local.key_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region             = var.aws_region
    project_name           = var.project_name
    github_repo_url        = var.github_repo_url
    github_branch          = var.github_branch
    enable_cloudwatch_logs = var.enable_cloudwatch_logs
    log_group_name         = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.app_logs[0].name : ""
  })

  tags = {
    Name = "${var.project_name}-server"
  }
}

# ── 8. Elastic IP (Static Public IPv4) ──
resource "aws_eip" "server_eip" {
  domain   = "vpc"
  instance = aws_instance.server.id

  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "${var.project_name}-eip"
  }
}
