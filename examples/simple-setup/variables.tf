variable "hetzner_token" {
  type        = string
  description = "Hetzner Cloud API Token"
}

variable "route53_zone_id" {
  type        = string
  default     = ""
  description = "The Route53 hosted zone ID for DNS records."
}

variable "aws_region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS region for Route53 provider."
}

variable "letsencrypt_issuer" {
  type        = string
  default     = ""
  description = "The email to send notifications regarding let's encrypt."
}