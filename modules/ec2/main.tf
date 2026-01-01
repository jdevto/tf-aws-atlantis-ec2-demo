# =============================================================================
# IAM ROLE FOR EC2 INSTANCE
# =============================================================================

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current AWS region
data "aws_region" "current" {}

# IAM role for EC2 instance
resource "aws_iam_role" "ec2" {
  name = "${var.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-ec2-role"
  })
}

# Attach SSM managed policy
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Policy for S3 access (for Terraform state)
resource "aws_iam_role_policy" "ec2_s3" {
  name = "${var.name}-ec2-s3-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = "arn:aws:s3:::${var.state_bucket_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::${var.state_bucket_name}/*"
      }
    ]
  })
}

# Policy for Secrets Manager access (for GitHub App key and webhook secret)
resource "aws_iam_role_policy" "ec2_secrets" {
  name = "${var.name}-ec2-secrets-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.github_app_key_secret_arn,
          var.github_webhook_secret_arn
        ]
      }
    ]
  })
}

# Policy for DynamoDB access (for state locking)
resource "aws_iam_role_policy" "ec2_dynamodb" {
  name = "${var.name}-ec2-dynamodb-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.state_lock_table}"
      }
    ]
  })
}

# IAM instance profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = merge(var.tags, {
    Name = "${var.name}-ec2-profile"
  })
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================

# Security group for EC2 instance
resource "aws_security_group" "ec2" {
  name        = "${var.name}-ec2-sg"
  description = "Security group for Atlantis EC2 instance"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks != null ? [1] : []
    content {
      description = "Atlantis web interface (CIDR blocks)"
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids != null ? [1] : []
    content {
      description     = "Atlantis web interface (security groups)"
      from_port       = var.port
      to_port         = var.port
      protocol        = "tcp"
      security_groups = var.allowed_security_group_ids
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
    Name = "${var.name}-ec2-sg"
  })
}

# =============================================================================
# AMAZON LINUX 2023 AMI DATA SOURCE
# =============================================================================

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 instance
resource "aws_instance" "ec2" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.sh", {
    github_owner              = var.github_owner
    demo_repo_name            = var.demo_repo_name
    aws_region                = var.aws_region
    state_bucket_name         = var.state_bucket_name
    state_lock_table          = var.state_lock_table
    port                      = tostring(var.port)
    github_app_id             = tostring(var.github_app_id)
    github_app_key_secret_arn = var.github_app_key_secret_arn
    github_webhook_secret_arn = var.github_webhook_secret_arn
    atlantis_url              = var.atlantis_url
  }))

  user_data_replace_on_change = true

  tags = merge(var.tags, {
    Name = "${var.name}-ec2"
  })
}
