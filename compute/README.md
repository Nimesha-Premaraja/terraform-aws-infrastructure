# Compute

Terraform configuration for AWS EC2 instances and associated security groups in the `us-east-1` region. Provisions a public-facing instance, a private instance, an auto-generated RSA key pair, and a security group allowing TLS traffic.

## Architecture

```
compute/
├── main.tf             # EC2 instances and RSA key pair
├── securty-group.tf    # Security group with ingress/egress rules
└── provider.tf         # AWS and TLS provider version constraints
```

## Resources

### EC2 Instances

Both instances use the [`terraform-aws-modules/ec2-instance/aws`](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest) module at version `6.4.0`.

| Name | Subnet | Public IP | Availability Zone |
|---|---|---|---|
| `dev-public-instance` | Public (`module.dev_vpc.public_subnet_id`) | Yes | `us-east-1b` |
| `dev-private-instance` | Private (`module.dev_vpc.private_subnet_id`) | No | `us-east-1b` |

**Shared configuration:**

| Setting | Value |
|---|---|
| AMI | `ami-0ec10929233384c7f` |
| Instance Type | `t3.micro` |
| Key Pair | `generated-key` (auto-generated) |
| Security Group | `allow_tls` |

Both instances have an explicit `depends_on` the `aws_key_pair.dev-key` resource.

### Key Pair

An RSA-4096 private key is generated at apply time using the `tls` provider and registered with AWS EC2 as `generated-key`.

| Resource | Name | Details |
|---|---|---|
| `tls_private_key.dev-rsa-key` | — | RSA 4096-bit key |
| `aws_key_pair.dev-key` | `generated-key` | Uploads the generated public key to AWS |

> **Security note:** The private key material is stored in Terraform state. Ensure your state backend is encrypted and access-controlled (e.g., S3 with SSE + KMS, restricted IAM policy).

### Security Group (`allow_tls`)

Attached to the VPC provided by the `dev_vpc` module. Uses the newer `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` resources (as opposed to inline rules).

**Ingress:**

| Rule | Protocol | Port | Source |
|---|---|---|---|
| `allow_tls_ipv4` | TCP | 443 | VPC CIDR block (IPv4) |
| `allow_tls_ipv6` | TCP | 443 | VPC CIDR block (IPv6) |

**Egress:**

| Rule | Protocol | Port | Destination |
|---|---|---|---|
| `allow_all_traffic_ipv4` | All (`-1`) | All | `0.0.0.0/0` |
| `allow_all_traffic_ipv6` | All (`-1`) | All | `::/0` |

## Providers

| Provider | Source | Version |
|---|---|---|
| AWS | `hashicorp/aws` | `6.42.0` |
| TLS | `hashicorp/tls` | `4.2.1` |

## Dependencies

This layer reads outputs from the `networking` layer via the `dev_vpc` module. The following values must be available before applying:

| Reference | Used By |
|---|---|
| `module.dev_vpc.public_subnet_id` | `module.public-instance` |
| `module.dev_vpc.private_subnet_id` | `module.private-instance` |
| `module.dev_vpc.vpc_id` | `aws_security_group.allow_tls` |
| `module.dev_vpc.vpc_cidr_block` | `allow_tls_ipv4` ingress rule |
| `module.dev_vpc.vpc_ipv6_cidr_block` | `allow_tls_ipv6` ingress rule |

Apply the `networking` layer first before provisioning compute resources.

## Usage

```bash
# From the compute/ directory
terraform init
terraform plan
terraform apply
```

## Known Issues

| File | Line | Issue |
|---|---|---|
| `main.tf` | 24 | `associate_public_ip_address = no` — `no` is not valid HCL. Should be `false`. |
| `main.tf` | 41 | `tls_private_key.this.public_key_openssh` — references resource name `this` but the resource is declared as `dev-rsa-key`. Should be `tls_private_key.dev-rsa-key.public_key_openssh`. |
| `provider.tf` | 6 | `region = "us-east-1"` inside `required_providers` is not a valid attribute. Region should be set in the `provider "aws" {}` block. |
