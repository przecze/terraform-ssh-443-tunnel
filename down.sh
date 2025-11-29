#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_CONFIG="$HOME/.ssh/config"

cd "$SCRIPT_DIR"

# Use the restricted tunnel-manager profile
export AWS_PROFILE=personal-tunnel-manager

echo "==> Destroying tunnel instance..."
terraform destroy -auto-approve

# Comment out jump host IP using tag marker (so ssh jump fails when tunnel is down)
echo "==> Disabling jump host..."
if grep -q "#tunnel-manager-ip" "$SSH_CONFIG"; then
    sed -i.bak 's|^[[:space:]]*Hostname \(.*\) #tunnel-manager-ip|    #Hostname \1 #tunnel-manager-ip|' "$SSH_CONFIG"
    echo "    Disabled jump host IP"
else
    echo "    WARNING: '#tunnel-manager-ip' tag not found in SSH config"
fi

# Disable ProxyJump using tag marker
echo "==> Disabling ProxyJump for bluh host..."
if grep -q "#tunnel-manager-proxy-jump" "$SSH_CONFIG"; then
    sed -i.bak 's|^[[:space:]]*ProxyJump \(.*\) #tunnel-manager-proxy-jump|    #ProxyJump \1 #tunnel-manager-proxy-jump|' "$SSH_CONFIG"
    echo "    Disabled ProxyJump for bluh"
else
    echo "    WARNING: '#tunnel-manager-proxy-jump' tag not found in SSH config"
fi

# Clean up backup file
rm -f "$SSH_CONFIG.bak"

echo ""
echo "==> Tunnel destroyed. Jump host and ProxyJump disabled."

