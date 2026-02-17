# ──────────────────────────────────────────────────────────────────────────────
# Packer template for RKE2 base image (L1/L2)
#
# DECISION: Packer builds a golden image with pre-installed packages.
# Why: Reproducibility — every node starts from the same image regardless of
#      when it's provisioned. Also reduces cloud-init time by ~2-3 minutes
#      (no apt-get during bootstrap).
#
# NOTE: This is a scaffold. Actual Packer builds are out of scope for
#       Terraform module CI — they run separately (manually or via GitHub Actions).
# See: docs/ARCHITECTURE.md — L1/L2 Layers
# ──────────────────────────────────────────────────────────────────────────────

packer {
  required_plugins {
    hcloud = {
      version = ">= 1.6.0"
      source  = "github.com/hetznercloud/hcloud"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "base_image" {
  type    = string
  default = "ubuntu-24.04"
}

variable "server_type" {
  type    = string
  default = "cx22"
}

variable "location" {
  type    = string
  default = "hel1"
}

variable "image_name" {
  type    = string
  default = "rke2-base"
}

source "hcloud" "rke2_base" {
  token       = var.hcloud_token
  image       = var.base_image
  location    = var.location
  server_type = var.server_type
  server_name = "packer-rke2-base"

  snapshot_name   = "${var.image_name}-{{timestamp}}"
  snapshot_labels = {
    "managed-by" = "packer"
    "role"       = "rke2-base"
    "base-image" = var.base_image
  }

  ssh_username = "root"
}

build {
  sources = ["source.hcloud.rke2_base"]

  # Install Ansible on the build instance
  provisioner "shell" {
    script = "scripts/install-ansible.sh"
  }

  # Run Ansible playbook for system hardening and package pre-installation
  provisioner "ansible-local" {
    playbook_file = "ansible/playbook.yml"
    role_paths    = ["ansible/roles/rke2-base"]
  }

  # Clean up for snapshot
  provisioner "shell" {
    inline = [
      "apt-get clean",
      "rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*",
      "cloud-init clean --logs --seed",
      "sync",
    ]
  }
}
