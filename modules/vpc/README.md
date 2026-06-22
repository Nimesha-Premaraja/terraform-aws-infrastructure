# AWS VPC Terraform Module

This Terraform module provisions a standard, secure AWS Virtual Cloud (VPC) network architecture. It sets up public, private, and database subnets across a single Availability Zone, along with an Internet Gateway, NAT Gateway, and an S3 Gateway VPC Endpoint.

## Architecture & Features

```
┌────────────────────────────────────────────────────────────────────────┐
│                              AWS REGION                                │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                            VPC (DEV)                             │  │
│  │                                                                  │  │
│  │  ┌─────────────────────────┐  ┌───────────────────────────────┐  │  │
│  │  │      PUBLIC SUBNET      │  │        PRIVATE SUBNET         │  │  │
│  │  │                         │  │                               │  │  │
│  │  │  ┌───────────────────┐  │  │  ┌─────────────────────────┐  │  │  │
│  │  │  │    NAT Gateway    │◄─┼──┼──┤    Private Instance     │  │  │  │
│  │  │  └─────────┬─────────┘  │  │  └─────────────────────────┘  │  │  │
│  │  │            │            │  │                               │  │  │
│  │  │  ┌─────────▼─────────┐  │  │  ┌─────────────────────────┐  │  │  │
│  │  │  │  Public Instance  │  │  │  │   S3 Gateway Endpoint   │  │  │  │
│  │  │  └───────────────────┘  │  │  └────────────┬────────────┘  │  │  │
│  │  └────────────┬────────────┘  └───────────────┼───────────────┘  │  │
│  │               │                               │                  │  │
│  └───────────────┼───────────────────────────────┼──────────────────┘  │
│                  │ (Internet Gateway)            │ (Internal Routing)  │
│                  ▼                               ▼                     │
│           Public Internet                    Amazon S3                 │
└────────────────────────────────────────────────────────────────────────┘
```

This module deploys and configures the following AWS resources:

- **VPC**: Enabled with DNS hostnames.
- **Subnets**:
  - **Public Subnet**: Automatically maps public IPs on launch, houses the NAT Gateway, and has a route to the Internet Gateway (IGW).
  - **Private Subnet**: For internal resources that route outbound internet traffic through the NAT Gateway.
  - **Database Subnet**: Dedicated subnet for database or stateful resources, also routing outbound traffic through the NAT Gateway.
- **Gateways**:
  - **Internet Gateway (IGW)**: For public internet access to/from the public subnet.
  - **NAT Gateway**: Resides in the public subnet to enable secure outbound internet access for private and database subnets.
- **VPC Endpoints**:
  - **S3 Gateway Endpoint**: Configured in the private route table to allow optimized, private communication with Amazon S3 without traversing the public internet.

---

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  region               = "us-east-1"
  vpc_name             = "production-vpc"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidr   = "10.0.1.0/24"
  private_subnet_cidr  = "10.0.2.0/24"
  db_subnet_cidr       = "10.0.3.0/24"
  az                   = "us-east-1a"
}
```

---

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

---

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |

---

## Created AWS Resources & Usage

This module creates and manages the following AWS resources to form a cohesive, secure network topology:

### 1. `aws_vpc.dev` (Virtual Private Cloud)
*   **Purpose**: Serves as the fundamental network boundary and container for your isolated infrastructure.
*   **Usage**: Configured with the user-defined `var.vpc_cidr` and enables DNS hostnames (`enable_dns_hostnames = true`). All subnets, gateways, and routing configurations reside within this resource.

### 2. `aws_subnet.public` (Public Subnet)
*   **Purpose**: Hosts internet-facing resources and network appliances (like the NAT Gateway).
*   **Usage**: Assigned `var.public_subnet_cidr` in the specified availability zone (`var.az`). It has `map_public_ip_on_launch = true` enabled, ensuring resources launched here automatically receive a public IPv4 address. Its traffic is routed directly to the Internet Gateway.

### 3. `aws_subnet.private` (Private Subnet)
*   **Purpose**: Houses backend application layers, application servers, or compute clusters.
*   **Usage**: Assigned `var.private_subnet_cidr`. It does not assign public IP addresses on launch. Outbound traffic is routed securely through the NAT Gateway, while any unsolicited direct inbound traffic from the internet is completely blocked.

### 4. `aws_subnet.db` (Database Subnet)
*   **Purpose**: Isolates database layers, RDS instances, cache clusters, or stateful resources.
*   **Usage**: Assigned `var.db_subnet_cidr`. Like the private subnet, it is associated with the private route table to ensure database instances remain unreachable from the public internet. Outbound connections (e.g., for updates/patches) flow safely through the NAT Gateway.

### 5. `aws_internet_gateway.igw` (Internet Gateway)
*   **Purpose**: Connects the VPC to the public internet, acting as a gateway for public-facing assets.
*   **Usage**: Bound to the VPC. It translates requests and forwards outbound traffic from the public subnet to the external internet, as well as allowing incoming connections to resources in the public subnet.

### 6. `aws_nat_gateway.nat` (Network Address Translation Gateway)
*   **Purpose**: Provides private resources (in private and database subnets) with outbound-only internet connectivity.
*   **Usage**: Deployed within the public subnet and pinned to a static public IPv4 via a dedicated Elastic IP (`aws_eip.nat`). Private subnets send their internet-bound traffic (`0.0.0.0/0`) here, ensuring they can fetch patches, dependencies, or API calls without revealing their internal IP addresses or accepting incoming connections.

### 7. `aws_eip.nat` (Elastic IP Address)
*   **Purpose**: Provides a static, persistent public IPv4 address for the NAT Gateway.
*   **Usage**: Allocated within the `vpc` domain and assigned directly to the `aws_nat_gateway.nat` instance.

### 8. `aws_route_table.public` & `aws_route_table.private` (Route Tables)
*   **Purpose**: Define the rules and paths that govern where network traffic is directed.
*   **Usage**:
    *   **Public Route Table**: Maps all external destinations (`0.0.0.0/0`) to the Internet Gateway (`aws_internet_gateway.igw`). Associated with the public subnet.
    *   **Private Route Table**: Maps all external destinations (`0.0.0.0/0`) to the NAT Gateway (`aws_nat_gateway.nat`). Associated with both the private and database subnets.

### 9. `aws_vpc_endpoint.s3` (S3 Gateway Endpoint)
*   **Purpose**: Establishes a highly secure, private path to Amazon S3 buckets.
*   **Usage**: Configured as a Gateway-type VPC endpoint for S3 and attached to the private route table. This ensures that any traffic bound for Amazon S3 from the private or database subnets travels over the internal AWS backbone, bypassing the NAT Gateway entirely. This increases network performance and eliminates data transfer/processing costs associated with routing S3 traffic through a NAT Gateway.

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc_name](#input\_vpc_name) | VPC name | `string` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc_cidr](#input\_vpc_cidr) | VPC CIDR block | `string` | n/a | yes |
| <a name="input_public_subnet_cidr"></a> [public_subnet_cidr](#input\_public_subnet_cidr) | Public subnet CIDR | `string` | n/a | yes |
| <a name="input_private_subnet_cidr"></a> [private_subnet_cidr](#input\_private_subnet_cidr) | Private subnet CIDR | `string` | n/a | yes |
| <a name="input_db_subnet_cidr"></a> [db_subnet_cidr](#input\_db_subnet_cidr) | Database subnet CIDR | `string` | n/a | yes |
| <a name="input_az"></a> [az](#input\_az) | Availability Zone | `string` | n/a | yes |

---

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | The CIDR block of the VPC |
| <a name="output_vpc_ipv6_cidr_block"></a> [vpc\_ipv6\_cidr\_block](#output\_vpc\_ipv6\_cidr\_block) | The IPv6 CIDR block of the VPC |
| <a name="output_public_subnet_id"></a> [public\_subnet\_id](#output\_public\_subnet\_id) | The ID of the Public Subnet |
| <a name="output_private_subnet_id"></a> [private\_subnet\_id](#output\_private\_subnet\_id) | The ID of the Private Subnet |
| <a name="output_db_subnet_id"></a> [db\_subnet\_id](#output\_db_subnet\_id) | The ID of the Database Subnet |
| <a name="output_nat_gateway_id"></a> [nat\_gateway\_id](#output\_nat\_gateway\_id) | The ID of the NAT Gateway |
| <a name="output_s3_endpoint_id"></a> [s3\_endpoint\_id](#output\_s3\_endpoint\_id) | The ID of the S3 Gateway Endpoint |

---

## Notes & Security Best Practices

1. **Availability Zones**: This module currently targets a single Availability Zone (`var.az`). For highly available production setups, it is recommended to distribute subnets across multiple AZs.
2. **Database Isolation**: The database subnet utilizes the private route table routed through the NAT Gateway. This allows outbound internet access (e.g., for patching or external updates) while keeping the database resources private and unreachable from the public internet.
3. **Optimized S3 Access**: Outbound S3 traffic from the private subnet is routed internally via the S3 Gateway Endpoint rather than traversing the NAT Gateway. This provides enhanced security, lower latency, and eliminates NAT Gateway transfer costs for S3-bound traffic.