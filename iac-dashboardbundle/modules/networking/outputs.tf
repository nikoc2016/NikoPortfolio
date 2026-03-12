output "vpc_id" {
  value = aws_vpc.dashboard_vpc.id
}

output "vpc_cidr_block" {
  value = aws_vpc.dashboard_vpc.cidr_block
}

output "public_subnets" {
  value = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

output "private_subnet_id" {
  value = aws_subnet.private_subnet.id
}
