# =============================================================================
# AWS SECRETS MANAGER
# =============================================================================

resource "aws_secretsmanager_secret" "this" {
  name        = "${var.secret_name_prefix}-${var.secret_name}"
  description = var.description

  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.secret_name_prefix}-${var.secret_name}"
  })
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.secret_value
}
