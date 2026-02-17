#!/bin/bash
# RKE2 agent (worker) bootstrap script.
#
# DECISION: Minimal bootstrap — only runtime logic that cannot be in cloud-config.
# Why: HashiCorp best practice — config.yaml is pre-written by cloud-init write_files
#      (via cloudinit_config data source). This script only handles runtime data:
#      detect private IP from Hetzner metadata API, patch config.yaml placeholder,
#      install RKE2, and start the service.
# See: https://developer.hashicorp.com/terraform/language/post-apply-operations
set -euo pipefail

# Wait for Hetzner private network IP to become available via metadata API
NODE_IP=""
while [[ "$NODE_IP" = "" ]]; do
  NODE_IP=$(curl -s --connect-timeout 5 http://169.254.169.254/hetzner/v1/metadata/private-networks | grep "ip:" | cut -f 3 -d" " || true)
  sleep 1
done

# Patch config.yaml with the runtime-detected private IP
# NOTE: __NODE_IP__ placeholder is written by cloud-init write_files part
sed -i "s/__NODE_IP__/$NODE_IP/g" /etc/rancher/rke2/config.yaml

# Install and start RKE2 agent
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" INSTALL_RKE2_VERSION="${INSTALL_RKE2_VERSION}" sh -
systemctl enable rke2-agent.service
systemctl start rke2-agent.service