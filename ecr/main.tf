module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name = "${var.name-prefix}-repo"
  repository_type = "private"
  region          = var.region

  #   repository_read_write_access_arns = ["arn:aws:iam::012345678901:role/terraform"]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 15 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["app"],
          countType     = "imageCountMoreThan",
          countNumber   = 15
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    managed-by  = "devops"
    environment = "dev"
  }
}