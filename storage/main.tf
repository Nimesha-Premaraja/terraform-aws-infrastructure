data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.15.4"

  bucket = "${var.prefix}-static-website-${local.account_id}"

  # Static website hosting configuration
  website = {
    index_document = "index.html"
    error_document = "index.html"
  }

  # Bucket policy
  attach_policy = true
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "PublicReadGetObject",
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::${var.prefix}-static-website-${local.account_id}/*"
      }
    ]
  })

  # Allow public access
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  # Disable ACLs
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
}

# Upload static website files
resource "aws_s3_object" "website_files" {
  for_each = fileset("${path.module}/static-website", "**/*")

  bucket       = module.s3-bucket.s3_bucket_id
  key          = each.value
  source       = "${path.module}/static-website/${each.value}"
  etag         = filemd5("${path.module}/static-website/${each.value}")
  content_type = lookup(local.mime_types, element(reverse(split(".", each.value)), 0), "binary/octet-stream")
}

locals {
  mime_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    # json = "application/json"
    # png  = "image/png"
    # jpg  = "image/jpeg"
    # jpeg = "image/jpeg"
    # gif  = "image/gif"
    # svg  = "image/svg+xml"
    # ico  = "image/x-icon"
    # txt  = "text/plain"
    # woff = "font/woff"
    # woff2 = "font/woff2"
  }
}
