output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "vpc_ipv6_cidr_block" {
  value = aws_vpc.this.ipv6_cidr_block
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "db_subnet_id" {
  value = aws_subnet.db.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.nat.id
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}
