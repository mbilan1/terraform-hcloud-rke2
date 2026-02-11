resource "kubectl_manifest" "ingress_configuration" {
  depends_on = [null_resource.wait_for_cluster_ready]
  count      = var.enable_nginx_modsecurity_waf ? 1 : 0
  yaml_body  = file("${path.module}/templates/values/ingress_controller.yaml")
}