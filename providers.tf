provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

provider "github" {
  # Authentication methods (in order of precedence):
  # 1. Environment variables (recommended - reliable method):
  #      export GITHUB_TOKEN="ghp_..."          # PAT with required permissions (see below)
  #      export GITHUB_OWNER="your-org-name"    # EXACT org name (e.g. cloudbuildlab)
  # 2. GitHub CLI (gh) - fallback if env vars not set
  #
  # Note: This token is only for Terraform to manage GitHub resources (repos, files, etc.)
  # Atlantis uses GitHub App authentication (configured separately)
  #
  # All repositories created will be in the organization/account specified by GITHUB_OWNER
  owner = var.github_owner
}

provider "githubx" {
  owner = var.github_owner
}
