resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Public Subnet (for NAT)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.az

  tags = {
    Name = "${var.vpc_name}-private"
  }
}

# Database Subnet
resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.db_subnet_cidr
  availability_zone = var.az

  tags = {
    Name = "${var.vpc_name}-db"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# EIP for NAT
resource "aws_eip" "nat" {
  domain = "vpc"
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.nat.id

  tags = {
    Name = "${var.vpc_name}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.private.id
}

# S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name = "${var.vpc_name}-s3-endpoint"
  }
}
