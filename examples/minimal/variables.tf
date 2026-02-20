variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API token."
}

variable "domain" {
  type        = string
  default     = "test.example.com"
  description = "Domain for the cluster."
}
