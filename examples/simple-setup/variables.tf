variable "hetzner_token" {
  type        = string
  description = "Hetzner Cloud API Token"
}

variable "domain" {
  type        = string
  default     = "example.com"
  description = "Cluster base domain (used by cert-manager HTTP-01 issuer and ingress hosts)."
}

variable "letsencrypt_issuer" {
  type        = string
  default     = "admin@example.com"
  description = "The email to send notifications regarding let's encrypt."
}