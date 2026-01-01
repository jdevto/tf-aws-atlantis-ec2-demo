# =============================================================================
# SECURITY GROUP FOR APPLICATION LOAD BALANCER
# =============================================================================

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = var.http_listener_port
    to_port     = var.http_listener_port
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
  }

  dynamic "ingress" {
    for_each = var.enable_https_listener && var.certificate_arn != null ? [1] : []
    content {
      description = "HTTPS"
      from_port   = var.https_listener_port
      to_port     = var.https_listener_port
      protocol    = "tcp"
      cidr_blocks = var.alb_ingress_cidrs
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-alb-sg"
  })
}

# =============================================================================
# APPLICATION LOAD BALANCER
# =============================================================================

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = var.enable_http2

  tags = merge(var.tags, {
    Name = "${var.name}-alb"
  })
}

# =============================================================================
# TARGET GROUP
# =============================================================================

resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.target_port
  protocol    = var.target_protocol
  vpc_id      = var.vpc_id
  target_type = var.target_type

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = var.health_check_protocol
    matcher             = var.health_check_matcher
    port                = "traffic-port"
  }

  deregistration_delay = var.deregistration_delay

  tags = merge(var.tags, {
    Name = "${var.name}-tg"
  })
}

# =============================================================================
# TARGET GROUP ATTACHMENT
# =============================================================================

resource "aws_lb_target_group_attachment" "this" {
  count            = var.create_target_attachments ? length(var.target_instance_ids) : 0
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_instance_ids[count.index]
  port             = var.target_port
}

# =============================================================================
# HTTP LISTENER
# =============================================================================

# HTTP listener that redirects to HTTPS (when certificate is provided)
resource "aws_lb_listener" "http_redirect" {
  count             = var.enable_http_listener && var.enable_https_listener && var.certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = var.http_listener_port
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = tostring(var.https_listener_port)
      protocol    = "HTTPS"
      status_code = var.http_redirect_status_code
    }
  }
}

# HTTP listener that forwards directly (when no certificate)
resource "aws_lb_listener" "http_forward" {
  count             = var.enable_http_listener && (var.certificate_arn == null || !var.enable_https_listener) ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = var.http_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# =============================================================================
# HTTPS LISTENER WITH SSL/TLS
# =============================================================================

resource "aws_lb_listener" "https" {
  count             = var.enable_https_listener && var.certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = var.https_listener_port
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Forward to target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
