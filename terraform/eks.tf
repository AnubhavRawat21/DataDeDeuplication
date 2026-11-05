# terraform/eks.tf
# Amazon EKS Cluster, Subnets & Node Group for CloudSieve Pro
# Reuses existing VPC: aws_vpc.main (vpc-0cc5a92193190c9a2)

variable "enable_eks" {
  description = "Enable provisioning of Amazon EKS cluster and node group (requires eks:* and iam:* permissions)"
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
  default     = "cloudsieve-eks"
}

variable "eks_node_instance_type" {
  description = "EC2 Instance type for EKS worker nodes"
  type        = string
  default     = "t3.large"
}

# ── 1. Secondary Public Subnet (in ap-southeast-2b for Multi-AZ EKS requirement) ──
resource "aws_subnet" "public_2" {
  count                   = var.enable_eks ? 1 : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-southeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name                                            = "${var.project_name}-public-subnet-2"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_route_table_association" "public_2" {
  count          = var.enable_eks ? 1 : 0
  subnet_id      = aws_subnet.public_2[0].id
  route_table_id = aws_route_table.public.id
}

# ── 2. Private Subnets for Secure EKS Worker Nodes ──
resource "aws_subnet" "private_1" {
  count             = var.enable_eks ? 1 : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name                                            = "${var.project_name}-private-subnet-1"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "private_2" {
  count             = var.enable_eks ? 1 : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "ap-southeast-2b"

  tags = {
    Name                                            = "${var.project_name}-private-subnet-2"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# ── 3. NAT Gateway for Private Worker Outbound Internet ──
resource "aws_eip" "nat" {
  count  = var.enable_eks ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = var.enable_eks ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

resource "aws_route_table" "private" {
  count  = var.enable_eks ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_1" {
  count          = var.enable_eks ? 1 : 0
  subnet_id      = aws_subnet.private_1[0].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "private_2" {
  count          = var.enable_eks ? 1 : 0
  subnet_id      = aws_subnet.private_2[0].id
  route_table_id = aws_route_table.private[0].id
}

# ── 4. EKS Cluster IAM Role ──
resource "aws_iam_role" "eks_cluster_role" {
  count = var.enable_eks ? 1 : 0
  name  = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role[0].name
}

# ── 5. EKS Worker Nodes IAM Role ──
resource "aws_iam_role" "eks_node_role" {
  count = var.enable_eks ? 1 : 0
  name  = "${var.project_name}-eks-node-role"

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
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role[0].name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_read_only" {
  count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role[0].name
}

# ── 6. EKS Control Plane Cluster ──
resource "aws_eks_cluster" "main" {
  count    = var.enable_eks ? 1 : 0
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role[0].arn
  version  = "1.31"

  vpc_config {
    subnet_ids = [
      aws_subnet.public.id,
      aws_subnet.public_2[0].id,
      aws_subnet.private_1[0].id,
      aws_subnet.private_2[0].id
    ]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = var.eks_cluster_name
  }
}

# ── 7. Managed Node Group ──
resource "aws_eks_node_group" "main" {
  count           = var.enable_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${var.project_name}-managed-nodes"
  node_role_arn   = aws_iam_role.eks_node_role[0].arn
  subnet_ids      = [aws_subnet.private_1[0].id, aws_subnet.private_2[0].id]
  instance_types  = [var.eks_node_instance_type]
  ami_type        = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only,
  ]

  tags = {
    Name = "${var.project_name}-node-group"
  }
}

output "eks_cluster_name" {
  description = "Amazon EKS Cluster Name"
  value       = var.enable_eks ? aws_eks_cluster.main[0].name : "EKS not enabled"
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS Control Plane"
  value       = var.enable_eks ? aws_eks_cluster.main[0].endpoint : "EKS not enabled"
}
