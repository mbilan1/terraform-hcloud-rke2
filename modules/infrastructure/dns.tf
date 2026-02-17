# ──────────────────────────────────────────────────────────────────────────────
# Route53 DNS — wildcard A record pointing to ingress LB
#
# NOTE: Check blocks (dns_requires_zone_id, dns_requires_harmony_ingress)
# remain in the root module's guardrails.tf — they validate root-level
# variable combinations before values are passed to child modules.
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_route53_record" "wildcard" {
  #checkov:skip=CKV2_AWS_23: Wildcard A record intentionally points to ingress LB IPv4; alias target does not apply to this module's pattern.
  count   = var.create_dns_record ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "*.${var.domain}"
  type    = "A"
  ttl     = 300

  records = [hcloud_load_balancer.ingress[0].ipv4]
}
