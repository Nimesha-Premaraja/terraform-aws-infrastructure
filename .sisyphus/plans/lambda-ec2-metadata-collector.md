# Plan: Lambda EC2 Metadata Collector

## Goal
Create a complete AWS Lambda setup that:
1. **Triggers** when an EC2 instance enters the `running` state (via Amazon EventBridge)
2. **Reads** EC2 instance basic metadata using `boto3`
3. **Uploads** the metadata as a JSON file to a new S3 bucket

---

## Constraints & Requirements
- All files go inside the `lambda/` folder
- Use **Terraform modules** instead of standalone resource blocks for all major services
  - `terraform-aws-modules/lambda/aws` for Lambda + IAM
  - `terraform-aws-modules/s3-bucket/aws` for S3
  - `terraform-aws-modules/eventbridge/aws` for EventBridge rule + target
- IAM role name **must** be `lambda_execution_role`
- Python runtime: `python3.12`
- AWS Region: `us-east-1`
- S3 bucket: **create new** (name derived from `prefix + account-id` for global uniqueness)
- Trigger: **EventBridge EC2 State-change Notification** (`running` state)
- AWS provider version: `6.42.0` (matches existing `compute/provider.tf`)

---

## Architecture Diagram

```
EC2 Instance Launched
        │
        ▼
┌───────────────────────┐
│   Amazon EventBridge  │  Rule: EC2 state-change → "running"
│   (Default Bus)       │
└──────────┬────────────┘
           │  Invokes
           ▼
┌───────────────────────┐
│   AWS Lambda          │  Name: ec2-metadata-collector
│   Runtime: Python3.12 │  Role: lambda_execution_role
│   Handler: index.     │
│          lambda_handler│
└──────────┬────────────┘
           │  boto3 → describe_instances
           │  boto3 → s3.put_object
           ▼
┌───────────────────────┐
│   Amazon S3 Bucket    │  Key: ec2-metadata/{instance-id}/{timestamp}.json
│   (Private, SSE-S3)   │  Versioned, encrypted at rest
└───────────────────────┘
```

---

## File Structure to Create/Modify

```
lambda/
├── provider.tf                        ← NEW: Terraform + AWS provider config
├── main.tf                            ← REPLACE: module calls (S3, Lambda, EventBridge, permission)
├── variables.tf                       ← REPLACE: all input variables
├── outputs.tf                         ← NEW: useful output values
└── src/
    └── ec2_metadata_collector/
        └── index.py                   ← NEW: Python Lambda source code
```

---

## Step-by-Step Implementation

### Step 1 — Create `lambda/provider.tf`

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.42.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

---

### Step 2 — Create `lambda/src/ec2_metadata_collector/index.py`

Python Lambda handler that:
- Extracts `instance-id` and `region` from the EventBridge event payload
- Calls `ec2:DescribeInstances` to fetch metadata
- Builds a structured JSON payload with: `instance_id`, `instance_type`, `state`, `launch_time`, `region`, `availability_zone`, `public_ip`, `private_ip`, `ami_id`, `key_name`, `subnet_id`, `vpc_id`, `architecture`, `platform`, `security_groups`, `tags`, `collected_at`
- Uploads the JSON to S3 at key `ec2-metadata/{instance_id}/{timestamp}.json`
- Reads `S3_BUCKET_NAME` and `LOG_LEVEL` from Lambda environment variables

```python
import json
import os
import logging
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def lambda_handler(event, context):
    """
    Triggered by EventBridge when an EC2 instance enters the 'running' state.
    Fetches basic metadata and uploads it as a JSON file to S3.
    """
    instance_id = event["detail"]["instance-id"]
    region      = event["region"]

    logger.info("Processing EC2 instance %s in region %s", instance_id, region)

    ec2_client = boto3.client("ec2", region_name=region)
    s3_client  = boto3.client("s3")
    bucket_name = os.environ["S3_BUCKET_NAME"]

    # ── Describe the instance ──────────────────────────────────────────────
    response = ec2_client.describe_instances(InstanceIds=[instance_id])

    if not response["Reservations"]:
        logger.error("No reservation found for instance: %s", instance_id)
        return {"statusCode": 404, "body": f"Instance {instance_id} not found"}

    instance = response["Reservations"][0]["Instances"][0]

    # ── Build metadata payload ─────────────────────────────────────────────
    metadata = {
        "instance_id":        instance.get("InstanceId"),
        "instance_type":      instance.get("InstanceType"),
        "state":              instance.get("State", {}).get("Name"),
        "launch_time":        instance.get("LaunchTime", datetime.now(timezone.utc)).isoformat(),
        "region":             region,
        "availability_zone":  instance.get("Placement", {}).get("AvailabilityZone"),
        "public_ip_address":  instance.get("PublicIpAddress"),
        "private_ip_address": instance.get("PrivateIpAddress"),
        "public_dns_name":    instance.get("PublicDnsName"),
        "private_dns_name":   instance.get("PrivateDnsName"),
        "ami_id":             instance.get("ImageId"),
        "key_name":           instance.get("KeyName"),
        "subnet_id":          instance.get("SubnetId"),
        "vpc_id":             instance.get("VpcId"),
        "architecture":       instance.get("Architecture"),
        "platform":           instance.get("Platform", "linux"),
        "security_groups": [
            {"id": sg["GroupId"], "name": sg["GroupName"]}
            for sg in instance.get("SecurityGroups", [])
        ],
        "tags": {
            tag["Key"]: tag["Value"]
            for tag in instance.get("Tags", [])
        },
        "collected_at": datetime.now(timezone.utc).isoformat(),
    }

    # ── Upload to S3 ───────────────────────────────────────────────────────
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    s3_key    = f"ec2-metadata/{instance_id}/{timestamp}.json"

    s3_client.put_object(
        Bucket      = bucket_name,
        Key         = s3_key,
        Body        = json.dumps(metadata, indent=2, default=str),
        ContentType = "application/json",
    )

    logger.info("Uploaded metadata to s3://%s/%s", bucket_name, s3_key)

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message":  f"Metadata collected for {instance_id}",
            "s3_path":  f"s3://{bucket_name}/{s3_key}",
        }),
    }
```

---

### Step 3 — Update `lambda/variables.tf`

Replace entire file:

```hcl
variable "aws_region" {
  description = "AWS region for all Lambda resources"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Short prefix applied to every resource name (e.g. dev, prod)"
  type        = string
  default     = "dev"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "ec2-metadata-collector"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory allocation in MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 14
}

variable "s3_force_destroy" {
  description = "Allow Terraform to destroy the S3 bucket even if it contains objects"
  type        = bool
  default     = true
}
```

---

### Step 4 — Rewrite `lambda/main.tf`

Full content:

```hcl
# ── Data source: resolve current AWS account ID for unique bucket naming ──
data "aws_caller_identity" "current" {}

locals {
  # Globally unique bucket name derived from prefix + account ID
  bucket_name = "${var.prefix}-ec2-metadata-${data.aws_caller_identity.current.account_id}"
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 Bucket  –  stores EC2 metadata JSON files
# Module: terraform-aws-modules/s3-bucket/aws
# ─────────────────────────────────────────────────────────────────────────────
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.11.0"

  bucket        = local.bucket_name
  force_destroy = var.s3_force_destroy

  # Object versioning — keeps history of metadata files
  versioning = {
    enabled = true
  }

  # Server-side encryption at rest
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
      bucket_key_enabled = true
    }
  }

  tags = {
    Name    = local.bucket_name
    Purpose = "ec2-metadata-storage"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Lambda Function  –  collects EC2 metadata and writes to S3
# Module: terraform-aws-modules/lambda/aws
# IAM role name: lambda_execution_role  (per requirement)
# ─────────────────────────────────────────────────────────────────────────────
module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.14.0"

  function_name = var.function_name
  description   = "Collects EC2 instance metadata on launch and uploads to S3"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  # Source directory — module handles zipping automatically
  source_path = "${path.module}/src/ec2_metadata_collector"

  # ── IAM ──────────────────────────────────────────────────────────────────
  role_name = "lambda_execution_role"

  # Custom policy: allow EC2 describe + targeted S3 write
  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3PutMetadata"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${module.s3_bucket.s3_bucket_arn}/ec2-metadata/*"
      }
    ]
  })

  # ── Runtime Environment ───────────────────────────────────────────────────
  environment_variables = {
    S3_BUCKET_NAME = module.s3_bucket.s3_bucket_id
    LOG_LEVEL      = "INFO"
  }

  # ── CloudWatch Logs ───────────────────────────────────────────────────────
  cloudwatch_logs_retention_in_days = var.log_retention_days

  tags = {
    Name = var.function_name
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EventBridge Rule  –  fires when EC2 instance enters "running" state
# Module: terraform-aws-modules/eventbridge/aws
# Uses the default AWS event bus — no custom bus required
# ─────────────────────────────────────────────────────────────────────────────
module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "3.14.2"

  # Use the default event bus (no custom bus needed)
  create_bus = false

  rules = {
    ec2_running_state = {
      description = "Trigger Lambda when an EC2 instance enters running state"
      enabled     = true
      event_pattern = jsonencode({
        source      = ["aws.ec2"]
        "detail-type" = ["EC2 Instance State-change Notification"]
        detail = {
          state = ["running"]
        }
      })
    }
  }

  targets = {
    ec2_running_state = [
      {
        name = "ec2-metadata-collector-target"
        arn  = module.lambda_function.lambda_function_arn
      }
    ]
  }

  tags = {
    Name = "${var.prefix}-ec2-state-change-rule"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Lambda Permission  –  grants EventBridge the right to invoke the function
# Note: a standalone resource is required here to break the circular dependency
# between the Lambda module (needs no EventBridge ARN at creation) and the
# EventBridge module (needs Lambda ARN). Permission is created last.
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.eventbridge.eventbridge_rule_arns["ec2_running_state"]
}
```

---

### Step 5 — Create `lambda/outputs.tf`

```hcl
output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = module.lambda_function.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = module.lambda_function.lambda_function_arn
}

output "lambda_iam_role_name" {
  description = "Name of the IAM execution role used by Lambda"
  value       = module.lambda_function.lambda_role_name
}

output "lambda_iam_role_arn" {
  description = "ARN of the IAM execution role used by Lambda"
  value       = module.lambda_function.lambda_role_arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket where EC2 metadata is stored"
  value       = module.s3_bucket.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3_bucket.s3_bucket_arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule that triggers the Lambda"
  value       = module.eventbridge.eventbridge_rule_arns["ec2_running_state"]
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = keys(module.eventbridge.eventbridge_rule_arns)[0]
}
```

---

## IAM Permissions Summary

| Permission | Service | Scope |
|---|---|---|
| `ec2:DescribeInstances` | EC2 | All instances (`*`) |
| `ec2:DescribeTags` | EC2 | All resources (`*`) |
| `s3:PutObject` | S3 | `{bucket_arn}/ec2-metadata/*` only |
| `logs:CreateLogGroup` | CloudWatch Logs | Auto-granted by Lambda module |
| `logs:CreateLogStream` | CloudWatch Logs | Auto-granted by Lambda module |
| `logs:PutLogEvents` | CloudWatch Logs | Auto-granted by Lambda module |

---

## S3 Object Structure

Each time an EC2 instance enters the `running` state, a file is written:
```
s3://{prefix}-ec2-metadata-{account_id}/
└── ec2-metadata/
    └── i-0abc123def456789/
        ├── 20260627T120000Z.json
        └── 20260628T090000Z.json   ← one file per state-change event
```

---

## Deployment Instructions

```bash
cd lambda/
terraform init
terraform plan
terraform apply
```

---

## Module Versions Used

| Module | Version |
|---|---|
| `terraform-aws-modules/lambda/aws` | `7.14.0` |
| `terraform-aws-modules/s3-bucket/aws` | `4.11.0` |
| `terraform-aws-modules/eventbridge/aws` | `3.14.2` |
| AWS Provider (`hashicorp/aws`) | `6.42.0` |
