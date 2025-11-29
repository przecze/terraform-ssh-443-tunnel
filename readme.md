# Terraform "SSH over 443" Tunnel Scripts
AWS Terraform script to spin up a minimal EC2 instance with SSH on port 443 — useful for WiFi with port restrictions 

Vibe-coded in ~1h with Cursor + claude-4.5-opus-high

## Overview
### Features
* Automatically spins up a minimal, cheap instance that serves SSH over port 443 (bypassing WiFi port restrictions)
* Populates `.ssh/config` with IP of the new instance and enables it as jump host for my main server
* Offers a `down.sh` script that destroys the instance and cleans up the `.ssh/config` file
* Instance is configured to auto-destroy after 4h if I forget to execute the `down.sh` script to avoid additional costs
### Outcome
Every visit to my favourite cafe saves me ~5 mins of manual clicking in AWS console and executing SSH commands for the setup. Saves me some costs if I forget to turn off the instance between visits.

## Prerequisites

- Terraform
- AWS profile `[personal-tunnel-manager]` in `~/.aws/credentials` (see `iam-policy.json` for required permissions)
- Security group allowing ports 22 and 443
- EC2 key pair
- Configure your settings in `terraform.tfvars` (security group name, key name, region)

## SSH Config

Add tags `#tunnel-manager-ip` and `#tunnel-manager-proxy-jump` to your `~/.ssh/config` for the scripts to update:

```
Host jump
    Hostname x.x.x.x #tunnel-manager-ip
    Port 443
    IdentityFile ~/.ssh/mac.pem
    User ec2-user

Host your_ssh_server
    ...
    #ProxyJump jump #tunnel-manager-proxy-jump
```

## Usage

```bash
./up.sh      # Create tunnel, update SSH config, wait until ready
./down.sh    # Destroy tunnel, disable ProxyJump
```

## Features

- Auto-terminates after 4 hours (configurable via `auto_shutdown_hours`)
- Restricted IAM policy (cheap instances only, eu-central-1 only)
- SSH config auto-updated via tags

## Cost

~€0.005/hour (t3.nano in Frankfurt)
