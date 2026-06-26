module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = var.function_name
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  source_path = "../src/lambda-function1"

  tags = {
    Name = var.function_name
  }
}

# IAM name - https://github.com/kodekloudhub/community-faq/blob/main/docs/playgrounds.md#aws-iam

# Ex: lambda_execution_role