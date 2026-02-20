#!/bin/bash
# Install Ansible on the Packer build instance.
# This runs before the ansible-local provisioner.
set -euo pipefail

apt-get update -q
apt-get install -q -y software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -q -y ansible
ansible --version
