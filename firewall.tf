resource "hcloud_firewall" "cluster" {
  name = "${var.cluster_name}-firewall"

  # Allow HTTP
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow HTTPS
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow SSH (consider restricting source_ips in production)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow Kubernetes API
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow RKE2 supervisor (node registration) — internal network only
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "9345"
    source_ips = [
      var.network_address
    ]
  }

  # Allow etcd — internal network only
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "2379-2380"
    source_ips = [
      var.network_address
    ]
  }

  # Allow kubelet API — internal network only
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "10250"
    source_ips = [
      var.network_address
    ]
  }

  # Allow NodePort range — internal network only
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "30000-32767"
    source_ips = [
      var.network_address
    ]
  }

  # Allow ICMP (ping)
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

