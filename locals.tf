locals {
  name         = "${var.name}-${random_id.suffix.hex}"
  project_name = var.name
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.name
    }
  )
}
