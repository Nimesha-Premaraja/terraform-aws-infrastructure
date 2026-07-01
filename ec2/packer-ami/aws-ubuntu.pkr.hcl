packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name        = "dev-ami-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  instance_type   = "t2.micro"
  region          = var.aws_region
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
  name = "dev-ami-build" # Name of the build within Packer
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    inline = [
      <<EOF
        cat > /home/ubuntu/vm-metadata.txt <<EOT
        VM Metadata
        ===========
        Hostname: $(hostname)
        OS: $(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
        Kernel: $(uname -r)
        Architecture: $(uname -m)
        Memory:
        $(free -h | awk '/^Mem:/ {print "  Total: "$2"\n  Used: "$3"\n  Free: "$4}')
        Build Time: $(date)
        EOT

        chown ubuntu:ubuntu /home/ubuntu/vm-metadata.txt
        chmod 644 /home/ubuntu/vm-metadata.txt
        EOF
    ]
  }
}
