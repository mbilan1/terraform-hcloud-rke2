resource "kubernetes_ingress_v1" "oidc" {
  depends_on = [null_resource.wait_for_cluster_ready]
  count      = var.expose_oidc_issuer_url ? 1 : 0

  metadata {
    name      = "oidc-ingress"
    namespace = "kube-system"
    annotations = {
      "cert-manager.io/cluster-issuer"               = var.cluster_issuer_name
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    }
  }

  spec {
    ingress_class_name = "nginx"
    rule {
      host = local.oidc_issuer_subdomain
      http {
        path {
          backend {
            service {
              name = "kubernetes"
              port {
                number = 443
              }
            }
          }
          path      = "/.well-known/openid-configuration"
          path_type = "Exact"
        }
        path {
          backend {
            service {
              name = "kubernetes"
              port {
                number = 443
              }
            }
          }
          path      = "/openid/v1/jwks"
          path_type = "Exact"
        }
      }
    }

    tls {
      hosts = [
        local.oidc_issuer_subdomain
      ]
      secret_name = "oidc-tls"
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

resource "kubernetes_cluster_role_binding_v1" "oidc" {
  depends_on = [null_resource.wait_for_cluster_ready]
  count      = var.expose_oidc_issuer_url ? 1 : 0
  metadata {
    name = "service-account-issuer-discovery"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "system:service-account-issuer-discovery"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "Group"
    name      = "system:unauthenticated"
    api_group = "rbac.authorization.k8s.io"
  }
}
