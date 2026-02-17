# ──────────────────────────────────────────────────────────────────────────────
# Infrastructure module outputs (L3)
#
# DECISION: Infrastructure module delivers a working cluster.
# Why: L3 ensures API readiness, outputs kubeconfig credentials, and provides
#      all values that downstream L4 (addons) needs.
# ──────────────────────────────────────────────────────────────────────────────

# --- Kubeconfig credentials ---

output "cluster_host" {
  description = "The Kubernetes API server endpoint URL"
  value       = "https://${hcloud_load_balancer.control_plane.ipv4}:6443"
}

output "cluster_ca" {
  description = "The cluster CA certificate (PEM-encoded)"
  value       = local.cluster_ca
  sensitive   = true
}

output "client_cert" {
  description = "The client certificate for cluster authentication (PEM-encoded)"
  value       = local.client_cert
  sensitive   = true
}

output "client_key" {
  description = "The client private key for cluster authentication (PEM-encoded)"
  value       = local.client_key
  sensitive   = true
}

output "kube_config" {
  description = "The full kubeconfig file content for cluster access"
  value       = local.kube_config
  sensitive   = true
}

# --- Network ---

output "network_id" {
  description = "The ID of the Hetzner Cloud private network"
  value       = hcloud_network.main.id
}

output "network_name" {
  description = "The name of the Hetzner Cloud private network"
  value       = hcloud_network.main.name
}

# --- Load Balancers ---

output "control_plane_lb_ipv4" {
  description = "The IPv4 address of the control-plane load balancer"
  value       = hcloud_load_balancer.control_plane.ipv4
}

output "ingress_lb_ipv4" {
  description = "The IPv4 address of the ingress load balancer. Null when harmony is disabled."
  value       = var.harmony_enabled ? hcloud_load_balancer.ingress[0].ipv4 : null
}

# --- Nodes ---

output "master_nodes_ipv4" {
  description = "The public IPv4 addresses of all master nodes"
  value       = concat(hcloud_server.master[*].ipv4_address, hcloud_server.additional_masters[*].ipv4_address)
}

output "worker_nodes_ipv4" {
  description = "The public IPv4 addresses of all worker nodes"
  value       = hcloud_server.worker[*].ipv4_address
}

output "worker_node_names" {
  description = "The names of all worker nodes (for kubernetes_labels in addons)"
  value       = hcloud_server.worker[*].name
}

# --- SSH (for provisioners in addons module) ---

output "master_ipv4" {
  description = "IPv4 of master[0] for SSH provisioners"
  value       = hcloud_server.master[0].ipv4_address
}

output "ssh_private_key" {
  description = "The SSH private key for remote-exec provisioners"
  value       = tls_private_key.machines.private_key_openssh
  sensitive   = true
}

# --- Dependency anchors ---

output "cluster_ready" {
  description = "Dependency anchor — downstream modules should depend on this"
  value       = terraform_data.wait_for_cluster_ready.id
}
