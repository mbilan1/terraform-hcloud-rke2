# ──────────────────────────────────────────────────────────────────────────────
# Addons module — external data sources
#
# DECISION: Keep data sources in dedicated data.tf.
# Why: This follows the module structure convention and makes it easier to
#      review which resources rely on remote inputs versus managed objects.
# ──────────────────────────────────────────────────────────────────────────────

# SUC CRD manifest bundle (downloaded only when auto-upgrades are enabled)
data "http" "suc_crd_manifest" {
  count = local.enable_suc_download ? 1 : 0
  url   = "${local.suc_base_url}/crd.yaml"

  lifecycle {
    # DECISION: Validate SUC source inputs before making network requests.
    # Why: Misconfigured version strings/URLs should fail at plan time with
    #      actionable messages instead of opaque HTTP/parse errors.
    precondition {
      condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", local.suc_version))
      error_message = "self_maintenance.system_upgrade_controller_version must be SemVer without 'v' prefix (e.g. 0.19.0)."
    }

    precondition {
      condition     = strcontains(local.suc_base_url, "https://")
      error_message = "SUC base URL must use HTTPS."
    }

    # DECISION: Validate remote manifest payload shape before downstream split("---").
    # Why: A clear postcondition error is easier to diagnose than later failures
    #      in manifest parsing resources when GitHub returns an empty/error body.
    postcondition {
      condition     = length(trimspace(self.response_body)) > 0
      error_message = "SUC CRD manifest download returned an empty response body."
    }
  }
}

# SUC controller manifest bundle (namespace + controller resources)
data "http" "suc_controller_manifest" {
  count = local.enable_suc_download ? 1 : 0
  url   = "${local.suc_base_url}/system-upgrade-controller.yaml"

  lifecycle {
    # DECISION: Validate SUC source inputs before making network requests.
    # Why: Duplicate guards here keep each data source self-validating and
    #      easier to reason about during targeted plans.
    precondition {
      condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", local.suc_version))
      error_message = "self_maintenance.system_upgrade_controller_version must be SemVer without 'v' prefix (e.g. 0.19.0)."
    }

    precondition {
      condition     = strcontains(local.suc_base_url, "https://")
      error_message = "SUC base URL must use HTTPS."
    }

    # DECISION: Enforce non-empty controller manifest for deterministic planning.
    # Why: This fails fast at data-read time instead of producing opaque errors
    #      in kubectl_manifest resources derived from split documents.
    postcondition {
      condition     = length(trimspace(self.response_body)) > 0
      error_message = "SUC controller manifest download returned an empty response body."
    }
  }
}
