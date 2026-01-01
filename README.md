# tf-aws-atlantis-ec2-demo

One Terraform project that bootstraps the entire Atlantis demo environment end-to-end on AWS.

## Overview

This project deploys a complete Atlantis demo environment on AWS, including:

- VPC with public/private subnets
- S3 bucket and DynamoDB table for Terraform state backend
- EC2 instance running Atlantis via Docker
- Application Load Balancer (ALB) with HTTPS
- Route53 DNS record
- GitHub repository with demo Terraform code
- GitHub webhook configured to send events to Atlantis

## Prerequisites

1. **AWS Account** with appropriate permissions for:
   - VPC, EC2, S3, DynamoDB, ALB, Route53, ACM, Secrets Manager, IAM
2. **Terraform/OpenTofu** version `>= 1.6.0`
3. **GitHub App** created with:
   - Repository permissions: Contents (Read & write), Pull requests (Read & write), Metadata (Read-only)
   - Webhook secret configured
   - App installed on your organization
   - Private key downloaded (PEM format)
4. **ACM Certificate** for your domain (wildcard certificate: `*.yourdomain.com`) in the same region as deployment
5. **Route53 Hosted Zone** for your domain
6. **GitHub Personal Access Token** with `repo` and `admin:org` scopes (for Terraform to manage GitHub resources)

## Setup

1. **Set environment variables:**

   ```bash
   export GITHUB_TOKEN="ghp_..."          # PAT with repo + admin:org perms
   export GITHUB_OWNER="your-org-name"    # EXACT org name (e.g. cloudbuildlab)
   ```

   **Note:** The GitHub provider will use these environment variables first, then fall back to GitHub CLI (`gh`) if not set.

2. **Configure variables in `terraform.tfvars`:**

   ```hcl
   github_owner               = "your-org-name"
   domain_name                = "your-domain.com"
   github_app_private_key     = <<-EOT
   -----BEGIN RSA PRIVATE KEY-----
   MIIEpAIBAAKCAQEA...
   (multiple lines of base64-encoded key data)
   -----END RSA PRIVATE KEY-----
   EOT
   github_webhook_secret      = "your-webhook-secret-string"
   github_app_id              = 123456
   ```

   **Important:** The `github_app_private_key` must be the full PEM-formatted private key (not the SHA256 fingerprint).

3. **Initialize and deploy:**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **After deployment, manually add repository to GitHub App installation:**
   - Go to: <https://github.com/organizations/{org}/settings/installations>
   - Find your GitHub App installation and click "Configure"
   - Go to "Repository access" → Add the repository

   **Note:** This step requires organization OWNER role. If you're not an owner, the repository must be added manually after creation.

## Testing Guide

### Step 1: Verify Infrastructure Deployment

After `terraform apply` completes, check the outputs:

```bash
terraform output
```

You should see:

- `atlantis_url` - URL to access Atlantis UI
- `demo_repo_url` - URL of the created GitHub repository
- `atlantis_instance_id` - EC2 instance ID
- `ssm_connect_command` - Command to connect via SSM

### Step 2: Verify Atlantis is Running

#### Option A: Check via ALB (Recommended)

```bash
# Get the Atlantis URL
ATLANTIS_URL=$(terraform output -raw atlantis_url)

# Check health endpoint
curl -k https://${ATLANTIS_URL}/healthz
# Should return: ok

# Check Atlantis UI
curl -k https://${ATLANTIS_URL}/
# Should return HTML with Atlantis interface
```

#### Option B: Check via SSM (Direct access to EC2)

```bash
# Connect to the instance
$(terraform output -raw ssm_connect_command)

# Once connected, check Docker container
docker ps | grep atlantis

# Check logs
docker logs atlantis

# Check health locally
curl http://localhost:4141/healthz
# Should return: ok
```

#### Option C: Check ALB Target Health

```bash
# Get ALB ARN (from AWS Console or describe-load-balancers)
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region <region>
```

### Step 3: Verify GitHub Webhook

1. **Check webhook in GitHub:**
   - Go to your repository: `https://github.com/{org}/{repo}/settings/hooks`
   - Verify the webhook is configured with:
     - URL: `https://{your-domain}/events`
     - Content type: `application/json`
     - Events: `issue_comment`, `pull_request`, `pull_request_review`, `pull_request_review_comment`, `push`
     - Status: Active (green checkmark)

2. **Test webhook delivery:**
   - In GitHub, click on the webhook → "Recent Deliveries"
   - Create a test event or wait for a real event
   - Check if delivery was successful (200 status)

### Step 4: Test Atlantis with a Pull Request

1. **Navigate to the demo repository:**

   ```bash
   DEMO_REPO_URL=$(terraform output -raw demo_repo_url)
   echo "Repository: ${DEMO_REPO_URL}"
   ```

2. **Clone and make a change:**

   ```bash
   git clone ${DEMO_REPO_URL}
   cd atlantis-demo-infra

   # Create a new branch
   git checkout -b test-atlantis

   # Make a simple change (e.g., update main.tf)
   echo '# Test comment' >> main.tf

   # Commit and push
   git add main.tf
   git commit -m "test: trigger Atlantis plan"
   git push origin test-atlantis
   ```

3. **Create a Pull Request:**
   - Go to the repository on GitHub
   - Create a PR from `test-atlantis` to `main`
   - Atlantis should automatically comment with a plan

4. **Verify Atlantis Response:**
   - Check the PR comments - you should see Atlantis commenting with:
     - Plan output
     - Instructions to apply
   - Check Atlantis logs (via SSM):

     ```bash
     $(terraform output -raw ssm_connect_command)
     docker logs -f atlantis
     ```

### Step 5: Test Apply Workflow

1. **Approve the PR:**
   - In the PR, comment: `atlantis apply`
   - Atlantis should apply the changes and comment back

2. **Verify State:**

   ```bash
   # Check S3 bucket for state file
   STATE_BUCKET=$(terraform output -raw state_bucket_name)
   aws s3 ls s3://${STATE_BUCKET}/

   # Check DynamoDB for lock table
   LOCK_TABLE=$(terraform output -raw state_lock_table || echo "N/A")
   echo "Lock table: ${LOCK_TABLE}"
   ```

### Step 6: Monitor and Troubleshoot

#### Check Atlantis Logs

```bash
# Via SSM
$(terraform output -raw ssm_connect_command)
docker logs -f atlantis

# Or check user-data logs
sudo tail -f /var/log/user-data.log
```

#### Common Issues

1. **Atlantis not responding:**
   - Check if container is running: `docker ps`
   - Check logs: `docker logs atlantis`
   - Verify GitHub App is installed and repository is added
   - Check security groups allow traffic from ALB

2. **Webhook not working:**
   - Verify webhook URL is accessible: `curl -k https://{domain}/events`
   - Check webhook secret matches in GitHub and Atlantis
   - Verify ALB health checks are passing

3. **GitHub App authentication errors:**
   - Ensure GitHub App is installed on the organization
   - Verify repository is added to the installation (requires owner role)
   - Check private key format (must be PEM, not SHA256 fingerprint)
   - Verify `--gh-app-id` and `--gh-app-key-file` are correctly configured
   - Check error: "wrong number of installations, expected 1, found 0" means app is not installed

4. **State backend issues:**
   - Verify EC2 instance role has S3 and DynamoDB permissions
   - Check bucket and table names are correct
   - Verify IAM permissions

5. **Terraform version errors:**
   - Atlantis is configured to use Terraform 1.6.0 via `--default-tf-version=1.6.0`
   - If you see "Unsupported Terraform Core version", ensure `required_version = ">= 1.6.0"` in versions.tf
   - Atlantis will automatically download the specified Terraform version on first use

6. **Apply requirements not working:**
   - Atlantis is configured with `--allow-repo-config` to allow repository-level configs
   - Verify `apply_requirements: [approved]` is set in `atlantis.yaml`
   - Applies require explicit approval via PR comment: `atlantis apply`

#### Useful Commands

```bash
# Get all outputs
terraform output

# Check specific output
terraform output atlantis_url
terraform output demo_repo_url
terraform output ssm_connect_command

# Connect to instance
$(terraform output -raw ssm_connect_command)

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names $(terraform output -raw name)-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text) \
  --region $(terraform output -raw region)
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

> **Note:** Make sure to:
>
> 1. Delete any state files from S3 if `s3_force_destroy = false`
>
1. Manually remove the repository from GitHub App installation
2. Delete the GitHub repository if you want to remove it completely

## Architecture

```plaintext
Internet
   │
   ▼
Route53 (DNS)
   │
   ▼
ALB (HTTPS:443 → HTTP:4141)
   │
   ▼
EC2 Instance (Private Subnet)
   │
   ├── Docker Container (Atlantis)
   │   ├── GitHub App Authentication (--gh-app-id, --gh-app-key-file)
   │   ├── Webhook Secret (--gh-webhook-secret)
   │   ├── Repo Config Allowed (--allow-repo-config)
   │   ├── Default Terraform Version (--default-tf-version=1.6.0)
   │   └── S3/DynamoDB Backend Access
   │
   └── IAM Role
       ├── S3 Access (state files)
       ├── DynamoDB Access (state locking)
       └── Secrets Manager Access (GitHub App key, webhook secret)

GitHub
   │
   ├── Repository (with Terraform code from modules/github/external/)
   │   ├── backend.tf (S3 backend config)
   │   ├── atlantis.yaml (Atlantis config with apply_requirements)
   │   ├── main.tf, variables.tf, versions.tf, providers.tf, outputs.tf
   │   └── Auto-merged PR from dev → main branch
   │
   └── Webhook → ALB → EC2 → Atlantis (/events endpoint)
```

## Key Features

- **GitHub App Authentication**: Secure authentication using GitHub Apps (no PAT tokens)
- **Repository-Level Configuration**: Atlantis allows repo-level configs via `--allow-repo-config`
- **Apply Requirements**: Requires approval before applying changes (`apply_requirements: [approved]`)
- **Terraform 1.6.0**: Configured to use Terraform 1.6.0 (OpenTofu compatible)
- **Automated Setup**: GitHub repository is automatically seeded with demo Terraform files
- **Secure Secrets**: GitHub App key and webhook secret stored in AWS Secrets Manager
- **HTTPS/SSL**: ALB terminates SSL with ACM certificate
- **Private Networking**: EC2 instance in private subnet, accessible only via ALB

## Outputs

After deployment, the following outputs are available:

- `atlantis_url` - URL to access Atlantis UI (HTTPS)
- `demo_repo_name` - Name of the created GitHub repository
- `demo_repo_url` - URL of the created GitHub repository
- `state_bucket_name` - S3 bucket name for Terraform state
- `atlantis_instance_id` - ID of the Atlantis EC2 instance
- `ssm_connect_command` - Command to connect to the Atlantis instance via SSM Session Manager

## Module Structure

```plaintext
modules/
├── github/
│   ├── external/          # Template files for repository content
│   │   ├── backend.tf
│   │   ├── atlantis.yaml
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── versions.tf
│   │   ├── providers.tf
│   │   └── outputs.tf
│   ├── main.tf            # GitHub repository, files, webhook, PR
│   ├── variables.tf
│   └── outputs.tf
├── ec2/                   # Atlantis EC2 instance
├── alb/                   # Application Load Balancer
├── route53/               # DNS records
├── s3/                    # S3 backend + DynamoDB
├── vpc/                   # VPC and networking
└── secrets-manager/       # AWS Secrets Manager
```

## License

See LICENSE file for details.
