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
