# ──────────────────────────────────────────────────────────────────────────────
# Addons module outputs
# ──────────────────────────────────────────────────────────────────────────────

output "harmony_deployed" {
  description = "Whether Harmony was deployed"
  value       = var.harmony.enabled
}

output "longhorn_deployed" {
  description = "Whether Longhorn was deployed"
  value       = var.cluster_configuration.longhorn.preinstall
}
