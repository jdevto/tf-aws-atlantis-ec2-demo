terraform {
  backend "s3" {
    bucket         = state_bucket_name
    key            = "${repository_name}/terraform.tfstate"
    region         = region
    dynamodb_table = state_lock_table
    encrypt        = true
  }
}
