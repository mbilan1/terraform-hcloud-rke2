# ──────────────────────────────────────────────────────────────────────────────
# Cluster readiness checks, kubeconfig retrieval, and operational lifecycle
#
# DECISION: Readiness checks live in infrastructure module (not addons).
# Why: They validate that the CLUSTER is functional before any addon deployment.
#      Addons depend on cluster_ready anchor output from this module.
#      SSH provisioners connect to infrastructure (master[0]), not to K8s API.
# ──────────────────────────────────────────────────────────────────────────────

# --- Data source: detect existing control-plane LB (for INITIAL_MASTER flag) ---

data "hcloud_load_balancers" "rke2_control_plane" {
  with_selector = "rke2=control-plane"
}

# --- Wait for RKE2 API server on master[0] ---

resource "terraform_data" "wait_for_api" {
  depends_on = [
    hcloud_load_balancer_service.cp_k8s_api,
    hcloud_server.master,
  ]

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for RKE2 to initialize...'",
      "cloud-init status --wait > /dev/null 2>&1",
      "until /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes >/dev/null 2>&1; do echo 'Waiting for API server...'; sleep 10; done",
      "echo 'RKE2 API server is ready!'",
    ]

    connection {
      type        = "ssh"
      host        = hcloud_server.master[0].ipv4_address
      user        = "root"
      private_key = tls_private_key.machines.private_key_openssh
      timeout     = "10m"
    }
  }
}

# --- Wait for ALL nodes to become Ready ---

resource "terraform_data" "wait_for_cluster_ready" {
  depends_on = [
    terraform_data.wait_for_api,
    hcloud_server.master,
    hcloud_server.additional_masters,
    hcloud_server.worker,
  ]

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for all ${var.master_node_count + var.worker_node_count} node(s) to become Ready...'",
      <<-EOT
      EXPECTED=${var.master_node_count + var.worker_node_count}
      export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
      KC=/var/lib/rancher/rke2/bin/kubectl

      # Phase 1: Wait for API server readiness via /readyz endpoint (timeout 300s)
      ELAPSED=0
      until [ "$($KC get --raw='/readyz' 2>/dev/null)" = "ok" ]; do
        if [ $ELAPSED -ge 300 ]; then
          echo "ERROR: API server did not become ready within 300s"
          exit 1
        fi
        echo "Waiting for API server /readyz... $${ELAPSED}s"
        sleep 5
        ELAPSED=$((ELAPSED + 5))
      done
      echo "API server is ready."

      # Phase 2: Wait for all nodes to register and report Ready (timeout 600s)
      ELAPSED=0
      while true; do
        READY=$($KC get nodes --no-headers 2>/dev/null | awk '$2 == "Ready" {c++} END {print c+0}')
        echo "Nodes Ready: $READY / $EXPECTED ($${ELAPSED}s)"
        if [ "$READY" -ge "$EXPECTED" ]; then
          echo "All $EXPECTED node(s) are Ready!"
          break
        fi
        if [ $ELAPSED -ge 600 ]; then
          echo "ERROR: Not all nodes became Ready within 600s"
          $KC get nodes --no-headers 2>/dev/null || true
          exit 1
        fi
        sleep 15
        ELAPSED=$((ELAPSED + 15))
      done
      EOT
    ]

    connection {
      type        = "ssh"
      host        = hcloud_server.master[0].ipv4_address
      user        = "root"
      private_key = tls_private_key.machines.private_key_openssh
      timeout     = "15m"
    }
  }
}

# --- Fetch kubeconfig from master[0] ---

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
    host        = hcloud_server.master[0].ipv4_address
    user        = "root"
    private_key = tls_private_key.machines.private_key_openssh
    sudo        = true
    timeout     = 500
  }

  path = "/etc/rancher/rke2/rke2.yaml"
}

# ──────────────────────────────────────────────────────────────────────────────
# Pre-upgrade etcd snapshot
#
# DECISION: Inline remote-exec instead of external .sh.tpl file
# Why: Cloud-init and scripts/ are immutable infrastructure — they should only
#      contain bootstrap logic. Operational scripts belong inline in their
#      Terraform resource, keeping the scripts/ directory minimal.
# See: docs/PLAN-operational-readiness.md — Step 5
# ──────────────────────────────────────────────────────────────────────────────
resource "terraform_data" "pre_upgrade_snapshot" {
  # NOTE: Only created when etcd backup is configured.
  # Without etcd backup, there is no S3 target for the snapshot.
  count = var.etcd_backup.enabled ? 1 : 0

  depends_on = [terraform_data.wait_for_cluster_ready]

  # Re-run when RKE2 version changes
  triggers_replace = [var.rke2_version]

  connection {
    type        = "ssh"
    host        = hcloud_server.master[0].ipv4_address
    user        = "root"
    private_key = tls_private_key.machines.private_key_openssh
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml",
      "export PATH=\"$PATH:/var/lib/rancher/rke2/bin\"",
      "SNAPSHOT_NAME=\"pre-upgrade-$(date +%Y%m%d-%H%M%S)\"",
      "echo \"Creating pre-upgrade etcd snapshot: $SNAPSHOT_NAME\"",
      "rke2 etcd-snapshot save --name \"$SNAPSHOT_NAME\"",
      "echo \"$SNAPSHOT_NAME\" > /var/lib/rancher/rke2/server/last-pre-upgrade-snapshot",
      "echo 'DONE: etcd snapshot saved'",
    ]
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Cluster health check — runs after cluster operations (upgrade, restore)
#
# DECISION: Inline remote-exec instead of external .sh.tpl file
# Why: Keeps scripts/ immutable (cloud-init only). Health check logic is
#      tightly coupled to the Terraform resource lifecycle — inline is clearer.
#      HTTP URL checks use a bash loop over a Terraform-joined string.
#      Longhorn health checks are handled separately in modules/addons/.
# See: docs/PLAN-operational-readiness.md — Step 4
# ──────────────────────────────────────────────────────────────────────────────
resource "terraform_data" "cluster_health_check" {
  depends_on = [terraform_data.wait_for_cluster_ready]

  # Re-run when RKE2 version changes (triggers health check after upgrade)
  triggers_replace = [var.rke2_version]

  connection {
    type        = "ssh"
    host        = hcloud_server.master[0].ipv4_address
    user        = "root"
    private_key = tls_private_key.machines.private_key_openssh
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml",
      "export PATH=\"$PATH:/var/lib/rancher/rke2/bin\"",
      "EXPECTED=${var.master_node_count + var.worker_node_count}",
      "TIMEOUT=600",
      "ELAPSED=0",
      "echo '=== Cluster Health Check ==='",
      # Check 1: API server /readyz
      "until [ \"$(kubectl get --raw='/readyz' 2>/dev/null)\" = 'ok' ]; do [ $ELAPSED -ge $TIMEOUT ] && echo 'FAIL: API /readyz' && exit 1; sleep 5; ELAPSED=$((ELAPSED + 5)); done",
      "echo 'PASS: API /readyz'",
      # Check 2: All nodes Ready
      "while true; do READY=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 == \"Ready\" {c++} END {print c+0}'); [ \"$READY\" -ge \"$EXPECTED\" ] && break; [ $ELAPSED -ge $TIMEOUT ] && echo \"FAIL: Nodes $READY/$EXPECTED\" && exit 1; sleep 10; ELAPSED=$((ELAPSED + 10)); done",
      "echo \"PASS: Nodes Ready ($EXPECTED/$EXPECTED)\"",
      # Check 3: System pods Running
      "for P in coredns kube-proxy cloud-controller-manager; do C=$(kubectl get pods -A --no-headers 2>/dev/null | grep \"$P\" | grep -c Running || true); [ \"$C\" -eq 0 ] && echo \"FAIL: No running $P pods\" && exit 1; echo \"PASS: $P ($C running)\"; done",
      # Check 4: HTTP endpoints (optional, Terraform-injected)
      "URLS='${join(" ", var.health_check_urls)}'",
      "for URL in $URLS; do CODE=$(curl -sk -o /dev/null -w '%%{http_code}' \"$URL\" 2>/dev/null || echo '000'); if [ \"$CODE\" -ge 200 ] && [ \"$CODE\" -lt 400 ]; then echo \"PASS: HTTP $URL ($CODE)\"; else echo \"FAIL: HTTP $URL ($CODE)\" && exit 1; fi; done",
      "echo '=== All health checks passed ==='",
    ]
  }
}
