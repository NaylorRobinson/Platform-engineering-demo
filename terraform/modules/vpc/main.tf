# ══════════════════════════════════════════════════════════════
# VPC MODULE — main.tf
# Builds the entire network foundation for the platform.
# Everything else (EKS, security groups) lives inside this VPC.
# ══════════════════════════════════════════════════════════════

# ── Tell Terraform which providers this module needs ──────────
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── VPC — the top-level network container ─────────────────────
# All subnets, routing, and resources live inside this boundary
resource "aws_vpc" "main" {
  # The IP address range for the entire VPC — /16 gives us 65,536 addresses
  cidr_block = var.vpc_cidr

  # Allows EC2 instances inside the VPC to resolve DNS hostnames
  enable_dns_hostnames = true

  # Allows DNS resolution inside the VPC
  enable_dns_support = true

  # Tags identify this resource in the AWS console and satisfy OPA tagging policy
  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc-${var.environment}"
  })
}

# ── Public Subnets — one per availability zone ────────────────
# Public subnets host the NAT gateway and load balancers
# Resources here can receive inbound traffic from the internet
resource "aws_subnet" "public" {
  # Create one subnet for each AZ provided in var.availability_zones
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  # Slice the CIDR range — e.g. 10.0.1.0/24, 10.0.2.0/24, etc.
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 1)

  # Place each subnet in a different availability zone for redundancy
  availability_zone = var.availability_zones[count.index]

  # Auto-assign public IPs to resources launched in this subnet
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}-${var.environment}"
    # This tag tells the AWS Load Balancer controller this subnet is for public load balancers
    "kubernetes.io/role/elb" = "1"
  })
}

# ── Private Subnets — one per availability zone ───────────────
# EKS worker nodes run here — no direct inbound internet access
# Outbound internet goes through the NAT gateway in the public subnet
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  # Use higher CIDR blocks so private subnets don't overlap with public ones
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 101)

  availability_zone = var.availability_zones[count.index]

  # Private subnets do NOT auto-assign public IPs
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}-${var.environment}"
    # This tag tells the AWS Load Balancer controller this subnet is for internal load balancers
    "kubernetes.io/role/internal-elb" = "1"
    # This tag lets EKS know it can place nodes in this subnet
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  })
}

# ── Internet Gateway — connects the VPC to the internet ───────
# Required for resources in public subnets to reach the internet
# and for inbound traffic from the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw-${var.environment}"
  })
}

# ── Elastic IP for NAT Gateway ────────────────────────────────
# The NAT gateway needs a static public IP address
resource "aws_eip" "nat" {
  # One EIP per public subnet (one per AZ) for high availability
  count = length(var.availability_zones)

  # domain = "vpc" is the modern replacement for the deprecated vpc = true
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-eip-${count.index}-${var.environment}"
  })
}

# ── NAT Gateway — lets private resources reach the internet ───
# EKS nodes in private subnets use the NAT gateway to pull container images,
# call AWS APIs, and reach external services — without being publicly reachable
resource "aws_nat_gateway" "main" {
  # One NAT gateway per AZ for high availability
  count = length(var.availability_zones)

  # NAT gateways must live in a PUBLIC subnet
  subnet_id = aws_subnet.public[count.index].id

  # Attach the Elastic IP we created above
  allocation_id = aws_eip.nat[count.index].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-${var.availability_zones[count.index]}-${var.environment}"
  })

  # The internet gateway must exist before the NAT gateway can be created
  depends_on = [aws_internet_gateway.main]
}

# ── Public Route Table ────────────────────────────────────────
# Routes all outbound traffic from public subnets through the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route all non-local traffic (0.0.0.0/0) to the internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rt-public-${var.environment}"
  })
}

# ── Associate each public subnet with the public route table ──
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Tables — one per AZ ─────────────────────────
# Each private subnet routes outbound traffic through its AZ's NAT gateway
# Using one per AZ avoids cross-AZ data transfer costs
resource "aws_route_table" "private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  # Route all non-local traffic through this AZ's NAT gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rt-private-${var.availability_zones[count.index]}-${var.environment}"
  })
}

# ── Associate each private subnet with its private route table ─
resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
