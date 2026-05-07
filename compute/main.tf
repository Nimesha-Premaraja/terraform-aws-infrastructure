module "public-instance" {
    depends_on = [ aws_key_pair.dev-key ]
    source  = "terraform-aws-modules/ec2-instance/aws"
    version = "6.4.0"

    name = "dev-public-instance"
    ami = "ami-0ec10929233384c7f"
    associate_public_ip_address = true
    availability_zone = "us-east-1b"
    instance_type   = "t3.micro"
    key_name = aws_key_pair.dev-key.key_name
    subnet_id = module.dev_vpc.public_subnet_id
    vpc_security_group_ids = [aws_security_group.allow_tls.id]

}

module "private-instance" {
    depends_on = [ aws_key_pair.dev-key ]
    source  = "terraform-aws-modules/ec2-instance/aws"
    version = "6.4.0"

    name = "dev-private-instance"
    ami = "ami-0ec10929233384c7f"
    associate_public_ip_address = no
    availability_zone = "us-east-1b"
    instance_type   = "t3.micro"
    key_name = aws_key_pair.dev-key.key_name
    subnet_id = module.dev_vpc.private_subnet_id
    vpc_security_group_ids = [aws_security_group.allow_tls.id]

}

resource "tls_private_key" "dev-rsa-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "dev-key" {
    depends_on = [ tls_private_key.dev-rsa-key ]
  key_name   = "generated-key"
  public_key = tls_private_key.dev-rsa-key.public_key_openssh
}
