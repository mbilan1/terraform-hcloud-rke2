# When Harmony is enabled, rke2-ingress-nginx is disabled and Harmony manages
# its own ingress-nginx. This HelmChartConfig only applies when using the
# RKE2 built-in ingress controller (harmony.enabled = false).
resource "kubectl_manifest" "ingress_configuration" {
  count      = var.harmony.enabled ? 0 : 1
  depends_on = [terraform_data.wait_for_infrastructure]
  yaml_body = templatefile("${path.module}/templates/values/ingress_controller.yaml", {
    enable_modsecurity = var.enable_nginx_modsecurity_waf
    proxy_body_size    = var.nginx_ingress_proxy_body_size
  })
}
