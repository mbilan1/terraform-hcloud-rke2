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
  description = "Hetzner Cloud API token with read/write access for creating build servers and snapshots."
  type        = string
  sensitive   = true
}

variable "base_image" {
  description = "Source OS image for the golden snapshot. Must be an Ubuntu LTS release supported by RKE2."
  type        = string
  default     = "ubuntu-24.04"

  validation {
    condition     = can(regex("^ubuntu-", var.base_image))
    error_message = "Only Ubuntu images are supported (e.g. 'ubuntu-24.04')."
  }
}

variable "server_type" {
  description = "Hetzner server type used as the temporary build instance. A small shared-CPU type is sufficient since the image is just installing packages."
  type        = string
  default     = "cx22"
}

variable "location" {
  description = "Hetzner datacenter for the temporary build server. The resulting snapshot is location-independent."
  type        = string
  default     = "hel1"
}

variable "image_name" {
  description = "Base name for the resulting snapshot. A timestamp suffix is appended automatically (e.g. 'rke2-base-1706000000')."
  type        = string
  default     = "rke2-base"
}

variable "kubernetes_version" {
  description = "RKE2 release tag to pre-install into the image. Must match the Terraform module's var.kubernetes_version to avoid version drift at bootstrap time."
  type        = string
  default     = "v1.34.4+rke2r1"
}

variable "enable_cis_hardening" {
  description = "Enable CIS Level 1 hardening (UBUNTU24-CIS benchmark). When true, the Packer build applies OS hardening via the ansible-lockdown/UBUNTU24-CIS role, configures UFW with Kubernetes-specific allow rules, and sets AppArmor to enforce mode. Increases build time by ~5-6 minutes."
  type        = bool
  default     = false
}

source "hcloud" "rke2_base" {
  token       = var.hcloud_token
  image       = var.base_image
  location    = var.location
  server_type = var.server_type
  server_name = "packer-rke2-base"

  snapshot_name = "${var.image_name}-{{timestamp}}"
  snapshot_labels = {
    "managed-by" = "packer"
    "role"       = "rke2-base"
    "base-image" = var.base_image
    # NOTE: rke2-version label allows Terraform data source lookups like:
    # data "hcloud_image" "rke2" { with_selector = "rke2-version=v1.34.4+rke2r1" }
    "rke2-version" = var.kubernetes_version
    # NOTE: cis-hardened label allows operators to filter hardened vs unhardened snapshots.
    # data "hcloud_image" "rke2" { with_selector = "cis-hardened=true" }
    "cis-hardened"  = var.enable_cis_hardening ? "true" : "false"
    "cis-benchmark" = var.enable_cis_hardening ? "UBUNTU24-CIS-v1.0.0-L1" : "none"
  }

  ssh_username = "root"
}

build {
  sources = ["source.hcloud.rke2_base"]

  # Upload Ansible files to the build instance so install-ansible.sh can find requirements.yml.
  # DECISION: Use file provisioner instead of ansible-local's galaxy_file parameter.
  # Why: galaxy_file only installs roles, not collections. We need both (community.general,
  #      ansible.posix) and the CIS role. The file provisioner + install-ansible.sh handles
  #      both via `ansible-galaxy collection install` and `ansible-galaxy role install`.
  provisioner "file" {
    source      = "ansible/"
    destination = "/tmp/packer-files/ansible"
  }

  # Install Ansible + Galaxy dependencies on the build instance
  provisioner "shell" {
    script = "scripts/install-ansible.sh"
  }

  # Run Ansible playbook for system preparation and optional CIS hardening.
  # DECISION: Pass both kubernetes_version and enable_cis_hardening as extra-vars.
  # Why: kubernetes_version controls which RKE2 release is pre-installed (must match
  #      the Terraform module variable). enable_cis_hardening gates the CIS role
  #      inclusion in playbook.yml (see the `when:` condition on the cis-hardening role).
  provisioner "ansible-local" {
    playbook_file = "ansible/playbook.yml"
    role_paths = [
      "ansible/roles/rke2-base",
      "ansible/roles/cis-hardening",
    ]
    extra_vars = "kubernetes_version=${var.kubernetes_version} enable_cis_hardening=${var.enable_cis_hardening}"
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
