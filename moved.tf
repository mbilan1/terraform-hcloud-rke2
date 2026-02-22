# ──────────────────────────────────────────────────────────────────────────────
# State migration — moved blocks for module split
#
# DECISION: Use moved blocks instead of `tofu state mv` for safer migration.
# Why: HashiCorp best practice — moved blocks are declarative, reviewable,
#      and automatically applied during `tofu apply`. Manual state surgery
#      (state mv) is error-prone and not auditable in code review.
# See: https://developer.hashicorp.com/terraform/language/modules/develop/refactoring
#
# NOTE: Data sources (data.*) do NOT need moved blocks — they are re-computed
# on every plan and have no persistent state to migrate.
#
# NOTE: check {} blocks do NOT need moved blocks — they have no state.
#
# After successful migration: keep these blocks for at least one release cycle
# to handle consumers who haven't applied yet. Remove in the NEXT major version.
# ──────────────────────────────────────────────────────────────────────────────

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Infrastructure module (modules/infrastructure/) — 28 blocks               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# --- Random resources ---

moved {
  from = random_string.master_node_suffix
  to   = module.infrastructure.random_string.master_node_suffix
}

moved {
  from = random_password.rke2_token
  to   = module.infrastructure.random_password.rke2_token
}

moved {
  from = random_string.worker_node_suffix
  to   = module.infrastructure.random_string.worker_node_suffix
}

# --- SSH ---

moved {
  from = tls_private_key.machines
  to   = module.infrastructure.tls_private_key.machines
}

moved {
  from = hcloud_ssh_key.main
  to   = module.infrastructure.hcloud_ssh_key.main
}

moved {
  from = local_sensitive_file.ssh_private_key
  to   = module.infrastructure.local_sensitive_file.ssh_private_key
}

# --- Network ---

moved {
  from = hcloud_network.main
  to   = module.infrastructure.hcloud_network.main
}

moved {
  from = hcloud_network_subnet.main
  to   = module.infrastructure.hcloud_network_subnet.main
}

# --- Firewall ---

moved {
  from = hcloud_firewall.cluster
  to   = module.infrastructure.hcloud_firewall.cluster
}

# --- Servers ---

moved {
  from = hcloud_server.master
  to   = module.infrastructure.hcloud_server.master
}

moved {
  from = hcloud_server.additional_masters
  to   = module.infrastructure.hcloud_server.additional_masters
}

moved {
  from = hcloud_server.worker
  to   = module.infrastructure.hcloud_server.worker
}

# --- Load Balancer: Control Plane ---

moved {
  from = hcloud_load_balancer.control_plane
  to   = module.infrastructure.hcloud_load_balancer.control_plane
}

moved {
  from = hcloud_load_balancer_network.control_plane_network
  to   = module.infrastructure.hcloud_load_balancer_network.control_plane_network
}

moved {
  from = hcloud_load_balancer_target.cp_initial_master
  to   = module.infrastructure.hcloud_load_balancer_target.cp_initial_master
}

moved {
  from = hcloud_load_balancer_target.cp_additional_masters
  to   = module.infrastructure.hcloud_load_balancer_target.cp_additional_masters
}

moved {
  from = hcloud_load_balancer_service.cp_k8s_api
  to   = module.infrastructure.hcloud_load_balancer_service.cp_k8s_api
}

moved {
  from = hcloud_load_balancer_service.cp_register
  to   = module.infrastructure.hcloud_load_balancer_service.cp_register
}

moved {
  from = hcloud_load_balancer_service.cp_ssh
  to   = module.infrastructure.hcloud_load_balancer_service.cp_ssh
}

# --- Load Balancer: Ingress ---

moved {
  from = hcloud_load_balancer.ingress
  to   = module.infrastructure.hcloud_load_balancer.ingress
}

moved {
  from = hcloud_load_balancer_network.ingress_network
  to   = module.infrastructure.hcloud_load_balancer_network.ingress_network
}

moved {
  from = hcloud_load_balancer_target.ingress_workers
  to   = module.infrastructure.hcloud_load_balancer_target.ingress_workers
}

moved {
  from = hcloud_load_balancer_service.ingress_http
  to   = module.infrastructure.hcloud_load_balancer_service.ingress_http
}

moved {
  from = hcloud_load_balancer_service.ingress_https
  to   = module.infrastructure.hcloud_load_balancer_service.ingress_https
}

moved {
  from = hcloud_load_balancer_service.ingress_custom
  to   = module.infrastructure.hcloud_load_balancer_service.ingress_custom
}

# --- DNS ---

moved {
  from = aws_route53_record.wildcard
  to   = module.infrastructure.aws_route53_record.wildcard
}

# --- Readiness / lifecycle ---

moved {
  from = terraform_data.wait_for_api
  to   = module.infrastructure.terraform_data.wait_for_api
}

moved {
  from = terraform_data.wait_for_cluster_ready
  to   = module.infrastructure.terraform_data.wait_for_cluster_ready
}

moved {
  from = terraform_data.pre_upgrade_snapshot
  to   = module.infrastructure.terraform_data.pre_upgrade_snapshot
}

moved {
  from = terraform_data.cluster_health_check
  to   = module.infrastructure.terraform_data.cluster_health_check
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Addons module (modules/addons/) — 24 blocks                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# --- HCCM ---

moved {
  from = kubernetes_secret_v1.hcloud_ccm
  to   = module.addons.kubernetes_secret_v1.hcloud_ccm
}

moved {
  from = helm_release.hccm
  to   = module.addons.helm_release.hccm
}

# --- CSI ---

moved {
  from = kubernetes_secret_v1.hcloud_csi
  to   = module.addons.kubernetes_secret_v1.hcloud_csi
}

moved {
  from = helm_release.hcloud_csi
  to   = module.addons.helm_release.hcloud_csi
}

# --- cert-manager ---

moved {
  from = kubernetes_namespace_v1.cert_manager
  to   = module.addons.kubernetes_namespace_v1.cert_manager
}

moved {
  from = kubernetes_secret_v1.cert_manager
  to   = module.addons.kubernetes_secret_v1.cert_manager
}

moved {
  from = helm_release.cert_manager
  to   = module.addons.helm_release.cert_manager
}

moved {
  from = kubectl_manifest.cert_manager_issuer
  to   = module.addons.kubectl_manifest.cert_manager_issuer
}

# --- Longhorn ---

moved {
  from = kubernetes_namespace_v1.longhorn
  to   = module.addons.kubernetes_namespace_v1.longhorn
}

moved {
  from = kubernetes_secret_v1.longhorn_s3
  to   = module.addons.kubernetes_secret_v1.longhorn_s3
}

moved {
  from = kubectl_manifest.longhorn_iscsi_installer
  to   = module.addons.kubectl_manifest.longhorn_iscsi_installer
}

moved {
  from = kubernetes_labels.longhorn_worker
  to   = module.addons.kubernetes_labels.longhorn_worker
}

moved {
  from = helm_release.longhorn
  to   = module.addons.helm_release.longhorn
}

moved {
  from = terraform_data.longhorn_health_check
  to   = module.addons.terraform_data.longhorn_health_check
}

moved {
  from = terraform_data.longhorn_pre_upgrade_snapshot
  to   = module.addons.terraform_data.longhorn_pre_upgrade_snapshot
}

# --- Ingress controller ---

moved {
  from = kubectl_manifest.ingress_configuration
  to   = module.addons.kubectl_manifest.ingress_configuration
}

# --- Harmony ---

moved {
  from = kubernetes_namespace_v1.harmony
  to   = module.addons.kubernetes_namespace_v1.harmony
}

moved {
  from = helm_release.harmony
  to   = module.addons.helm_release.harmony
}

# --- Self-maintenance ---

moved {
  from = kubernetes_namespace_v1.kured
  to   = module.addons.kubernetes_namespace_v1.kured
}

moved {
  from = helm_release.kured
  to   = module.addons.helm_release.kured
}

moved {
  from = kubectl_manifest.system_upgrade_controller_crds
  to   = module.addons.kubectl_manifest.system_upgrade_controller_crds
}

moved {
  from = kubectl_manifest.system_upgrade_controller_ns
  to   = module.addons.kubectl_manifest.system_upgrade_controller_ns
}

moved {
  from = kubectl_manifest.system_upgrade_controller
  to   = module.addons.kubectl_manifest.system_upgrade_controller
}

moved {
  from = kubectl_manifest.system_upgrade_controller_server_plan
  to   = module.addons.kubectl_manifest.system_upgrade_controller_server_plan
}

moved {
  from = kubectl_manifest.system_upgrade_controller_agent_plan
  to   = module.addons.kubectl_manifest.system_upgrade_controller_agent_plan
}
