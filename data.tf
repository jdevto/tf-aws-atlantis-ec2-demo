# =============================================================================
# DATA SOURCES
# =============================================================================

# Data source for random suffix
resource "random_id" "suffix" {
  byte_length = 3 # 3 bytes = 6 hex characters
}

# Get availability zones (excluding local zones)
data "aws_availability_zones" "available" {
  state                  = "available"
  all_availability_zones = false

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required", "opted-in"]
  }

  # Exclude local zones
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

# Data source for ACM certificate
data "aws_acm_certificate" "web" {
  domain   = "*.${var.domain_name}"
  statuses = ["ISSUED"]
}
