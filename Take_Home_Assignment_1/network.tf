# Create a custom VPC
resource "aws_vpc" "custom_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Create the private subnet for EC2 instance
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false  # EC2 in private subnet won't get public IPs
  tags = {
    Name = "Private Subnet"
  }
}

# Create Public Subnet 1 in AZ us-east-1a
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 1"
  }
}

# Create Public Subnet 2 in AZ us-east-1b
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 2"
  }
}

# Create an internet gateway in the default VPC and attach it to the custom VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id
}

# Create Elastic IP for NAT Gateway in Public Subnet
resource "aws_eip" "nat_eip" {
}

# Create the NAT Gateway in the Public Subnet 1
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
}

# Create Route Table for Public Subnets (with direct access to the internet)
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate the public route table with Public Subnet 1
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate the public route table with Public Subnet 2
resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create a Route Table for Private Subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

# Associate Private Route Table with Private Subnet
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}
