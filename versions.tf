terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    githubx = {
      source  = "tfstack/githubx"
      version = ">= 1.0"
    }
  }
}
