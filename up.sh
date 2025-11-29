#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_CONFIG="$HOME/.ssh/config"

cd "$SCRIPT_DIR"

# Use the restricted tunnel-manager profile
export AWS_PROFILE=personal-tunnel-manager

echo "==> Initializing Terraform..."
terraform init -input=false

echo "==> Applying Terraform..."
terraform apply -auto-approve

# Get the new IP from Terraform output
NEW_IP=$(terraform output -raw tunnel_ip)

if [ -z "$NEW_IP" ]; then
    echo "ERROR: Failed to get tunnel IP from Terraform output"
    exit 1
fi

echo "==> Tunnel IP: $NEW_IP"

# Update jump host IP using tag marker FIRST (so ssh jump works for testing)
echo "==> Updating jump host IP in $SSH_CONFIG..."
if grep -q "#tunnel-manager-ip" "$SSH_CONFIG"; then
    sed -i.bak 's|^[[:space:]]*#*Hostname .* #tunnel-manager-ip|    Hostname '"$NEW_IP"' #tunnel-manager-ip|' "$SSH_CONFIG"
    echo "    Updated jump host IP to $NEW_IP"
else
    echo "    WARNING: '#tunnel-manager-ip' tag not found in SSH config"
fi

# Enable ProxyJump using tag marker
echo "==> Enabling ProxyJump for bluh host..."
if grep -q "#tunnel-manager-proxy-jump" "$SSH_CONFIG"; then
    sed -i.bak 's|^[[:space:]]*#ProxyJump \(.*\) #tunnel-manager-proxy-jump|    ProxyJump \1 #tunnel-manager-proxy-jump|' "$SSH_CONFIG"
    echo "    Enabled ProxyJump for bluh"
else
    echo "    WARNING: '#tunnel-manager-proxy-jump' tag not found in SSH config"
fi

# Clean up backup file
rm -f "$SSH_CONFIG.bak"

# Get instance ID and region for status checks
INSTANCE_ID=$(terraform output -raw instance_id)
AWS_REGION=$(grep 'aws_region' terraform.tfvars | cut -d'"' -f2)

# Wait for instance to be fully ready
echo "==> Waiting for instance to initialize..."
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    STATUS=$(aws ec2 describe-instance-status --region "$AWS_REGION" --instance-ids "$INSTANCE_ID" --query 'InstanceStatuses[0].[SystemStatus.Status,InstanceStatus.Status]' --output text 2>/dev/null || echo "unknown unknown")
    SYS_STATUS=$(echo "$STATUS" | awk '{print $1}')
    INST_STATUS=$(echo "$STATUS" | awk '{print $2}')
    
    if [ "$SYS_STATUS" = "ok" ] && [ "$INST_STATUS" = "ok" ]; then
        echo "    Instance ready! (system=$SYS_STATUS, instance=$INST_STATUS)"
        break
    fi
    
    printf "\r    Waiting... (%ds) system=%-12s instance=%-12s" "$WAITED" "$SYS_STATUS" "$INST_STATUS"
    sleep 1
    WAITED=$((WAITED + 1))
done
echo ""

# Wait for SSH on port 443 to be ready
echo "==> Waiting for SSH on port 443..."
WAITED=0
while [ $WAITED -lt 60 ]; do
    if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=accept-new -o BatchMode=yes jump "exit 0" 2>/dev/null; then
        echo "    SSH tunnel ready!"
        break
    fi
    printf "\r    Waiting for sshd on port 443... (%ds)" "$WAITED"
    sleep 1
    WAITED=$((WAITED + 1))
done
echo ""

echo ""
echo "==> TUNNEL READY!"
