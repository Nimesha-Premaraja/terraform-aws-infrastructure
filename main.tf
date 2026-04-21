provider "aws" {
  region = "us-east-1"
}

module "dev_vpc" {
  source = "./modules/vpc"

  region               = "us-east-1"
  vpc_name             = "dev-vpc"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidr   = "10.0.0.0/24"
  private_subnet_cidr  = "10.0.144.0/20"
  az                   = "us-east-1b"
}