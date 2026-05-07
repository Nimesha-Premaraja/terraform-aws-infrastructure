data "aws_vpc" "dev_vpc" {
  filter {
    name   = "tag:Name"
    values = ["dev-vpc"]
  }
}

data "aws_subnet" "public" {
  filter {
    name   = "tag:Name"
    values = ["dev-vpc-public"]
  }
}

data "aws_subnet" "private" {
  filter {
    name   = "tag:Name"
    values = ["dev-vpc-private"]
  }
}
