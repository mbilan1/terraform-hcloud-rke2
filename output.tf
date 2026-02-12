output "kube_config" {
  description = "The full kubeconfig file content for cluster access"
  value       = local.kube_config
  sensitive   = true
}

output "cluster_ca" {
  description = "The cluster CA certificate (base64 encoded)"
  value       = local.cluster_ca
  sensitive   = true
}

output "client_cert" {
  description = "The client certificate for cluster authentication (base64 encoded)"
  value       = local.client_cert
  sensitive   = true
}

output "client_key" {
  description = "The client private key for cluster authentication (base64 encoded)"
  value       = local.client_key
  sensitive   = true
}

output "cluster_host" {
  description = "The Kubernetes API server endpoint URL"
  value       = local.cluster_host
}

output "management_lb_ipv4" {
  description = "The IPv4 address of the management load balancer"
  value       = hcloud_load_balancer.management_lb.ipv4
}

output "management_network_id" {
  description = "The ID of the Hetzner Cloud private network"
  value       = hcloud_network.main.id
}

output "management_network_name" {
  description = "The name of the Hetzner Cloud private network"
  value       = hcloud_network.main.name
}

output "cluster_master_nodes_ipv4" {
  description = "The public IPv4 addresses of all master (control plane) nodes"
  value       = concat(hcloud_server.master[*].ipv4_address, hcloud_server.additional_masters[*].ipv4_address)
}

output "cluster_worker_nodes_ipv4" {
  description = "The public IPv4 addresses of all worker nodes"
  value       = hcloud_server.worker[*].ipv4_address
}

output "cluster_issuer_name" {
  description = "The name of the cert-manager ClusterIssuer created by this module"
  value       = var.cluster_issuer_name
}

output "harmony_infrastructure_values" {
  description = "Infrastructure-specific Harmony values applied by this module (for reference only — already merged into the Helm release)"
  value       = yamlencode(local.harmony_infrastructure_values)
}
