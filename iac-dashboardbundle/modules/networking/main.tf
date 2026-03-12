resource "aws_vpc" "dashboard_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.dashboard_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name_prefix}-public-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.dashboard_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name_prefix}-public-2"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.dashboard_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-1a"
  tags = {
    Name = "${var.name_prefix}-private-1"
  }
}

resource "aws_internet_gateway" "dashboard_igw" {
  vpc_id = aws_vpc.dashboard_vpc.id
  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_nat_gateway" "dashboard_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags = {
    Name = "${var.name_prefix}-nat"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.dashboard_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dashboard_igw.id
  }
  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.dashboard_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dashboard_nat.id
  }
  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}
