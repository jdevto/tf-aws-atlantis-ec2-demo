variable "repository_name" {
  description = "Name of the GitHub repository"
  type        = string
}

variable "atlantis_url" {
  description = "URL of the Atlantis instance (for webhook)"
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "state_lock_table" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID to install on the organization"
  type        = number
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret for Atlantis (used to verify webhook payloads)"
  type        = string
  sensitive   = true
}
