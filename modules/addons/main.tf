# ──────────────────────────────────────────────────────────────────────────────
# Addons module — dependency anchor
#
# DECISION: Use terraform_data as a dependency anchor instead of module-level depends_on.
# Why: Module-level depends_on is too coarse-grained — it creates an implicit
#      dependency on ALL resources in the depended-upon module. Using an explicit
#      anchor preserves the exact same dependency semantics as the original flat
#      structure (addons depend on wait_for_cluster_ready, NOT on health_check).
# ──────────────────────────────────────────────────────────────────────────────

resource "terraform_data" "wait_for_infrastructure" {
  input = var.cluster_ready
}
