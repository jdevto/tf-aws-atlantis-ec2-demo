output "atlantis_url" {
  description = "URL to access Atlantis UI"
  value       = "https://${module.route53.custom_domain}"
}

output "demo_repo_name" {
  description = "Name of the created GitHub repository"
  value       = var.demo_repo_name
}

output "demo_repo_url" {
  description = "URL of the created GitHub repository"
  value       = "https://github.com/${var.github_owner}/${var.demo_repo_name}"
}

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = module.s3-backend.state_bucket_name
}

output "atlantis_instance_id" {
  description = "ID of the Atlantis EC2 instance"
  value       = module.ec2-atlantis.instance_id
}

output "ssm_connect_command" {
  description = "Command to connect to the Atlantis instance via SSM Session Manager"
  value       = "aws ssm start-session --region ${var.region} --target ${module.ec2-atlantis.instance_id}"
}
