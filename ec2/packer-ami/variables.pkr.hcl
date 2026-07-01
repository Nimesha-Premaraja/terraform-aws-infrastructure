variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "owner_id" {
  type    = string
  default = "099720109477"
}

variable "ami_name" {
  type    = string
  default = "ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-20260421"
}