# Example Terraform configuration for Atlantis demo
resource "aws_s3_bucket" "example" {
  bucket = repository_name
}
