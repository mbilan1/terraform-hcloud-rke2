# ──────────────────────────────────────────────────────────────────────────────
# Addons module — required providers
#
# DECISION: Declare required_providers but do NOT configure them.
# Why: HashiCorp best practice for child modules — providers are configured
#      in the root module and passed via the providers argument.
# See: https://developer.hashicorp.com/terraform/language/modules/develop/providers
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}
