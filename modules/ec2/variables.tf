variable "name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the EC2 instance will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the EC2 instance will be deployed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Atlantis"
  type        = string
  default     = "t3.micro"
}

variable "port" {
  description = "Port on which Atlantis will listen"
  type        = number
  default     = 4141
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the port. If provided, traffic from these CIDR blocks will be allowed."
  type        = list(string)
  default     = null
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to access the port. If provided, traffic from these security groups will be allowed."
  type        = list(string)
  default     = null
}

variable "github_app_id" {
  description = "GitHub App ID for Atlantis authentication"
  type        = number
}

variable "github_app_key_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing GitHub App private key (PEM format)"
  type        = string
}

variable "github_webhook_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing GitHub webhook secret"
  type        = string
}

variable "github_owner" {
  description = "GitHub owner (username or organization)"
  type        = string
}

variable "demo_repo_name" {
  description = "Name of the demo GitHub repository"
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

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "atlantis_url" {
  description = "Full URL of Atlantis instance (e.g., https://atlantis.example.com)"
  type        = string
}
