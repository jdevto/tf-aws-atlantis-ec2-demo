#!/bin/bash
set -e

# Logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Starting Atlantis user data script at $(date) ==="

# Configuration
GITHUB_OWNER="${github_owner}"
ATLANTIS_REPO_ALLOWLIST="github.com/${github_owner}/${demo_repo_name}"
AWS_REGION="${aws_region}"
STATE_BUCKET="${state_bucket_name}"
LOCK_TABLE="${state_lock_table}"
PORT="${port}"
GITHUB_APP_ID="${github_app_id}"
GITHUB_APP_KEY_SECRET_ARN="${github_app_key_secret_arn}"
GITHUB_WEBHOOK_SECRET_ARN="${github_webhook_secret_arn}"
ATLANTIS_URL="${atlantis_url}"

# Retrieve GitHub App private key from Secrets Manager
echo "Retrieving GitHub App private key from Secrets Manager..."
GITHUB_APP_KEY=$(aws secretsmanager get-secret-value \
  --secret-id "$GITHUB_APP_KEY_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

if [ -z "$GITHUB_APP_KEY" ] || [ "$GITHUB_APP_KEY" = "null" ]; then
  echo "Error: Failed to retrieve GitHub App private key from Secrets Manager"
  exit 1
fi
echo "✓ GitHub App private key retrieved from Secrets Manager"

# Retrieve GitHub webhook secret from Secrets Manager
echo "Retrieving GitHub webhook secret from Secrets Manager..."
GITHUB_WEBHOOK_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$GITHUB_WEBHOOK_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

if [ -z "$GITHUB_WEBHOOK_SECRET" ] || [ "$GITHUB_WEBHOOK_SECRET" = "null" ]; then
  echo "Error: Failed to retrieve GitHub webhook secret from Secrets Manager"
  exit 1
fi
echo "✓ GitHub webhook secret retrieved from Secrets Manager"

echo "Configuration:"
echo "  GitHub Owner: $GITHUB_OWNER"
echo "  GitHub App ID: $GITHUB_APP_ID"
echo "  Demo Repo: $ATLANTIS_REPO_ALLOWLIST"
echo "  Atlantis URL: $ATLANTIS_URL"
echo "  AWS Region: $AWS_REGION"
echo "  State Bucket: $STATE_BUCKET"
echo "  Lock Table: $LOCK_TABLE"
echo "  Atlantis Port: $PORT"

# Update system
echo "Updating system packages..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y docker jq curl-minimal
systemctl enable docker
systemctl start docker

# Wait for Docker to be ready
sleep 5
docker --version

# Create Atlantis configuration directory and subdirectories
# Atlantis container runs as UID 100 and needs to create /atlantis-data/bin
mkdir -p /opt/atlantis/bin
# Set ownership to UID 100 (atlantis user in container)
# If UID 100 doesn't exist on host, create it or use group-based permissions
if ! id -u 100 >/dev/null 2>&1; then
    # Create atlantis user with UID 100 if it doesn't exist
    useradd -r -u 100 -d /opt/atlantis -s /sbin/nologin atlantis 2>/dev/null || true
fi
# Set ownership to UID 100 with proper permissions
chown -R 100:100 /opt/atlantis 2>/dev/null || {
    # Fallback: use group permissions if chown fails
    chgrp -R docker /opt/atlantis 2>/dev/null || true
    chmod -R 775 /opt/atlantis
}
# Ensure proper permissions (owner/group can write, others read-only)
chmod 755 /opt/atlantis
chmod 755 /opt/atlantis/bin 2>/dev/null || true

# Write GitHub App private key to file
echo "$GITHUB_APP_KEY" > /opt/atlantis/atlantis-app-key.pem
# Private key should be readable by owner only (UID 100)
chmod 600 /opt/atlantis/atlantis-app-key.pem
chown 100:100 /opt/atlantis/atlantis-app-key.pem 2>/dev/null || {
    chgrp docker /opt/atlantis/atlantis-app-key.pem 2>/dev/null || true
    chmod 640 /opt/atlantis/atlantis-app-key.pem
}
echo "✓ GitHub App private key written to /opt/atlantis/atlantis-app-key.pem"

# Run Atlantis container
echo "Starting Atlantis container..."
docker run -d \
  --name atlantis \
  --restart always \
  -p $${PORT}:$${PORT} \
  -e ATLANTIS_DATA_DIR=/atlantis-data \
  -e AWS_REGION="$AWS_REGION" \
  -e AWS_DEFAULT_REGION="$AWS_REGION" \
  -v /opt/atlantis:/atlantis-data \
  runatlantis/atlantis:latest \
  server \
  --gh-app-id "$GITHUB_APP_ID" \
  --gh-app-key-file /atlantis-data/atlantis-app-key.pem \
  --gh-webhook-secret "$GITHUB_WEBHOOK_SECRET" \
  --write-git-creds \
  --repo-allowlist "$ATLANTIS_REPO_ALLOWLIST" \
  --atlantis-url "$ATLANTIS_URL" \
  --port "$${PORT}" \
  --allow-repo-config \
  --default-tf-version=1.6.0

# Wait for Atlantis to start
sleep 10

# Check if Atlantis is running
if docker ps | grep -q atlantis; then
    echo "✓ Atlantis container is running"
else
    echo "✗ Atlantis container failed to start"
    docker logs atlantis
    exit 1
fi

# Wait a bit more for Atlantis to fully initialize
echo "Waiting for Atlantis to initialize..."
sleep 15

# Check if Atlantis is listening on configured port
echo "Checking if Atlantis is listening on port $${PORT}..."
if ss -tuln | grep -q ":$${PORT}"; then
    echo "✓ Atlantis is listening on port $${PORT}"
else
    echo "✗ Atlantis is NOT listening on port $${PORT}"
    echo ""
    echo "=== Atlantis Container Logs ==="
    docker logs atlantis 2>&1 | tail -50
    echo ""
    echo "=== Troubleshooting ==="
    echo "Common issues:"
    echo "1. GitHub App not installed: Install the GitHub App (ID: $GITHUB_APP_ID) on your organization"
    echo "   Go to: https://github.com/settings/apps and install the app"
    echo "2. Check logs above for specific error messages"
    echo "3. Verify GitHub App permissions are correct"
    exit 1
fi

echo "=== User data script completed at $(date) ==="
echo ""
echo "Summary:"
echo "  ✓ Atlantis service: docker container 'atlantis'"
echo ""
echo "Useful commands:"
echo "  docker ps"
echo "  docker logs atlantis"
echo "  docker logs -f atlantis"
echo "  curl http://localhost:$${PORT}/healthz"
