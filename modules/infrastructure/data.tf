# ──────────────────────────────────────────────────────────────────────────────
# Infrastructure module — external data sources
#
# DECISION: Keep data sources in dedicated data.tf.
# Why: This keeps readiness/provisioning resources focused on lifecycle logic
#      while centralizing external reads (remote files, http, etc.) in one place.
# ──────────────────────────────────────────────────────────────────────────────

# --- Fetch kubeconfig from master[0] ---
# DECISION: Retrieve kubeconfig through the remote provider with explicit
# post-readiness dependency on full node convergence.
# Why: Addon providers consume this artifact immediately; fetching it only
#      after cluster-wide readiness reduces first-apply race conditions where
#      API is up but node registration/critical daemon scheduling is incomplete.

data "remote_file" "kubeconfig" {
  depends_on = [
    # Reliability compromise (chosen): fetch kubeconfig only after full node readiness,
    # not just API readiness, to reduce early Helm/Kubernetes provider race conditions
    # on first apply.
    #
    # Alternative considered: keep depends_on = [terraform_data.wait_for_api] for faster
    # addon start. Rejected because it can trigger transient failures while workers are
    # still joining, which is noisier for operators and CI.
    terraform_data.wait_for_cluster_ready
  ]
  conn {
    host        = hcloud_server.initial_control_plane[0].ipv4_address
    user        = "root"
    private_key = tls_private_key.ssh_identity.private_key_openssh
    # DECISION: Read as root directly (no sudo wrapper needed).
    # Why: SSH session already authenticates as root in this module.
    sudo    = false
    timeout = 180
  }

  path = "/etc/rancher/rke2/rke2.yaml"

  lifecycle {
    # DECISION: Validate SSH connection inputs before remote read.
    # Why: Missing host/key should fail with clear diagnostics instead of
    #      provider-level SSH errors that are harder to map to root cause.
    precondition {
      condition     = trimspace(hcloud_server.initial_control_plane[0].ipv4_address) != ""
      error_message = "Cannot fetch kubeconfig: initial control-plane IPv4 is empty."
    }

    precondition {
      condition     = trimspace(tls_private_key.ssh_identity.private_key_openssh) != ""
      error_message = "Cannot fetch kubeconfig: SSH private key is empty."
    }

    # DECISION: Validate fetched kubeconfig structure before provider consumption.
    # Why: Kubernetes/Helm provider errors become noisy if kubeconfig is empty
    #      or malformed; explicit postconditions fail earlier with root-cause text.
    postcondition {
      condition     = strcontains(self.content, "apiVersion: v1")
      error_message = "Fetched kubeconfig is malformed: missing apiVersion: v1."
    }

    postcondition {
      condition     = strcontains(self.content, "clusters:")
      error_message = "Fetched kubeconfig is malformed: missing clusters section."
    }
  }
}
