# AWS VPC Infrastructure

This Terraform configuration creates a production-ready AWS VPC with public, private, and database subnets, along with necessary networking components.

## Architecture Overview

The VPC infrastructure includes:

- **VPC** with DNS hostnames enabled
- **Three Subnets**:
  - Public Subnet (10.0.0.0/24) - For resources that need direct internet access
  - Private Subnet (10.0.144.0/20) - For application servers
  - Database Subnet (10.0.160.0/20) - For database instances
- **Internet Gateway** - Provides internet access to the public subnet
- **NAT Gateway** - Enables outbound internet access for private subnets
- **Route Tables** - Properly configured for public and private routing
- **S3 VPC Endpoint** - Private access to S3 without internet gateway

## Network Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                    │
│                                                         │
│  ┌──────────────────┐    ┌──────────────────┐          │
│  │ Public Subnet    │    │ Private Subnet   │          │
│  │ 10.0.0.0/24      │    │ 10.0.144.0/20    │          │
│  │                  │    │                  │          │
│  │ ┌──────────┐     │    │ ┌──────────┐     │          │
│  │ │NAT Gateway│◄───┼────┤ │App Server│     │          │
│  │ └──────────┘     │    │ └──────────┘     │          │
│  └────────┬─────────┘    └──────────────────┘          │
│           │                                             │
│  ┌────────┴─────────────────────────────────┐          │
│  │        Internet Gateway                  │          │
│  └──────────────────────────────────────────┘          │
│                                                         │
│  ┌──────────────────┐    ┌──────────────────┐          │
│  │ Database Subnet  │    │  S3 Endpoint     │          │
│  │ 10.0.160.0/20    │    │  (Gateway)       │          │
│  │                  │    └──────────────────┘          │
│  │ ┌──────────┐     │                                  │
│  │ │ Database │     │                                  │
│  │ └──────────┘     │                                  │
│  └──────────────────┘                                  │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS Provider version 6.42.0 or compatible

## Usage

### Initialize Terraform

```bash
cd vpc
terraform init
```

### Plan Infrastructure

```bash
terraform plan
```

### Deploy Infrastructure

```bash
terraform apply
```

### Destroy Infrastructure

```bash
terraform destroy
```

## Module Configuration

The VPC is configured using the reusable module located at `../modules/vpc`.

### Current Configuration (Dev VPC)

```hcl
module "dev_vpc" {
  source = "../modules/vpc"

  region              = "us-east-1"
  vpc_name            = "dev-vpc"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.0.0/24"
  private_subnet_cidr = "10.0.144.0/20"
  db_subnet_cidr      = "10.0.160.0/20"
  az                  = "us-east-1b"
}
```

## Variables

| Variable | Description | Type | Example |
|----------|-------------|------|---------|
| `region` | AWS region | string | us-east-1 |
| `vpc_name` | Name of the VPC | string | dev-vpc |
| `vpc_cidr` | CIDR block for VPC | string | 10.0.0.0/16 |
| `public_subnet_cidr` | CIDR for public subnet | string | 10.0.0.0/24 |
| `private_subnet_cidr` | CIDR for private subnet | string | 10.0.144.0/20 |
| `db_subnet_cidr` | CIDR for database subnet | string | 10.0.160.0/20 |
| `az` | Availability zone | string | us-east-1b |

## Outputs

The module provides the following outputs:

| Output | Description |
|--------|-------------|
| `vpc_id` | The ID of the VPC |
| `vpc_cidr_block` | The CIDR block of the VPC |
| `vpc_ipv6_cidr_block` | The IPv6 CIDR block of the VPC |
| `public_subnet_id` | ID of the public subnet |
| `private_subnet_id` | ID of the private subnet |
| `db_subnet_id` | ID of the database subnet |
| `nat_gateway_id` | ID of the NAT gateway |
| `s3_endpoint_id` | ID of the S3 VPC endpoint |

## Network Flow

### Public Subnet Traffic
- **Inbound**: Internet → Internet Gateway → Public Subnet
- **Outbound**: Public Subnet → Internet Gateway → Internet

### Private Subnet Traffic
- **Inbound**: No direct inbound from internet (use Application Load Balancer in public subnet)
- **Outbound**: Private Subnet → NAT Gateway → Internet Gateway → Internet
- **S3 Access**: Private Subnet → S3 VPC Endpoint → S3 (stays within AWS network)

### Database Subnet Traffic
- **Inbound**: From Private Subnet only
- **Outbound**: Database Subnet → NAT Gateway → Internet Gateway → Internet
- **S3 Access**: Database Subnet → S3 VPC Endpoint → S3 (for backups)

## Cost Considerations

- **NAT Gateway**: ~$0.045/hour + data processing charges (~$32.40/month)
- **Elastic IP**: Free when attached to running NAT Gateway
- **S3 VPC Endpoint**: No additional charge (Gateway endpoint)
- **VPC, Subnets, IGW, Route Tables**: No charge

## Security Best Practices

1. **Network Isolation**: Keep databases in dedicated subnet with no direct internet access
2. **NAT Gateway**: Provides secure outbound internet access without exposing instances
3. **S3 Endpoint**: Reduces data transfer costs and improves security by keeping S3 traffic private
4. **Availability**: Single AZ deployment (consider multi-AZ for production)

## Future Enhancements

- [ ] Add support for multiple availability zones
- [ ] Create subnet groups for RDS
- [ ] Add VPC Flow Logs for network monitoring
- [ ] Implement Network ACLs for additional security
- [ ] Add DynamoDB VPC endpoint
- [ ] Configure VPC peering for multi-VPC architectures

## Troubleshooting

### Issue: Instances in private subnet can't reach internet
- Verify NAT Gateway is running
- Check route table association for private subnet
- Ensure NAT Gateway has Elastic IP attached

### Issue: High data transfer costs
- Review NAT Gateway data processing charges
- Consider using VPC endpoints for AWS services
- Check for unnecessary data transfers

## License

This configuration is provided as-is for infrastructure deployment purposes.
