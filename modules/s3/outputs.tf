output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "uploaded_files" {
  description = "Map of uploaded files with their S3 keys"
  value       = var.upload_files != null ? { for k, v in aws_s3_object.files : k => v.key } : {}
}

output "state_bucket_name" {
  description = "Name of the S3 bucket (for state backend)"
  value       = aws_s3_bucket.this.id
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table"
  value       = var.enable_terraform_state_locking_dynamodb ? aws_dynamodb_table.lock[0].name : null
}

output "lock_table_arn" {
  description = "ARN of the DynamoDB lock table"
  value       = var.enable_terraform_state_locking_dynamodb ? aws_dynamodb_table.lock[0].arn : null
}
