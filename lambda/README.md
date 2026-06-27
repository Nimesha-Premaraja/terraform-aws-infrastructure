# Lambda EC2 Metadata Collector

This Terraform module deploys an AWS Lambda function that automatically collects EC2 instance metadata whenever an instance enters the `running` state and stores it in an S3 bucket.

## Architecture

```
EC2 Instance Created
       │
       ▼
┌─────────────────────────┐
│  Amazon EventBridge     │  Rule: EC2 state → "running"
│  (Default Event Bus)    │
└───────────┬─────────────┘
            │ Invokes
            ▼
┌─────────────────────────┐
│  AWS Lambda             │  Name: ec2-metadata-collector
│  Runtime: Python 3.12   │  Role: lambda_execution_role
└───────────┬─────────────┘
            │ boto3 API calls
            ▼
┌─────────────────────────┐
│  Amazon S3              │  Key: ec2-metadata/{id}/{timestamp}.json
│  Versioned, Encrypted   │
└─────────────────────────┘
```

## Features

- ✅ **Event-Driven**: Automatically triggered by EventBridge when EC2 instances start
- ✅ **Comprehensive Metadata**: Collects 18+ fields including instance details, network info, tags, and security groups
- ✅ **Secure**: Private S3 bucket with server-side encryption (SSE-AES256)
- ✅ **Versioned**: S3 object versioning enabled for audit trail
- ✅ **IAM Best Practices**: Least-privilege permissions (EC2 describe, S3 PutObject)
- ✅ **Module-Based**: Uses official Terraform AWS modules

## Usage

```bash
cd lambda/
terraform init
terraform plan
terraform apply
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | 6.42.0 |

## Modules Used

| Module | Version | Purpose |
|--------|---------|---------|
| terraform-aws-modules/s3-bucket/aws | 4.11.0 | S3 bucket for metadata storage |
| terraform-aws-modules/lambda/aws | 7.14.0 | Lambda function with IAM role |
| terraform-aws-modules/eventbridge/aws | 3.14.2 | EventBridge rule and target |

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| aws_region | AWS region for all Lambda resources | string | "us-east-1" |
| prefix | Short prefix applied to resource names | string | "dev" |
| function_name | Name of the Lambda function | string | "ec2-metadata-collector" |
| lambda_timeout | Lambda function timeout in seconds | number | 30 |
| lambda_memory_size | Lambda memory allocation in MB | number | 128 |
| log_retention_days | CloudWatch Logs retention period | number | 14 |
| s3_force_destroy | Allow bucket destruction with objects | bool | true |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_name | Name of the deployed Lambda function |
| lambda_function_arn | ARN of the deployed Lambda function |
| lambda_iam_role_name | Name of the IAM execution role |
| lambda_iam_role_arn | ARN of the IAM execution role |
| s3_bucket_name | Name of the S3 bucket |
| s3_bucket_arn | ARN of the S3 bucket |
| eventbridge_rule_arn | ARN of the EventBridge rule |
| eventbridge_rule_name | Name of the EventBridge rule |

## Metadata Collected

The Lambda function collects the following EC2 instance metadata:

- **Instance Details**: ID, type, state, launch time, architecture, platform
- **Network**: Public/private IPs, public/private DNS names, VPC ID, subnet ID, availability zone
- **Configuration**: AMI ID, key name
- **Security**: Security groups (ID + name)
- **Tags**: All instance tags
- **Timestamp**: When metadata was collected

## S3 Object Structure

Metadata is stored with the following key pattern:
```
s3://{prefix}-ec2-metadata-{account-id}/
└── ec2-metadata/
    └── {instance-id}/
        ├── 20260627T120000Z.json
        └── 20260627T130000Z.json
```

## IAM Permissions

The Lambda function is granted the following permissions:

- `ec2:DescribeInstances` - Read EC2 instance metadata
- `ec2:DescribeTags` - Read EC2 tags
- `s3:PutObject` - Write metadata to S3 (scoped to `{bucket}/ec2-metadata/*`)
- CloudWatch Logs permissions (auto-granted by Lambda module)

## Example Output

After an EC2 instance enters the running state, a JSON file is created:

```json
{
  "instance_id": "i-0abc123def456789",
  "instance_type": "t3.micro",
  "state": "running",
  "launch_time": "2026-06-27T12:00:00+00:00",
  "region": "us-east-1",
  "availability_zone": "us-east-1a",
  "public_ip_address": "54.123.45.67",
  "private_ip_address": "10.0.1.100",
  "ami_id": "ami-0c55b159cbfafe1f0",
  "vpc_id": "vpc-0123456789abcdef0",
  "subnet_id": "subnet-0123456789abcdef0",
  "security_groups": [
    {
      "id": "sg-0123456789abcdef0",
      "name": "default"
    }
  ],
  "tags": {
    "Name": "my-instance",
    "Environment": "dev"
  },
  "collected_at": "2026-06-27T12:00:05+00:00"
}
```

## Testing

To test the Lambda function:

1. Deploy the infrastructure: `terraform apply`
2. Launch an EC2 instance in the same region (us-east-1)
3. Wait for the instance to reach "running" state
4. Check the S3 bucket for the metadata JSON file
5. View Lambda logs in CloudWatch: `/aws/lambda/ec2-metadata-collector`

## Notes

- The Lambda function triggers on **any** EC2 instance state change to "running" in the region
- This includes instance restarts, not just initial creation
- S3 bucket is created with a globally unique name: `{prefix}-ec2-metadata-{account-id}`
- CloudWatch Logs retention is configurable (default: 14 days)
