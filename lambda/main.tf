# Get current AWS account ID for unique bucket naming
data "aws_caller_identity" "current" {}

# Construct globally unique S3 bucket name
locals {
  bucket_name = "${var.prefix}-ec2-metadata-${data.aws_caller_identity.current.account_id}"
}

# S3 Bucket for EC2 metadata storage
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.11.0"

  bucket        = local.bucket_name
  force_destroy = var.s3_force_destroy

  versioning = {
    enabled = true
  }

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
    Purpose = "EC2 metadata storage"
  }
}

# Lambda Function for EC2 metadata collection
module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.14.0"

  function_name = var.function_name
  description   = "Collects and stores EC2 instance metadata to S3"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  source_path = "${path.module}/src/ec2_metadata_collector"

  role_name          = "lambda_execution_role"
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

  environment_variables = {
    S3_BUCKET_NAME = module.s3_bucket.s3_bucket_id
    LOG_LEVEL      = "INFO"
  }

  cloudwatch_logs_retention_in_days = var.log_retention_days

  tags = {
    Name = var.function_name
  }
}

# EventBridge rule for EC2 state changes
module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "3.14.2"

  create_bus = false

  rules = {
    ec2_running_state = {
      description = "Capture EC2 instances entering running state"
      event_pattern = jsonencode({
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
        detail = {
          state = ["running"]
        }
      })
    }
  }

  targets = {
    ec2_running_state = [
      {
        name = "trigger-lambda-on-ec2-running"
        arn  = module.lambda_function.lambda_function_arn
      }
    ]
  }

  tags = {}
}

# Lambda permission to allow EventBridge invocation
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.eventbridge.eventbridge_rule_arns["ec2_running_state"]
}
