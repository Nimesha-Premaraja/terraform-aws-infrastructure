terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.42.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "dev_vpc" {
  source = "../modules/vpc"

  region              = var.region
  vpc_name            = "${var.vpc-prefix}-vpc"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.0.0/24"
  private_subnet_cidr = "10.0.144.0/20"
  db_subnet_cidr      = "10.0.160.0/20"
  az                  = "${var.region}b"
}
