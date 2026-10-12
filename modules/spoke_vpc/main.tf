resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags                 = { Name = var.vpc_name }
}

# Subnets
resource "aws_subnet" "pub_1" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidrs.pub_1
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.vpc_name} Public Subnet AZ1" }
}
resource "aws_subnet" "pub_2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidrs.pub_2
  availability_zone       = var.az_b
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.vpc_name} Public Subnet AZ2" }
}
resource "aws_subnet" "priv_1" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidrs.priv_1
  availability_zone       = var.az_a
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.vpc_name} Private Subnet AZ1" }
}
resource "aws_subnet" "priv_2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidrs.priv_2
  availability_zone       = var.az_b
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.vpc_name} Private Subnet AZ2" }
}
resource "aws_subnet" "tgw_1" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidrs.tgw_1
  availability_zone       = var.az_a
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.vpc_name} TGW Subnet AZ1" }
}
resource "aws_subnet" "tgw_2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidrs.tgw_2
  availability_zone       = var.az_b
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.vpc_name} TGW Subnet AZ2" }
}

# Gateways
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name} IGW" }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_1.id
  tags          = { Name = "${var.vpc_name} NATGW" }
  depends_on    = [aws_internet_gateway.igw]
}

# Route Tables & Associations
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name} Public Route Table" }
}
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.pub_1.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.pub_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name} Private Route Table" }
}
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}
resource "aws_route_table_association" "priv_1" {
  subnet_id      = aws_subnet.priv_1.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "priv_2" {
  subnet_id      = aws_subnet.priv_2.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table" "tgw_rt" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name} TGW Route Table" }
}
resource "aws_route_table_association" "tgw_1" {
  subnet_id      = aws_subnet.tgw_1.id
  route_table_id = aws_route_table.tgw_rt.id
}
resource "aws_route_table_association" "tgw_2" {
  subnet_id      = aws_subnet.tgw_2.id
  route_table_id = aws_route_table.tgw_rt.id
}

# Security Group
resource "aws_security_group" "sg" {
  name        = "${var.vpc_name} Security Group"
  description = "Open-up ports for ICMP"
  vpc_id      = aws_vpc.this.id

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instances
resource "aws_instance" "private_server" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.priv_1.id
  private_ip             = var.server_ip
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile   = var.instance_profile_name
  tags                   = { Name = "${var.vpc_name} Private AZ1 Server" }
}

resource "aws_instance" "public_server" {
  count                       = var.create_public_server ? 1 : 0
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.pub_2.id
  private_ip                  = var.public_server_ip
  vpc_security_group_ids      = [aws_security_group.sg.id]
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true
  tags                        = { Name = "${var.vpc_name} Public AZ2 Server" }
}
