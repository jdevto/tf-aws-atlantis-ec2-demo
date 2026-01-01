variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "github_owner" {
  description = "GitHub organization name (or username) where the repository will be created. Set this to your specific organization name."
  type        = string
}

variable "github_app_id" {
  description = <<-EOT
    GitHub App ID for Atlantis authentication.
    Example: 123456

    This is the App ID (not the Installation ID). You can find it in your GitHub App settings.

    IMPORTANT: The GitHub App must be INSTALLED on your organization/repository
    before Atlantis can use it. After creating the GitHub App, you must:
    1. Go to https://github.com/settings/apps
    2. Find your GitHub App and click "Install App"
    3. Select your organization (or specific repositories)
    4. Grant the necessary permissions

    After installation, you must manually add the repository to the GitHub App installation
    via the GitHub UI (managing installations requires organization OWNER role).

    Without installation, Atlantis will fail with: "wrong number of installations, expected 1, found 0"
    EOT
  type        = number
}

variable "github_app_private_key" {
  description = <<-EOT
    GitHub App private key (PEM format) to store in Secrets Manager.
    This is the full PEM-formatted private key, NOT the SHA256 fingerprint.
    The private key is a multi-line string with BEGIN/END markers.
    Example:
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA...
    (multiple lines of base64-encoded key data)
    -----END RSA PRIVATE KEY-----

    Note: If you only see "SHA256:???????" that's the fingerprint, not the key.
    Download the actual private key from your GitHub App settings.
    EOT
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = <<-EOT
    GitHub webhook secret for Atlantis.
    Example: "your-webhook-secret-string-here"
    EOT
  type        = string
  sensitive   = true
}

variable "demo_repo_name" {
  description = "Name of the demo GitHub repository"
  type        = string
  default     = "atlantis-demo-infra"
}

variable "atlantis_instance_type" {
  description = "EC2 instance type for Atlantis"
  type        = string
  default     = "t3.micro"
}

variable "atlantis_port" {
  description = "Port on which Atlantis will listen"
  type        = number
  default     = 4141
}

variable "name" {
  description = "Name prefix for resources"
  type        = string
  default     = "test"
}

variable "environment" {
  description = "Environment of the resources"
  type        = string
  default     = "dev"
}

variable "one_nat_gateway_per_az" {
  description = "Should be true if you want one NAT Gateway per availability zone. Otherwise, one NAT Gateway will be used for all AZs."
  type        = bool
  default     = false
}

variable "s3_enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "s3_force_destroy" {
  description = "Force destroy the S3 bucket"
  type        = bool
  default     = true
}

variable "dynamodb_deletion_protection_enabled" {
  description = "Enable deletion protection for the DynamoDB table"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
