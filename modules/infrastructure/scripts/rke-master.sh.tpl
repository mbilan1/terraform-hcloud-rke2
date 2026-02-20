#!/bin/bash
# RKE2 server (master) bootstrap script.
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

# Install RKE2 server binaries — skip if already present from Packer base image.
# DECISION: Check /etc/rke2-image-version stamp written by the Ansible role.
# Why: Packer pre-installs RKE2 at image build time to eliminate the ~2-3 min
#      GitHub download from the cloud-init critical path. If the stamp matches
#      the requested version, the download is skipped entirely. Falls back to
#      normal install on stock ubuntu-24.04 images (no stamp file).
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
  curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="$REQUESTED_VERSION" sh -
fi

systemctl enable rke2-server.service
systemctl start rke2-server.service
