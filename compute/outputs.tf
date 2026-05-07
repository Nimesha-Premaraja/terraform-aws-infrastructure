output "private_key_pem" {
  description = "The private key data in PEM format"
  value       = tls_private_key.dev-rsa-key.private_key_pem
  sensitive   = true
}
