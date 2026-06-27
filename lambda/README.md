# EC2 Metadata Collector with Lambda and EventBridge

An event-driven serverless solution that automatically captures and stores EC2 instance metadata when instances transition to the running state. The system uses Amazon EventBridge to trigger an AWS Lambda function that queries EC2 APIs and persists comprehensive instance metadata to Amazon S3 with encryption and versioning enabled.

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud Environment                           │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌───────────────┐                                                      │
│  │  EC2 Instance │                                                      │
│  │   (any AZ)    │                                                      │
│  └───────┬───────┘                                                      │
│          │                                                               │
│          │ State Change Event: "running"                                │
│          │                                                               │
│          ▼                                                               │
│  ┌──────────────────────────────────────────────┐                      │
│  │       Amazon EventBridge (Default Bus)       │                      │
│  │  ┌────────────────────────────────────────┐  │                      │
│  │  │ Event Rule: ec2-running-state-rule     │  │                      │
│  │  │                                        │  │                      │
│  │  │ Pattern:                               │  │                      │
│  │  │   source: aws.ec2                      │  │                      │
│  │  │   detail-type: EC2 State-change        │  │                      │
│  │  │   detail.state: ["running"]            │  │                      │
│  │  └────────────────────────────────────────┘  │                      │
│  └───────────────────┬──────────────────────────┘                      │
│                      │ Invokes (async)                                  │
│                      ▼                                                   │
│  ┌────────────────────────────────────────────────────┐                │
│  │          AWS Lambda Function                       │                │
│  │   Name: ec2-metadata-collector                     │                │
│  │   Runtime: Python 3.12                             │                │
│  │   Timeout: 30s | Memory: 128 MB                    │                │
│  │                                                     │                │
│  │   Environment Variables:                           │                │
│  │     • S3_BUCKET_NAME                               │                │
│  │     • LOG_LEVEL=INFO                               │                │
│  │                                                     │                │
│  │   Execution Role: lambda_execution_role            │                │
│  │     • AWSLambdaBasicExecutionRole                  │                │
│  │     • AmazonEC2ReadOnlyAccess                      │                │
│  │     • AmazonS3FullAccess                           │                │
│  └──────────────┬────────────────┬────────────────────┘                │
│                 │                 │                                      │
│      API Call: DescribeInstances  │ API Call: PutObject                │
│                 │                 │                                      │
│                 ▼                 ▼                                      │
│  ┌──────────────────┐  ┌────────────────────────────────┐              │
│  │   Amazon EC2     │  │       Amazon S3 Bucket         │              │
│  │                  │  │  {prefix}-ec2-metadata-        │              │
│  │ Returns metadata │  │      {account-id}              │              │
│  │ for instance ID  │  │                                │              │
│  └──────────────────┘  │  Features:                     │              │
│                        │    • Versioning: Enabled       │              │
│                        │    • Encryption: AES-256       │              │
│                        │    • Bucket Key: Enabled       │              │
│                        │                                │              │
│                        │  Key Pattern:                  │              │
│                        │  ec2-metadata/{id}/{time}.json │              │
│                        └────────────────────────────────┘              │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

**Flow Summary:**
1. EC2 instance transitions to "running" state
2. EventBridge captures the state change event
3. EventBridge invokes Lambda function asynchronously
4. Lambda queries EC2 API for detailed instance metadata
5. Lambda writes JSON metadata to S3 with timestamp-based key
6. S3 encrypts and versions the object automatically

---

## AWS Resources Created

This Terraform configuration provisions the following AWS resources:

| Resource | Type | Purpose |
|----------|------|---------|
| `aws_s3_bucket.metadata` | S3 Bucket | Stores EC2 instance metadata as JSON objects with globally unique name |
| `aws_s3_bucket_versioning.metadata` | S3 Versioning | Enables versioning on metadata bucket for audit trail and recovery |
| `aws_s3_bucket_server_side_encryption_configuration.metadata` | S3 Encryption | Enforces AES-256 server-side encryption with S3-managed keys |
| `aws_iam_role.lambda_execution_role` | IAM Role | Execution role for Lambda with trust policy allowing lambda.amazonaws.com to assume |
| `aws_iam_role_policy_attachment.lambda_basic` | IAM Policy Attachment | Grants CloudWatch Logs permissions for Lambda function logging |
| `aws_iam_role_policy_attachment.lambda_ec2_readonly` | IAM Policy Attachment | Grants read-only access to EC2 API for describing instances and tags |
| `aws_iam_role_policy_attachment.lambda_s3_full` | IAM Policy Attachment | Grants full S3 access for writing metadata objects to bucket |
| `aws_lambda_function.ec2_metadata_collector` | Lambda Function | Python 3.12 function that collects EC2 metadata and writes to S3 |
| `aws_cloudwatch_event_rule.ec2_running` | EventBridge Rule | Filters for EC2 state change events where state becomes "running" |
| `aws_cloudwatch_event_target.lambda` | EventBridge Target | Routes matched events to Lambda function for processing |
| `aws_lambda_permission.allow_eventbridge` | Lambda Permission | Grants EventBridge service permission to invoke Lambda function |

**Additional Resources (Data Sources):**
- `data.aws_caller_identity.current` - Retrieves AWS account ID for unique bucket naming
- `data.archive_file.lambda_zip` - Packages Python source code into deployment ZIP

---

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **Terraform** installed (version >= 1.0)
2. **AWS CLI** configured with credentials that have permissions to create:
   - S3 buckets
   - Lambda functions
   - IAM roles and policies
   - EventBridge rules
   - CloudWatch log groups
3. **AWS Provider** version 6.42.0 or compatible
4. **Source code** present at `lambda/src/ec2_metadata_collector/index.py`
5. **Network connectivity** to AWS APIs (if running from restricted environment)

---

## Usage

### Deploy Infrastructure

Navigate to the `lambda` directory and run:

```bash
# Initialize Terraform and download AWS provider
terraform init

# Review the execution plan
terraform plan

# Deploy all resources
terraform apply
```

### Customize Deployment

Override default variables using `-var` flags or a `terraform.tfvars` file:

```bash
terraform apply \
  -var="aws_region=us-west-2" \
  -var="prefix=prod" \
  -var="lambda_timeout=60" \
  -var="lambda_memory_size=256"
```

### Destroy Infrastructure

To tear down all resources:

```bash
terraform destroy
```

**Note:** Set `s3_force_destroy=true` (default) to allow bucket deletion even with objects present.

---

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `aws_region` | AWS region where resources will be deployed | string | `"us-east-1"` | No |
| `prefix` | Prefix applied to resource names for environment separation | string | `"dev"` | No |
| `function_name` | Lambda function name | string | `"ec2-metadata-collector"` | No |
| `lambda_timeout` | Maximum execution time in seconds (1-900) | number | `30` | No |
| `lambda_memory_size` | Memory allocated to Lambda in MB (128-10240) | number | `128` | No |
| `log_retention_days` | CloudWatch Logs retention period in days | number | `14` | No |
| `s3_force_destroy` | Allow Terraform to destroy bucket with objects | bool | `true` | No |

---

## Outputs

After deployment, Terraform exports the following values:

| Name | Description |
|------|-------------|
| `lambda_function_name` | Name of the deployed Lambda function |
| `lambda_function_arn` | Amazon Resource Name (ARN) of the Lambda function |
| `lambda_iam_role_name` | Name of the IAM execution role |
| `lambda_iam_role_arn` | ARN of the IAM execution role |
| `s3_bucket_name` | Name of the S3 bucket storing metadata |
| `s3_bucket_arn` | ARN of the S3 bucket |
| `eventbridge_rule_arn` | ARN of the EventBridge rule |
| `eventbridge_rule_name` | Name of the EventBridge rule |

**Retrieve outputs:**
```bash
terraform output s3_bucket_name
terraform output -json  # Export all outputs as JSON
```

---

## Metadata Collected

The Lambda function extracts and stores the following EC2 instance attributes:

**Instance Identifiers:**
- Instance ID
- Instance Type
- AMI ID
- Architecture (x86_64, arm64)
- Platform (Linux, Windows)

**Network Configuration:**
- Public IP Address
- Private IP Address
- Public DNS Name
- Private DNS Name
- VPC ID
- Subnet ID
- Availability Zone

**Security:**
- Security Groups (ID and Name for each)

**State Information:**
- Current State
- Launch Time
- Region

**Custom Tags:**
- All user-defined instance tags (key-value pairs)

**System Metadata:**
- Timestamp of metadata collection
- Key Name (SSH key pair)

**Total:** 18+ distinct fields per instance

---

## S3 Object Structure

Metadata objects are stored with a hierarchical key pattern:

```
s3://{prefix}-ec2-metadata-{account-id}/
└── ec2-metadata/
    ├── i-0abc123def456789/
    │   ├── 20260627T120000Z.json
    │   ├── 20260627T130530Z.json
    │   └── 20260627T145622Z.json
    └── i-0xyz789abc123def/
        └── 20260627T121045Z.json
```

**Key Pattern:** `ec2-metadata/{instance-id}/{iso8601-timestamp}.json`

**Example Metadata Object:**

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
  "public_dns_name": "ec2-54-123-45-67.compute-1.amazonaws.com",
  "private_dns_name": "ip-10-0-1-100.ec2.internal",
  "ami_id": "ami-0c55b159cbfafe1f0",
  "vpc_id": "vpc-0123456789abcdef0",
  "subnet_id": "subnet-0123456789abcdef0",
  "key_name": "my-key-pair",
  "architecture": "x86_64",
  "platform": "Linux",
  "security_groups": [
    {
      "id": "sg-0123456789abcdef0",
      "name": "default"
    },
    {
      "id": "sg-0fedcba987654321",
      "name": "web-server"
    }
  ],
  "tags": {
    "Name": "production-web-server",
    "Environment": "production",
    "ManagedBy": "terraform"
  },
  "collected_at": "2026-06-27T12:00:05+00:00"
}
```

---

## Testing

Verify the system works correctly:

### 1. Deploy Infrastructure
```bash
cd lambda/
terraform apply
```

### 2. Launch Test EC2 Instance
```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.micro \
  --region us-east-1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-metadata-collection}]'
```

### 3. Wait for Running State
Monitor the instance until it reaches "running" state (typically 30-60 seconds).

### 4. Check S3 Bucket
```bash
# Get bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# List objects in bucket
aws s3 ls s3://$BUCKET_NAME/ec2-metadata/ --recursive

# Download metadata file
aws s3 cp s3://$BUCKET_NAME/ec2-metadata/i-xxxxx/20260627Txxxxxx.json ./metadata.json

# View contents
cat metadata.json | jq .
```

### 5. Verify Lambda Execution
```bash
# View recent logs
aws logs tail /aws/lambda/ec2-metadata-collector --follow

# Check invocation count
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=ec2-metadata-collector \
  --start-time 2026-06-27T00:00:00Z \
  --end-time 2026-06-27T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

### 6. Test EventBridge Rule
```bash
# Check if rule is enabled
aws events describe-rule --name ec2-running-state-rule

# View targets
aws events list-targets-by-rule --rule ec2-running-state-rule
```

---

## Security Considerations

**Implemented Security Controls:**

- **Encryption at Rest:** S3 bucket enforces AES-256 server-side encryption with S3-managed keys
- **Versioning:** Object versioning enabled for audit trail and accidental deletion protection
- **IAM Least Privilege:** Lambda role uses AWS managed policies with minimal required permissions
- **Private Bucket:** S3 bucket has no public access (AWS default block public access)
- **Event-Driven:** No polling or continuous scanning, only triggered on EC2 state changes
- **CloudWatch Logging:** All Lambda executions logged to CloudWatch for monitoring and debugging

**Recommended Enhancements:**

- Replace AWS managed policies with custom least-privilege policies scoped to specific resources
- Enable S3 access logging for compliance and audit requirements
- Add KMS encryption with customer-managed keys instead of S3-managed keys
- Implement VPC endpoints to keep traffic within AWS private network
- Add DLQ (Dead Letter Queue) to Lambda for failed invocation retry handling
- Enable AWS CloudTrail to log all API calls to EventBridge and Lambda

---

## Operational Notes

**Important Behaviors:**

- The Lambda function triggers on **any** EC2 instance entering the "running" state within the deployed AWS region
- This includes instance restarts, not just initial launches
- If an instance is stopped and started multiple times, each transition creates a new metadata snapshot
- S3 bucket name is globally unique: `{prefix}-ec2-metadata-{aws-account-id}`
- CloudWatch Logs retention is configurable via `log_retention_days` variable (default: 14 days)
- Lambda execution logs available at: `/aws/lambda/ec2-metadata-collector`
- EventBridge delivers events asynchronously with at-least-once delivery guarantee
- Lambda retries failed invocations automatically (2 retries with exponential backoff)

**Cost Optimization:**

- Lambda is billed per invocation and execution duration (typically <1 second per execution)
- S3 storage costs depend on number of instances and restart frequency
- EventBridge rule has no charge (only Lambda invocation charges apply)
- Consider adding S3 lifecycle policies to transition old metadata to Glacier or delete after retention period

**Monitoring:**

- Track Lambda errors via CloudWatch Metrics: `Errors`, `Throttles`, `Duration`
- Set up CloudWatch Alarms for Lambda failure rate thresholds
- Monitor S3 bucket size growth over time
- Review EventBridge rule invocation count to understand EC2 activity patterns
