output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = aws_lambda_function.ec2_metadata_collector.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = aws_lambda_function.ec2_metadata_collector.arn
}

output "lambda_iam_role_name" {
  description = "Name of the IAM execution role used by Lambda"
  value       = aws_iam_role.lambda_execution_role.name
}

output "lambda_iam_role_arn" {
  description = "ARN of the IAM execution role used by Lambda"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket where EC2 metadata is stored"
  value       = aws_s3_bucket.metadata.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.metadata.arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule that triggers the Lambda"
  value       = aws_cloudwatch_event_rule.ec2_running.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.ec2_running.name
}
