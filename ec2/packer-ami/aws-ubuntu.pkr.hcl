packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "dev-packer-${timestamp}"
  instance_type = "t2.micro"
  region        = var.aws_region
  ami_description = "Ubuntu AMI from Packer build"
  source_ami_filter {
    filters = {
      name                = var.ami_name
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = [var.owner_id] # AMIs owned by Canonical
  }

  run_tags = {
    Name = "packer-builder"
  }

  ssh_username = "ubuntu"
}

build {
  name    = "dev-packer-${timestamp}"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
}


# aws ec2 describe-images \
#   --owners 637423280582 \
#   --filters \
#     "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*" \
#   --query "sort_by(Images,&CreationDate)[-1].[ImageId,Name]" \
#   --output table

# aws ec2 describe-images \
#   --filters \
#     "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*" \
#     "Name=state,Values=available" \
#   --query "sort_by(Images,&CreationDate)[].[ImageId,Name,CreationDate]" \
#   --output table