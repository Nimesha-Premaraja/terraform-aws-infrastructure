## [2026-06-27T16:56:00Z] Issues Encountered

### Issue 1: EC2 Client Region Bug (FIXED)
**Problem:** Initial implementation created EC2 client globally without region parameter
**Impact:** Would fail for EC2 instances in different regions
**Solution:** Moved `ec2_client = boto3.client("ec2", region_name=region)` inside lambda_handler
**Location:** `lambda/src/ec2_metadata_collector/index.py` line 29

### Issue 2: Security Groups Key Names (FIXED)
**Problem:** Used `"group_id"` and `"group_name"` instead of `"id"` and `"name"`
**Impact:** Inconsistent with plan specification
**Solution:** Changed to `"id"` and `"name"` per plan line 156
**Location:** `lambda/src/ec2_metadata_collector/index.py` lines 65-66

### Issue 3: Variable Reference Errors in main.tf (FIXED)
**Problem 1:** `LOG_LEVEL = var.log_level` but variable doesn't exist
**Solution:** Changed to `LOG_LEVEL = "INFO"` (hardcoded string)
**Location:** `lambda/main.tf` line 75

**Problem 2:** `var.cloudwatch_logs_retention_in_days` wrong variable name
**Solution:** Changed to `var.log_retention_days` (correct name from variables.tf)
**Location:** `lambda/main.tf` line 78

### Non-Issues

- Terraform init timeout: Expected behavior when downloading multiple modules
- Module installation can take 1-2 minutes on first run
- User should run `terraform init` manually before `terraform apply`
