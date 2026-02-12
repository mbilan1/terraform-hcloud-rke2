locals {
  ip_addresses = concat(hcloud_server.master[*].ipv4_address, hcloud_server.additional_masters[*].ipv4_address, hcloud_server.worker[*].ipv4_address)
}

resource "aws_route53_record" "wildcard" {
  count   = var.create_dns_record ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "*.${var.domain}"
  type    = "A"
  ttl     = 300

  records = local.ip_addresses
}
