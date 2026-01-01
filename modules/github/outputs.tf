output "repository_name" {
  description = "Name of the GitHub repository"
  value       = githubx_repository.this.name
}

output "repository_url" {
  description = "URL of the GitHub repository"
  value       = githubx_repository.this.html_url
}

output "webhook_id" {
  description = "ID of the GitHub webhook for Atlantis"
  value       = github_repository_webhook.atlantis.id
}

output "webhook_url" {
  description = "URL of the GitHub webhook"
  value       = github_repository_webhook.atlantis.configuration[0].url
}
