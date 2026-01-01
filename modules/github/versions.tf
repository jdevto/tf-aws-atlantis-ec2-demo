terraform {
  required_providers {
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
