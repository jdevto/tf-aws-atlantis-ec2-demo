# GitHub repository
# The organization is determined by the GitHub provider's 'owner' field
# in the root module (providers.tf). Set var.github_owner to your specific
# organization name to create the repository in that organization.
resource "githubx_repository" "this" {
  name        = var.repository_name
  description = "Terraform S3 backend demo for Atlantis"
  visibility  = "private"
  auto_init   = true # Initialize with README to create default branch
}

# NOTE: The repository must be manually added to the GitHub App installation
# because managing GitHub App installations requires organization OWNER role,
# not just admin role, even with admin:org scope.
#
# After the repository is created, manually add it to the installation:
# 1. Go to: https://github.com/organizations/{org}/settings/installations
# 2. Find your GitHub App installation and click "Configure"
# 3. Go to "Repository access" → Add the repository

resource "githubx_repository_branch" "dev" {
  branch        = "dev"
  repository    = githubx_repository.this.name
  source_branch = githubx_repository.this.default_branch
}

# Backend configuration file
resource "githubx_repository_file" "backend" {
  repository = githubx_repository.this.name
  branch     = githubx_repository_branch.dev.branch
  file       = "backend.tf"
  content = templatefile("${path.module}/external/backend.tf", {
    state_bucket_name = var.state_bucket_name
    repository_name   = var.repository_name
    region            = var.region
    state_lock_table  = var.state_lock_table
  })
  commit_message      = <<-EOM
    docs: add backend.tf

    Configure Terraform backend to use S3 for state storage
    with DynamoDB for state locking.
  EOM
  overwrite_on_create = true

  # Uncomment to allow manual edits without Terraform overwriting:
  lifecycle {
    ignore_changes = [content]
  }
}

# Atlantis configuration file
resource "githubx_repository_file" "atlantis_yaml" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.dev.branch
  file                = "atlantis.yaml"
  content             = file("${path.module}/external/atlantis.yaml")
  commit_message      = <<-EOM
    docs: add atlantis.yaml

    Configure Atlantis to use the repository.
  EOM
  overwrite_on_create = true

  # Uncomment to allow manual edits without Terraform overwriting:
  lifecycle {
    ignore_changes = [content]
  }
}

# Example main.tf file
resource "githubx_repository_file" "main_tf" {
  repository = githubx_repository.this.name
  branch     = githubx_repository_branch.dev.branch
  file       = "main.tf"
  content = templatefile("${path.module}/external/main.tf", {
    repository_name = var.repository_name
  })
  commit_message      = <<-EOM
    feat: add example main.tf

    Add example S3 bucket resource for Atlantis demo.
  EOM
  overwrite_on_create = true

  # Uncomment to allow manual edits without Terraform overwriting:
  lifecycle {
    ignore_changes = [content]
  }
}

# Example variables.tf file
resource "githubx_repository_file" "variables_tf" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.dev.branch
  file                = "variables.tf"
  content             = file("${path.module}/external/variables.tf")
  commit_message      = <<-EOM
    feat: add example variables.tf

    Add example variables file for Terraform configuration.
  EOM
  overwrite_on_create = true

  # Uncomment to allow manual edits without Terraform overwriting:
  lifecycle {
    ignore_changes = [content]
  }
}

# Example versions.tf file
resource "githubx_repository_file" "versions_tf" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.dev.branch
  file                = "versions.tf"
  content             = file("${path.module}/external/versions.tf")
  commit_message      = <<-EOM
    feat: add versions.tf

    Define Terraform and provider version requirements.
  EOM
  overwrite_on_create = true

  # Uncomment to allow manual edits without Terraform overwriting:
  lifecycle {
    ignore_changes = [content]
  }
}

# Example providers.tf file
resource "githubx_repository_file" "providers_tf" {
  repository = githubx_repository.this.name
  branch     = githubx_repository_branch.dev.branch
  file       = "providers.tf"
  content = templatefile("${path.module}/external/providers.tf", {
    region = var.region
  })
  commit_message      = <<-EOM
    feat: add providers.tf

    Configure AWS and random providers.
  EOM
  overwrite_on_create = true

  # Uncomment to allow manual edits without Terraform overwriting:
  lifecycle {
    ignore_changes = [content]
  }
}

# Example outputs.tf file
resource "githubx_repository_file" "outputs_tf" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.dev.branch
  file                = "outputs.tf"
  content             = file("${path.module}/external/outputs.tf")
  commit_message      = <<-EOM
    feat: add outputs.tf

    Add output for S3 bucket name.
  EOM
  overwrite_on_create = true

  # Uncomment to allow manual edits without Terraform overwriting:
  lifecycle {
    ignore_changes = [content]
  }
}

resource "githubx_repository_pull_request_auto_merge" "auto_merge_pr" {
  repository         = githubx_repository.this.name
  base_ref           = "main"
  head_ref           = githubx_repository_branch.dev.branch
  title              = "feat: add initial Terraform configuration"
  body               = <<-EOM
    This PR adds the initial Terraform configuration files for the Atlantis demo:

    - Backend configuration (S3 + DynamoDB)
    - Atlantis configuration
    - Example S3 bucket resource
    - Supporting files (variables, versions, providers, outputs)

    Ready for Atlantis to plan and apply.
  EOM
  merge_when_ready   = true
  merge_method       = "merge"
  wait_for_checks    = true
  auto_delete_branch = true

  depends_on = [
    githubx_repository_file.backend,
    githubx_repository_file.atlantis_yaml,
    githubx_repository_file.main_tf,
    githubx_repository_file.variables_tf,
    githubx_repository_file.versions_tf,
    githubx_repository_file.providers_tf,
    githubx_repository_file.outputs_tf
  ]
}

# GitHub webhook to send events to Atlantis
# This webhook is essential for GitHub to notify Atlantis about pull requests, pushes, etc.
resource "github_repository_webhook" "atlantis" {
  repository = githubx_repository.this.name
  active     = true

  configuration {
    url          = "${var.atlantis_url}/events"
    content_type = "json"
    secret       = var.github_webhook_secret
    insecure_ssl = !startswith(var.atlantis_url, "https://")
  }

  events = [
    "issue_comment",
    "pull_request",
    "pull_request_review",
    "pull_request_review_comment",
    "push"
  ]

  depends_on = [githubx_repository.this]
}
