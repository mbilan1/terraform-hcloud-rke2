# ──────────────────────────────────────────────────────────────────────────────
# Infrastructure module — computed locals
#
# NOTE: Only infrastructure-related locals live here.
# Addon-related locals (longhorn_s3_endpoint, SUC CRDs, etc.) live in
# modules/addons/locals.tf.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  # --- Kubeconfig parsing ---
  # DECISION: Parse kubeconfig inline with yamldecode + base64decode.
  # Why: Avoids external tools (yq, jq) and keeps everything in the Terraform graph.
  #      Empty-string guards prevent errors when kubeconfig is not yet available
  #      (e.g., during initial plan before any apply).
  cluster_ca   = data.remote_file.kubeconfig.content == "" ? "" : base64decode(yamldecode(data.remote_file.kubeconfig.content).clusters[0].cluster.certificate-authority-data)
  client_key   = data.remote_file.kubeconfig.content == "" ? "" : base64decode(yamldecode(data.remote_file.kubeconfig.content).users[0].user.client-key-data)
  client_cert  = data.remote_file.kubeconfig.content == "" ? "" : base64decode(yamldecode(data.remote_file.kubeconfig.content).users[0].user.client-certificate-data)
  cluster_host = "https://${hcloud_load_balancer.control_plane.ipv4}:6443"
  kube_config  = replace(data.remote_file.kubeconfig.content, "https://127.0.0.1:6443", local.cluster_host)

  is_highly_available = var.master_node_count >= 3

  # DECISION: Auto-detect Hetzner Object Storage endpoint from lb_location.
  # Why: Reduces configuration burden — operator only needs bucket + credentials.
  # Hetzner endpoints follow pattern: {location}.your-objectstorage.com.
  # See: https://docs.hetzner.com/storage/object-storage/overview
  etcd_s3_endpoint = (
    trimspace(var.etcd_backup.s3_endpoint) != ""
    ? var.etcd_backup.s3_endpoint
    : "${var.lb_location}.your-objectstorage.com"
  )

  etcd_s3_folder = (
    trimspace(var.etcd_backup.s3_folder) != ""
    ? var.etcd_backup.s3_folder
    : var.cluster_name
  )
}
