output "state_bucket" {
  description = "Pass this to `terraform init -backend-config=bucket=...` in each environment."
  value       = aws_s3_bucket.state.bucket
}

output "region" {
  value = var.aws_region
}
