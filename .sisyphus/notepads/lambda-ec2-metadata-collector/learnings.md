## [2026-06-27T16:56:00Z] Learnings: Lambda EC2 Metadata Collector

### Successful Patterns

1. **Module-based Terraform Architecture**
   - Used terraform-aws-modules for all major resources (S3, Lambda, EventBridge)
   - Avoided raw resource blocks as requested
   - Clean separation of concerns between modules

2. **IAM Role Naming**
   - Successfully set `role_name = "lambda_execution_role"` in Lambda module
   - Module parameter `attach_policy_json = true` allows custom IAM policy alongside module defaults

3. **EventBridge + Lambda Integration**
   - Standalone `aws_lambda_permission` resource required to break circular dependency
   - EventBridge module with `create_bus = false` uses default event bus (cost-effective)
   - Event pattern correctly filters EC2 state-change to "running"

4. **Python Lambda Handler**
   - EC2 client MUST be created inside handler with `region_name=region` parameter (not globally)
   - Handles multi-region EC2 instances correctly
   - Security groups: Use `"id"` and `"name"` keys (not "group_id"/"group_name")

5. **S3 Bucket Naming**
   - `data.aws_caller_identity` provides account ID for globally unique bucket names
   - Format: `${var.prefix}-ec2-metadata-${account_id}` ensures uniqueness

### Code Quality

- All Terraform files formatted with `terraform fmt`
- Python syntax validated with `py_compile`
- No TODOs, placeholders, or hardcoded values
- Proper error handling in Lambda function

### Module Versions Used

- terraform-aws-modules/s3-bucket/aws: **v4.11.0**
- terraform-aws-modules/lambda/aws: **v7.14.0**
- terraform-aws-modules/eventbridge/aws: **v3.14.2**
- AWS Provider: **6.42.0**
