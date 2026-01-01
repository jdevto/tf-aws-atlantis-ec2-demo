# =============================================================================
# VPC MODULE
# =============================================================================

module "vpc" {
  source = "./modules/vpc"

  name                   = local.name
  availability_zones     = slice(data.aws_availability_zones.available.names, 0, 2)
  one_nat_gateway_per_az = var.one_nat_gateway_per_az
  tags                   = local.common_tags
}

# =============================================================================
# S3 BACKEND MODULE (S3 + DynamoDB)
# =============================================================================

module "s3-backend" {
  source = "./modules/s3"

  name                                 = local.name
  enable_versioning                    = var.s3_enable_versioning
  s3_force_destroy                     = var.s3_force_destroy
  dynamodb_deletion_protection_enabled = var.dynamodb_deletion_protection_enabled
  tags                                 = local.common_tags
}

# =============================================================================
# ALB MODULE
# =============================================================================
module "alb" {
  source = "./modules/alb"

  name       = local.name
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids # ALB should be in public subnets

  # Target instance(s) to register
  target_instance_ids = [
    module.ec2-atlantis.instance_id
  ]

  # Target group settings - Atlantis listens on configured port
  target_port     = var.atlantis_port
  target_protocol = "HTTP"

  # Health check settings for Atlantis
  health_check_path = "/healthz"

  # SSL/HTTPS settings (optional - set to null to disable SSL)
  # If you have an ACM certificate, set it here:
  # certificate_arn = "arn:aws:acm:region:account:certificate/cert-id"
  certificate_arn = data.aws_acm_certificate.web.arn

  tags = local.common_tags
}

module "route53" {
  source = "./modules/route53"

  name         = local.name
  domain_name  = var.domain_name
  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
}

# =============================================================================
# SECRETS MANAGER FOR GITHUB APP CREDENTIALS
# =============================================================================

module "github_app_key" {
  source = "./modules/secrets-manager"

  secret_name_prefix = local.name
  secret_name        = "github-app-key"
  secret_value       = var.github_app_private_key
  description        = "GitHub App private key (PEM) for Atlantis"
  tags               = local.common_tags
}

module "github_webhook_secret" {
  source = "./modules/secrets-manager"

  secret_name_prefix = local.name
  secret_name        = "github-webhook-secret"
  secret_value       = var.github_webhook_secret
  description        = "GitHub webhook secret for Atlantis"
  tags               = local.common_tags
}

# =============================================================================
# EC2 ATLANTIS MODULE
# =============================================================================
module "ec2-atlantis" {
  source = "./modules/ec2"

  name                       = local.name
  vpc_id                     = module.vpc.vpc_id
  subnet_id                  = module.vpc.private_subnet_ids[0]
  instance_type              = var.atlantis_instance_type
  port                       = var.atlantis_port
  allowed_security_group_ids = [module.alb.security_group_id]
  github_app_id              = var.github_app_id
  github_app_key_secret_arn  = module.github_app_key.secret_arn
  github_webhook_secret_arn  = module.github_webhook_secret.secret_arn
  github_owner               = var.github_owner
  demo_repo_name             = var.demo_repo_name
  state_bucket_name          = module.s3-backend.state_bucket_name
  state_lock_table           = module.s3-backend.lock_table_name
  aws_region                 = var.region
  atlantis_url               = "https://${module.route53.custom_domain}"
  tags                       = local.common_tags
}

# =============================================================================
# GITHUB MODULE
# =============================================================================

module "github" {
  source = "./modules/github"

  repository_name       = var.demo_repo_name
  github_owner          = var.github_owner
  github_app_id         = var.github_app_id
  github_webhook_secret = var.github_webhook_secret
  atlantis_url          = "https://${module.route53.custom_domain}"
  state_bucket_name     = module.s3-backend.state_bucket_name
  state_lock_table      = module.s3-backend.lock_table_name
  region                = var.region
}
