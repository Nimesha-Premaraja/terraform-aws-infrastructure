output "s3_bucket_domain_name" {
  value = module.s3-bucket.s3_bucket_bucket_domain_name
}

output "s3_bucket_website_domain" {
  value = module.s3-bucket.s3_bucket_website_domain
}

output "s3_bucket_website_endpoint" {
  value = module.s3-bucket.s3_bucket_website_endpoint
}