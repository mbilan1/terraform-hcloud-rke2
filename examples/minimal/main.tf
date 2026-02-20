# ──────────────────────────────────────────────────────────────────────────────
# Minimal RKE2 cluster — smallest viable configuration
#
# DECISION: This example serves dual purpose:
# 1. Documentation: shows minimum required inputs for the module
# 2. Testing: used by tests/examples.tftest.hcl for plan validation
# Why: Having a testable minimal example catches regressions in default values
#      and ensures the module remains usable with just required variables.
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.44"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

module "rke2" {
  source = "../.."

  hetzner_token = var.hcloud_token
  domain        = var.domain

  # Single master, no workers — cheapest possible cluster
  master_node_count = 1
  worker_node_count = 0

  # Defaults: all addons enabled, no Harmony, no DNS
}

# ──────────────────────────────────────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value       = module.rke2.kube_config
  sensitive   = true
}

output "control_plane_lb_ipv4" {
  description = "Control-plane LB IP"
  value       = module.rke2.control_plane_lb_ipv4
}
