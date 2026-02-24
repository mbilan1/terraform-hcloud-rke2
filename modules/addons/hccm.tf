# ──────────────────────────────────────────────────────────────────────────────
# Hetzner Cloud Controller Manager (HCCM)
#
# DECISION: Deploy via official Helm chart from charts.hetzner.cloud.
# Why: Hetzner-maintained chart. Provides node lifecycle management (IP
#      assignment, labeling), cloud route configuration for pod networking,
#      and Load Balancer reconciliation with the Hetzner Cloud API.
# See: https://github.com/hetznercloud/hcloud-cloud-controller-manager
# ──────────────────────────────────────────────────────────────────────────────

locals {
  # DECISION: Centralize HCCM activation switch and iteration keys.
  # Why: Keeping toggle logic in locals avoids duplicated conditional expressions
  #      across resources and makes future policy checks (guardrails/conditions)
  #      easier to maintain.
  deploy_hccm = var.cluster_configuration.hcloud_controller.preinstall

  # NOTE: Map-based for_each yields stable addresses and is friendlier for future
  # metadata extension than raw set-of-string keys.
  hccm_instances = local.deploy_hccm ? {
    primary = {
      release_name = "hccm"
      secret_name  = "hcloud"
      namespace    = "kube-system"
    }
  } : {}

  # DECISION: Keep HCCM values composed in locals before yamlencode.
  # Why: This keeps business intent reviewable in plain HCL and avoids embedding
  #      large inline object literals directly inside resource arguments.
  hccm_values = {
    networking = {
      enabled     = true
      clusterCIDR = "10.42.0.0/16"
    }

    env = {
      HCLOUD_LOAD_BALANCERS_ENABLED = {
        value = "true"
      }
    }

    # DECISION: Define explicit resource requests/limits for predictable scheduling.
    # Why: This aligns with the project gate requirement (Container & K8s #145)
    #      and prevents noisy scheduling under control-plane pressure.
    resources = {
      requests = {
        cpu    = "50m"
        memory = "64Mi"
      }
      limits = {
        cpu    = "250m"
        memory = "256Mi"
      }
    }
  }
}

# DECISION: Store Hetzner API token in a dedicated Kubernetes Secret.
# Why: Helm values end up in the release ConfigMap (visible in etcd). A
#      proper Secret integrates with RBAC, is auditable via K8s audit logs,
#      and supports future migration to external-secrets-operator.
resource "kubernetes_secret_v1" "cloud_controller_token" {
  depends_on = [terraform_data.wait_for_infrastructure]

  for_each = local.hccm_instances

  metadata {
    name      = each.value.secret_name
    namespace = each.value.namespace
    labels = {
      "app.kubernetes.io/component" = "cloud-controller"
      "app.kubernetes.io/name"      = "hcloud-cloud-controller-manager"
      "managed-by"                  = "opentofu"
    }
  }

  data = {
    token   = var.hcloud_api_token
    network = var.network_name
  }

  lifecycle {
    # NOTE: Kubernetes adds internal annotations (kubectl.kubernetes.io/last-applied-configuration)
    # that should not trigger a diff on every plan.
    ignore_changes = [metadata[0].annotations, metadata[0].labels]

    precondition {
      condition     = trimspace(var.hcloud_api_token) != ""
      error_message = "HCCM requires non-empty hcloud_api_token when cluster_configuration.hcloud_controller.preinstall = true."
    }

    precondition {
      condition     = trimspace(var.network_name) != ""
      error_message = "HCCM secret requires non-empty network_name from infrastructure outputs."
    }
  }
}

resource "helm_release" "cloud_controller" {
  depends_on = [kubernetes_secret_v1.cloud_controller_token]

  for_each = local.hccm_instances

  name       = each.value.release_name
  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-cloud-controller-manager"
  namespace  = each.value.namespace
  version    = var.cluster_configuration.hcloud_controller.version
  timeout    = 300

  # DECISION: Enable networking integration for cloud route configuration.
  # Why: HCCM sets up cloud routes for pod-to-pod traffic across nodes on
  #      the Hetzner private network. Without this, inter-node pod traffic
  #      relies solely on the CNI overlay (VXLAN), which adds latency.
  values = [yamlencode(local.hccm_values)]

  lifecycle {
    precondition {
      condition     = can(regex("^[0-9A-Za-z._-]+$", var.cluster_configuration.hcloud_controller.version))
      error_message = "HCCM chart version must be a non-empty chart-compatible string."
    }
  }
}
