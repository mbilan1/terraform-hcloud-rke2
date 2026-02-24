# ──────────────────────────────────────────────────────────────────────────────
# Cluster self-maintenance — OS patching (Kured) + K8s upgrades (SUC)
#
# DECISION: Self-maintenance is gated on HA (≥3 masters).
# Why: Automated reboots and rolling upgrades require a quorum-safe control
#      plane. With a single master, a reboot = total cluster downtime.
#      The guard is enforced below via local.enable_* flags.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  # Gate self-maintenance features on HA topology
  enable_os_patching  = var.enable_auto_os_updates && local.is_ha_cluster
  enable_k8s_upgrades = var.enable_auto_kubernetes_updates && local.is_ha_cluster

  # Combined gate for SUC resources that also require remote manifest access
  enable_suc_download = local.enable_k8s_upgrades && var.allow_remote_manifest_downloads

  # SUC version shorthand — used in download URLs below
  suc_version  = var.cluster_configuration.self_maintenance.system_upgrade_controller_version
  suc_base_url = "https://github.com/rancher/system-upgrade-controller/releases/download/v${local.suc_version}"

  # DECISION: Keep deterministic for_each maps with explicit keys.
  # Why: Existing moved blocks and historical state transitions already target
  #      these keys ("kured", "server-plan", "agent-plan"). Preserving keys
  #      avoids unnecessary state churn while still allowing internal refactors.
  kured_instances = local.enable_os_patching ? {
    kured = {
      release_name = "kured"
      namespace    = "kured"
    }
  } : {}

  suc_server_plan_instances = local.enable_k8s_upgrades ? {
    "server-plan" = {
      concurrency = 1
      role_key    = "node-role.kubernetes.io/control-plane"
      role_op     = "In"
      role_values = ["true"]
    }
  } : {}

  suc_agent_plan_instances = local.enable_k8s_upgrades ? {
    "agent-plan" = {
      concurrency = 2
      role_key    = "node-role.kubernetes.io/control-plane"
      role_op     = "NotIn"
      role_values = ["true"]
    }
  } : {}

  # NOTE: Shared SUC image/channel constants kept in locals for consistency.
  suc_upgrade_image   = "rancher/rke2-upgrade"
  suc_upgrade_channel = "https://update.rke2.io/v1-release/channels/stable"
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Kured — Kubernetes Reboot Daemon                                          ║
# ║  Watches /var/run/reboot-required and cordons + reboots nodes one at a time║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "kubernetes_namespace_v1" "reboot_daemon" {
  depends_on = [terraform_data.wait_for_infrastructure]

  for_each = local.kured_instances

  metadata {
    name = each.value.namespace
    labels = {
      "app.kubernetes.io/component" = "reboot-daemon"
      "app.kubernetes.io/name"      = "kured"
      "managed-by"                  = "opentofu"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}

resource "helm_release" "reboot_daemon" {
  depends_on = [kubernetes_namespace_v1.reboot_daemon]

  for_each = local.kured_instances

  name       = each.value.release_name
  repository = "https://kubereboot.github.io/charts"
  chart      = "kured"
  namespace  = each.value.namespace
  version    = var.cluster_configuration.self_maintenance.kured_version
  timeout    = 300

  values = [yamlencode({
    configuration = {
      period = "1h0m0s"
    }
  })]

  lifecycle {
    precondition {
      condition     = trimspace(var.cluster_configuration.self_maintenance.kured_version) != ""
      error_message = "kured_version must be non-empty when OS auto-updates are enabled."
    }
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  System Upgrade Controller (SUC) — Automated RKE2 patch upgrades           ║
# ║  Downloads CRDs + controller from GitHub, creates server + agent Plans     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# DECISION: Use sha1() of document content as for_each key instead of list index.
# Why: List-index keys (0, 1, 2...) are fragile — if an upstream CRD is added or
#      removed in the middle, all subsequent indices shift and OpenTofu sees
#      destroy+create for unchanged resources. Content-based keys are stable
#      across upstream reorderings.
resource "kubectl_manifest" "suc_crds" {
  depends_on = [terraform_data.wait_for_infrastructure]

  for_each = local.enable_suc_download ? {
    for doc in local.suc_crd_documents : sha1(doc) => doc
  } : {}

  yaml_body = each.value

  lifecycle {
    precondition {
      condition     = !local.enable_suc_download || length(local.suc_crd_documents) > 0
      error_message = "SUC CRD manifest set is empty after parsing; verify downloaded YAML content."
    }
  }
}

# Namespace resources must be applied before other controller resources.
# Split into two resource blocks: namespace first, everything else second.
resource "kubectl_manifest" "suc_namespace" {
  depends_on = [terraform_data.wait_for_infrastructure, kubectl_manifest.suc_crds]

  for_each = local.enable_suc_download ? {
    for doc in local.suc_controller_documents : sha1(doc) => doc
    if strcontains(doc, "kind: Namespace")
  } : {}

  yaml_body = each.value

  lifecycle {
    # DECISION: Require explicit Namespace document in SUC controller bundle.
    # Why: Applying controller objects before namespace creation causes noisy
    #      reconciliation failures; fail early with a direct configuration hint.
    precondition {
      condition = !local.enable_suc_download || length([
        for doc in local.suc_controller_documents : doc
        if strcontains(doc, "kind: Namespace")
      ]) > 0
      error_message = "SUC controller manifest bundle must include a Namespace document."
    }
  }
}

resource "kubectl_manifest" "suc_controller" {
  depends_on = [terraform_data.wait_for_infrastructure, kubectl_manifest.suc_crds, kubectl_manifest.suc_namespace]

  for_each = local.enable_suc_download ? {
    for doc in local.suc_controller_documents : sha1(doc) => doc
    if !strcontains(doc, "kind: Namespace")
  } : {}

  yaml_body = each.value

  lifecycle {
    precondition {
      condition     = !local.enable_suc_download || length(local.suc_controller_documents) > 0
      error_message = "SUC controller manifest set is empty after parsing; verify downloaded YAML content."
    }
  }
}

# ── SUC Upgrade Plans ────────────────────────────────────────────────────────
# DECISION: Use yamlencode() to build Plan manifests inline.
# Why: Upstream module uses file() to load static YAML templates. We use
#      yamlencode() for deterministic output and to keep all configuration
#      visible in a single file rather than split across templates.

resource "kubectl_manifest" "suc_server_upgrade_plan" {
  depends_on = [kubectl_manifest.suc_controller]

  for_each = local.suc_server_plan_instances

  yaml_body = yamlencode({
    apiVersion = "upgrade.cattle.io/v1"
    kind       = "Plan"
    metadata = {
      name      = each.key
      namespace = "system-upgrade"
      labels = {
        "rke2-upgrade" = "server"
      }
    }
    spec = {
      concurrency = each.value.concurrency
      cordon      = true
      nodeSelector = {
        matchExpressions = [
          { key = "rke2-upgrade", operator = "Exists" },
          { key = "rke2-upgrade", operator = "NotIn", values = ["disabled", "false"] },
          { key = each.value.role_key, operator = each.value.role_op, values = each.value.role_values },
        ]
      }
      serviceAccountName = "system-upgrade"
      prepare = {
        image = local.suc_upgrade_image
        args  = ["etcd-snapshot", "save", "--name", "pre-suc-upgrade"]
      }
      upgrade = {
        image = local.suc_upgrade_image
      }
      channel = local.suc_upgrade_channel
    }
  })

  lifecycle {
    # DECISION: Validate SUC plan inputs before applying manifest.
    # Why: Failing at Terraform planning time gives clearer diagnostics than
    #      runtime reconciliation failures in system-upgrade-controller.
    precondition {
      condition     = each.value.concurrency > 0
      error_message = "SUC server plan concurrency must be > 0."
    }

    precondition {
      condition     = trimspace(local.suc_upgrade_channel) != "" && strcontains(local.suc_upgrade_channel, "https://")
      error_message = "SUC upgrade channel must be a non-empty HTTPS URL."
    }

    precondition {
      condition     = length(each.value.role_values) > 0
      error_message = "SUC server plan role_values must contain at least one value."
    }
  }
}

resource "kubectl_manifest" "suc_agent_upgrade_plan" {
  depends_on = [kubectl_manifest.suc_controller]

  for_each = local.suc_agent_plan_instances

  yaml_body = yamlencode({
    apiVersion = "upgrade.cattle.io/v1"
    kind       = "Plan"
    metadata = {
      name      = each.key
      namespace = "system-upgrade"
      labels = {
        "rke2-upgrade" = "agent"
      }
    }
    spec = {
      concurrency = each.value.concurrency
      cordon      = true
      drain = {
        force              = true
        deleteEmptyDirData = true
        ignoreDaemonSets   = true
        gracePeriodSeconds = 60
      }
      nodeSelector = {
        matchExpressions = [
          { key = "rke2-upgrade", operator = "Exists" },
          { key = "rke2-upgrade", operator = "NotIn", values = ["disabled", "false"] },
          { key = each.value.role_key, operator = each.value.role_op, values = each.value.role_values },
        ]
      }
      serviceAccountName = "system-upgrade"
      prepare = {
        image = local.suc_upgrade_image
        args  = ["prepare", "server-plan"]
      }
      upgrade = {
        image = local.suc_upgrade_image
      }
      channel = local.suc_upgrade_channel
    }
  })

  lifecycle {
    # DECISION: Validate SUC plan inputs before applying manifest.
    # Why: Keeps plan-time failures actionable and prevents invalid Plan CRs.
    precondition {
      condition     = each.value.concurrency > 0
      error_message = "SUC agent plan concurrency must be > 0."
    }

    precondition {
      condition     = trimspace(local.suc_upgrade_channel) != "" && strcontains(local.suc_upgrade_channel, "https://")
      error_message = "SUC upgrade channel must be a non-empty HTTPS URL."
    }

    precondition {
      condition     = length(each.value.role_values) > 0
      error_message = "SUC agent plan role_values must contain at least one value."
    }
  }
}
