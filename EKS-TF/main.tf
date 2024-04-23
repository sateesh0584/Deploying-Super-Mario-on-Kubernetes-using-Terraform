resource "aws_vpc" "main" {
  cidr_block          = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "CZ-IGW"
  }
}

# Create public subnets
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "CZ-Subnet-${count.index + 1}"
  }
}

# Creating Public Route table 1
resource "aws_route_table" "public-rt1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "CZ-Route-1"
  }
}

# Associating the Public Route table 1 with Public Subnet 1
resource "aws_route_table_association" "public-rt-association1" {
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public-rt1.id
}

# Creating Public Route table 2
resource "aws_route_table" "public-rt2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "CZ-Route-2"
  }
}

# Associating the Public Route table 2 with Public Subnet 2
resource "aws_route_table_association" "public-rt-association2" {
  subnet_id      = aws_subnet.public[1].id
  route_table_id = aws_route_table.public-rt2.id
}

# Create security group
resource "aws_security_group" "example_sg" {
  name        = "Ec2-SG"
  description = "Example security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  # Define ingress rules for SSH and HTTP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create IAM role for Cluster 
resource "aws_iam_role" "example_role" {
  name               = "Cluster-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": ["ec2.amazonaws.com", "eks.amazonaws.com"]
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# Create IAM instance profile
resource "aws_iam_instance_profile" "example_instance_profile" {
  name = "Cluster-profile"
  role = aws_iam_role.example_role.name
}

# IAM Role Policies
resource "aws_iam_role_policy_attachment" "iam_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
  role       = aws_iam_role.example_role.name
}
resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.example_role.name
}

resource "aws_iam_role_policy_attachment" "cloudformation_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
  role       = aws_iam_role.example_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.example_role.name
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.example_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.example_role.name
}
# Create EKS Cluster
resource "aws_eks_cluster" "example" {
  name     = "EKS_CLOUD"
  role_arn = aws_iam_role.example_role.arn

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

} 
# Create EKS Node Group
resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "Node-cloud"
  node_role_arn   = aws_iam_role.example_role.arn
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  instance_types = ["t2.small"]

   depends_on = [aws_eks_cluster.example]
}
