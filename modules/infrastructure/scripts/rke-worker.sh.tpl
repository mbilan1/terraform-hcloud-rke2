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

# Install RKE2 agent binaries — skip if already present from Packer base image.
# DECISION: Same conditional logic as rke-master.sh.tpl.
# Why: See rke-master.sh.tpl — Packer pre-installs both server and agent binaries.
REQUESTED_VERSION="${INSTALL_RKE2_VERSION}"
IMAGE_VERSION=""
if [ -f /etc/rke2-image-version ]; then
  IMAGE_VERSION=$(cat /etc/rke2-image-version | tr -d '[:space:]')
fi

if [ -n "$IMAGE_VERSION" ] && { [ -z "$REQUESTED_VERSION" ] || [ "$IMAGE_VERSION" = "$REQUESTED_VERSION" ]; }; then
  echo "RKE2 $IMAGE_VERSION already installed via Packer image — skipping download."
else
  if [ -n "$IMAGE_VERSION" ] && [ -n "$REQUESTED_VERSION" ] && [ "$IMAGE_VERSION" != "$REQUESTED_VERSION" ]; then
    echo "Version mismatch: image has $IMAGE_VERSION, requested $REQUESTED_VERSION — re-installing."
  else
    echo "No pre-installed RKE2 found — installing $${REQUESTED_VERSION:-latest}."
  fi
  curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" INSTALL_RKE2_VERSION="$REQUESTED_VERSION" sh -
fi

systemctl enable rke2-agent.service
systemctl start rke2-agent.service