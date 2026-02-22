resource "kubernetes_namespace_v1" "cert_manager" {
  depends_on = [terraform_data.wait_for_infrastructure]
  count      = var.cluster_configuration.cert_manager.preinstall ? 1 : 0
  metadata {
    name = "cert-manager"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }
}

resource "kubernetes_secret_v1" "cert_manager" {
  depends_on = [kubernetes_namespace_v1.cert_manager]
  count      = var.cluster_configuration.cert_manager.preinstall && var.aws_access_key != "" ? 1 : 0
  metadata {
    name      = "route53-credentials-secret"
    namespace = "cert-manager"
  }

  data = {
    secret-access-key = var.aws_secret_key
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

resource "helm_release" "cert_manager" {
  depends_on = [kubernetes_namespace_v1.cert_manager]
  count      = var.cluster_configuration.cert_manager.preinstall ? 1 : 0

  name = "cert-manager"
  # https://cert-manager.io/docs/installation/helm/
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cluster_configuration.cert_manager.version

  namespace = "cert-manager"
  timeout   = 600

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
    {
      name  = "crds.keep"
      value = "true"
    },
    {
      name  = "startupapicheck.timeout"
      value = "5m"
    },
  ]
}

resource "kubectl_manifest" "cert_manager_issuer" {
  depends_on = [kubernetes_secret_v1.cert_manager, helm_release.cert_manager]
  count      = var.cluster_configuration.cert_manager.use_for_preinstalled_components ? 1 : 0
  yaml_body  = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${var.cluster_issuer_name}
spec:
  acme:
    email: ${var.letsencrypt_issuer}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: ${var.cluster_issuer_name}
    solvers:
%{if var.route53_zone_id != ""}
    - dns01:
        route53:
          region: ${var.aws_region}
          hostedZoneID: ${var.route53_zone_id}
%{if var.aws_access_key != ""}
          accessKeyID: ${var.aws_access_key}
          secretAccessKeySecretRef:
            name: route53-credentials-secret
            key: secret-access-key
%{endif}
%{else}
    - http01:
        ingress:
          class: nginx
%{endif}
YAML
}

# ──────────────────────────────────────────────────────────────────────────────
# Harmony: default TLS bootstrap certificate
#
# WORKAROUND: Harmony's built-in echo Ingress is HTTP-only (no spec.tls).
# Why: ingress-nginx will otherwise serve its self-signed "Fake Certificate" for
#      the HTTPS catch-all vhost, which looks like a broken platform.
#      Issuing a real cert for var.domain and configuring ingress-nginx with
#      --default-ssl-certificate fixes the UX without requiring Tutor/Open edX.
# See: https://kubernetes.github.io/ingress-nginx/user-guide/tls/#default-ssl-certificate
# See: https://cert-manager.io/docs/usage/certificate/
resource "kubectl_manifest" "harmony_default_tls_certificate" {
  depends_on = [
    kubernetes_namespace_v1.harmony,
    helm_release.harmony,
    kubectl_manifest.cert_manager_issuer,
  ]

  count = (
    var.harmony.enabled
    && var.cluster_configuration.cert_manager.preinstall
    && var.cluster_configuration.cert_manager.use_for_preinstalled_components
    && local.harmony_enable_default_tls_certificate
  ) ? 1 : 0

  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: harmony-default-tls
  namespace: harmony
spec:
  secretName: ${local.harmony_default_tls_secret_name}
  dnsNames:
    - ${var.domain}
  issuerRef:
    name: ${var.cluster_issuer_name}
    kind: ClusterIssuer
YAML
}
