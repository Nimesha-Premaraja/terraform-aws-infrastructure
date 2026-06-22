# Terraform AWS 2-Tier Infrastructure

This repository contains a modular, decoupled 2-tier AWS infrastructure managed entirely via Terraform. The project demonstrates cloud architecture best practices by separating the **Networking (VPC) Layer** from the **Compute (EC2) Layer**. 

---

## Architecture Overview

The infrastructure is split into two distinct tiers to isolate state and limit the blast radius of changes:

1.  **Network Tier (`modules/vpc` & `vpc/`)**: Provisions the core virtual network, allocating subnets across public, private, and database zones, and establishing secure gateways (IGW/NAT) and an S3 VPC endpoint. 
    *(See the comprehensive ASCII architecture diagram in the [VPC Module README](./modules/vpc/README.md).)*
2.  **Compute Tier (`compute/`)**: Queries the network tier's outputs dynamically via Terraform data sources and deploys a public-facing instance (e.g., as a bastion or proxy) and an isolated private-facing instance.

---

## Directory Structure

```text
├── README.md                      # Main project orchestration guide
├── vpc/                           # Network deployment environment
│   └── main.tf                    # Instantiates the custom VPC module
├── compute/                       # Compute deployment environment
│   ├── main.tf                    # Provisions public/private EC2 instances
│   ├── data.tf                    # Dynamic lookup of VPC & Subnet resources
│   ├── securty-group.tf           # Network firewall and ingress/egress rules
│   ├── provider.tf                # AWS provider settings for compute
│   └── outputs.tf                 # Exports sensitive PEM keys
└── modules/
    └── vpc/                       # Custom, reusable AWS VPC Module
        ├── README.md              # Dedicated documentation for the VPC module
        ├── main.tf                # VPC, Subnets, GWs, Route Tables, VPC Endpoint
        ├── variables.tf           # VPC input definitions
        └── outputs.tf             # VPC output definitions
```

---

## Component Breakdown

### 1. Reusable VPC Module (`modules/vpc`)
The custom `vpc` module acts as our reusable networking blueprint. It configures:
*   **AWS VPC**: The foundational software-defined network.
*   **Subnets**:
    *   **Public**: Automatic public IP assignment; hosts the NAT Gateway.
    *   **Private**: For workloads requiring outbound internet connectivity (via NAT) but no inbound internet exposure.
    *   **Database**: For data stores needing network isolation with secure outbound patching capabilities.
*   **Gateways**: Internet Gateway (IGW) for public routing, and a NAT Gateway (utilizing an Elastic IP) for private outbound routing.
*   **S3 Gateway Endpoint**: Direct internal AWS routing to Amazon S3 buckets, bypassing the NAT Gateway to eliminate data transfer fees and decrease latency.

*For complete details, variables, and outputs, read the [VPC Module README](./modules/vpc/README.md).*

### 2. Networking Deployment (`vpc/`)
The `vpc/` directory initiates the actual deployment of the networking layer. It sets the region (`us-east-1`), availability zone (`us-east-1b`), and CIDR configurations to deploy the `dev-vpc`.

### 3. Compute Deployment (`compute/`)
The `compute/` directory provisions the virtual machines within the pre-deployed VPC. Features include:
*   **Dynamic Resource Querying (`data.tf`)**: Queries the VPC and subnets dynamically using tag filters (`Name = dev-vpc`, etc.). This eliminates hardcoded subnet IDs and decouples state management.
*   **Dual EC2 Setup (`main.tf`)**:
    *   **Public Instance**: Instantiated in the public subnet; receives a public IP address.
    *   **Private Instance**: Instantiated in the private subnet; only accessible within the internal network.
*   **Automated SSH Key Generation**: Uses TLS provider resources to generate an RSA-4096 private key and dynamically registers the public key as an AWS Key Pair.
*   **Stateful Security Groups (`securty-group.tf`)**:
    *   Allows TLS inbound traffic (port 443) exclusively from within the VPC CIDR block.
    *   Allows SSH inbound traffic (port 22) globally (`0.0.0.0/0`) for remote administration.
    *   Allows all outbound IPv4 and IPv6 traffic.

---

## How to Deploy

Because this infrastructure is decoupled, deployment must be executed sequentially.

### Step 1: Deploy the Network Tier
Navigate to the `vpc` directory, initialize, and deploy:
```bash
# Move to the VPC deployment folder
cd vpc

# Initialize Terraform AWS providers and modules
terraform init

# Review execution plan
terraform plan

# Apply changes and build the VPC
terraform apply -auto-approve
```

### Step 2: Deploy the Compute Tier
Once the VPC is fully provisioned and tags are in place, navigate to the `compute` directory to launch the instances:
```bash
# Move to the compute folder
cd ../compute

# Initialize AWS and TLS providers
terraform init

# Review compute resource layout
terraform plan

# Apply changes to deploy EC2 instances
terraform apply -auto-approve
```

### Accessing the Private Key
The SSH private key is dynamically generated and stored in the Terraform state. To retrieve the PEM key to connect to your instances, run:
```bash
terraform output -raw private_key_pem > dev-key.pem
chmod 400 dev-key.pem
```

---

## Security Features Implemented

*   **Decoupled State**: Prevents modifications to compute instances from risking network state/configurations.
*   **Private Isolation**: Compute workloads are divided between public (DMZ) and private (backend) zones.
*   **Data Protection**: Outbound database connections route through highly restricted NAT protocols, while database subnets remain entirely secure against public internet ingress.
*   **VPC-Only Gateway Endpoint**: Keeps Amazon S3 traffic internal to AWS, securing communication and optimizing infrastructure spend.
*   **Cryptographic Key Pairing**: Dynamically generates unique 4096-bit RSA keys during deploy cycles rather than using pre-existing, shared keys.
