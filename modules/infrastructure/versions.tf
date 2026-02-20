# ──────────────────────────────────────────────────────────────────────────────
# Infrastructure module — required providers
#
# DECISION: Declare required_providers but do NOT configure them.
# Why: HashiCorp best practice for child modules — providers are configured
#      in the root module and passed via the providers argument.
# See: https://developer.hashicorp.com/terraform/language/modules/develop/providers
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.44"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
    remote = {
      source  = "tenstad/remote"
      version = "~> 0.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
