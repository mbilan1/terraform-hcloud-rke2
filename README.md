<div align="center" width="100%">
    <h2>hcloud rke2 module</h2>
    <p>Enterprise-grade RKE2 Kubernetes cluster on Hetzner Cloud, purpose-built for Open edX deployments in Europe.</p>
    <a target="_blank" href="https://github.com/mbilan1/terraform-hcloud-rke2/releases"><img src="https://img.shields.io/github/v/release/mbilan1/terraform-hcloud-rke2?display_name=tag" /></a>
    <a target="_blank" href="https://github.com/mbilan1/terraform-hcloud-rke2/commits/main"><img src="https://img.shields.io/github/last-commit/mbilan1/terraform-hcloud-rke2" /></a>
</div>

> [!WARNING]
> **This module is experimental and NOT production-ready.** APIs, variable names, and default values may change without notice between releases. Use at your own risk.

> **This is a fork of [wenzel-felix/terraform-hcloud-rke2](https://github.com/wenzel-felix/terraform-hcloud-rke2).**
> The original module is available on the [Terraform Registry](https://registry.terraform.io/modules/wenzel-felix/rke2/hcloud/latest).

## 🎯 Mission

The primary goal of this module is to provide an **enterprise-grade, cost-effective, and secure Kubernetes cluster** optimized for deploying [Open edX](https://openedx.org/) in Europe via [openedx-k8s-harmony](https://github.com/openedx/openedx-k8s-harmony).

By running on **Hetzner Cloud** — a European infrastructure provider with data centers in Germany and Finland — this module supports **European digital sovereignty**: student data, course content, and platform operations stay within EU jurisdiction, fully compliant with GDPR and European data protection regulations.

**Key principles:**
- **Open edX-first** — every default, dependency version, and architectural decision is aligned with the Harmony chart and Tutor deployment workflow
- **Affordable** — Hetzner Cloud offers some of the best price-to-performance ratios in Europe, making production-grade Open edX accessible to universities, NGOs, and small enterprises
- **Fast** — a fully operational cluster with all prerequisites (ingress, cert-manager, CSI, monitoring, Harmony) deploys in under 15 minutes
- **Secure** — hardened firewall rules, TLS everywhere via cert-manager + Let's Encrypt, OTel collector with least-privilege security context, sensitive outputs marked as such
- **Sovereign** — EU-hosted infrastructure, no dependency on US hyperscalers for compute or storage

## Changes from upstream

This fork includes the following improvements over the original module:

### Reliability
- **Cluster readiness check** — replaced `time_sleep` with a two-phase `null_resource` that polls `/readyz` and waits for all nodes to report `Ready` status before deploying workloads
- **Firewall attachment fix** — removed `hcloud_firewall_attachment` (only one per firewall allowed by the provider); firewall is now bound via `firewall_ids` on each `hcloud_server`, fixing `tofu destroy` race conditions
- **cert-manager helm fix** — use `crds.enabled` + `crds.keep` (correct for v1.19.x), increased timeout to 600s and `startupapicheck.timeout` to 5m
- **Load balancer health checks** — HTTP `/healthz` for K8s API (6443), TCP for SSH (22), RKE2 registration (9345), and custom ports

### DNS & TLS
- **Replaced Cloudflare with AWS Route53** — DNS records are now created via `aws_route53_record` in a Route53 hosted zone
- **cert-manager ClusterIssuer** — uses Route53 DNS-01 solver; ClusterIssuer named `harmony-letsencrypt-global` by default for compatibility with [openedx-k8s-harmony](https://github.com/openedx/openedx-k8s-harmony) (configurable via `cluster_issuer_name`)
- **Supports both explicit and IAM credentials** — pass `aws_access_key`/`aws_secret_key` or rely on default AWS credentials chain (IRSA, instance profile, env vars)

### Harmony (Open edX) compatibility
- **ClusterIssuer name `harmony-letsencrypt-global`** — matches the name hardcoded in Harmony's Tutor plugin `k8s-services` patch (`cert-manager.io/cluster-issuer: harmony-letsencrypt-global`); configurable via `cluster_issuer_name` variable
- **IngressClass `nginx`** — RKE2's built-in `rke2-ingress-nginx` provides IngressClass `nginx`, matching Harmony's `K8S_HARMONY_INGRESS_CLASS_NAME` default
- **cert-manager v1.19.3 with CRDs** — installed via Helm with `crds.enabled: true`, `crds.keep: true`, ClusterIssuer uses DNS-01 solver (Route53) for wildcard certificate support. Version synced with Harmony's cert-manager dependency
- **kube-prometheus-stack v81.0.1** — version synced with Harmony's `prometheusstack` dependency to avoid CRD conflicts
- **metrics-server** — provided by RKE2's built-in `rke2-metrics-server`
- **Hetzner CSI driver** — provides `hcloud-volumes` StorageClass (default) for persistent volumes required by Open edX (MySQL, MongoDB, Elasticsearch, Meilisearch PVCs); installed via Helm chart from `charts.hetzner.cloud`
- **proxy-body-size** — nginx ingress controller defaults to `100m` (matching Harmony's ingress annotation `nginx.ingress.kubernetes.io/proxy-body-size: 100m`), configurable via `nginx_ingress_proxy_body_size`
- **ssl-redirect** — monitoring ingress annotated with `nginx.ingress.kubernetes.io/ssl-redirect: "true"`
- **Harmony values output** — `harmony_recommended_values` output provides a ready-to-use `values.yaml` snippet for the Harmony Helm chart (includes `prometheusstack.enabled: false`)

### Security
- **Firewall rules** — proper ingress rules for all required ports; internal-only access for etcd, kubelet, RKE2 registration, and NodePort ranges
- **Sensitive variables** — `sensitive = true` on `hetzner_token`, `aws_access_key`, `aws_secret_key`, and all credential outputs
- **OTel collector hardening** — pinned image by digest, `runAsNonRoot`, `readOnlyRootFilesystem`, `drop ALL` capabilities, `seccompProfile: RuntimeDefault`, resource requests/limits, liveness/readiness probes

### Bug fixes
- **network.tf** — subnet was incorrectly using `network_address` instead of `subnet_address`
- **rke-master.sh.tpl** — fixed `kube-proxy` → `kube-proxy-arg`, OIDC condition `!= null` → `!= ""`, added `set -euo pipefail`
- **rke-worker.sh.tpl** — added `set -euo pipefail` and error handling
- **ssh.tf** — renamed `local_file "name"` → `"ssh_private_key"`
- **OIDC ingress** — moved from `default` to `kube-system` namespace, fixed count condition to use bool type

### Code quality
- Added `required_version >= 1.5.0` and declared all implicit providers with version constraints
- Added input validations: domain non-empty, `master_node_count` prevents split-brain (must be 1 or >= 3)
- Added descriptions to all outputs
- Updated defaults: `ubuntu-24.04`, `cx23`, three-location spread (`hel1`, `nbg1`, `fsn1`)
- Normalized all files to Unix (LF) line endings
- Clean pass: `tofu fmt`, `tofu validate`, `tflint`
- Security aligned with Trivy, Checkov, and KICS best practices

## ✨ Features

- Create a robust Kubernetes cluster deployed to multiple zones
- Fast and easy to use
- Available as module

## 🤔 Why?

There are existing Kubernetes projects with Terraform on Hetzner Cloud, but they often seem to have a large overhead of code. This project focuses on creating an integrated Kubernetes experience for Hetzner Cloud with high availability and resilience while keeping a small code base. 

## 🔧 Prerequisites

There are no special prerequirements in order to take advantage of this module. Only things required are:
* a Hetzner Cloud account
* access to Terraform
* (Optional) If you want DNS and TLS certificate management you need an AWS account with a Route53 hosted zone

## 🚀 Usage

### Standalone

``` bash
terraform init
terraform apply
```

### As module

Refer to the module registry documentation [here](https://registry.terraform.io/modules/wenzel-felix/rke2/hcloud/latest).

## Maintain/upgrade your cluster (API server)

### Change node size / Change node operating system / Upgrade cluster version
Change the Terraform variable to the desired configuration, then go to the Hetzner Cloud UI and remove one master at a time and apply the configuration after each.
To ensure minimal downtime while you upgrade the cluster consider [draining the node](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/) you plan to replace/upgrade.

_Note:_ For upgrading your cluster version please review any breaking changes on the [official rke2 repository](https://github.com/rancher/rke2/releases).

## Deploying Open edX with Harmony

This module is pre-aligned with [openedx-k8s-harmony](https://github.com/openedx/openedx-k8s-harmony). The following components are already provided by the RKE2 cluster and **must be disabled** in the Harmony chart:

| Component | Provided by | Harmony setting |
|---|---|---|
| ingress-nginx | RKE2 built-in (`rke2-ingress-nginx`, IngressClass: `nginx`) | `ingress-nginx.enabled: false` |
| cert-manager | This Terraform module (namespace: `cert-manager`) | `cert-manager.enabled: false` |
| ClusterIssuer | This module (`harmony-letsencrypt-global`, DNS-01/Route53) | — (auto-discovered by name) |
| metrics-server | RKE2 built-in (`rke2-metrics-server`) | `metricsserver.enabled: false` |
| kube-prometheus-stack | This Terraform module (namespace: `monitoring`, v81.0.1) | `prometheusstack.enabled: false` |
| Hetzner CSI driver | This Terraform module (StorageClass: `hcloud-volumes`) | — (default StorageClass for PVCs) |

### Step 1: Deploy the cluster

```hcl
module "rke2" {
  source             = "mbilan1/rke2/hcloud"
  hetzner_token      = var.hetzner_token
  domain             = "example.com"
  master_node_count  = 3
  worker_node_count  = 2
  create_dns_record  = true
  route53_zone_id    = var.route53_zone_id
  letsencrypt_issuer = "admin@example.com"

  cluster_configuration = {
    hcloud_controller = { preinstall = true }
    hcloud_csi        = { preinstall = true, default_storage_class = true }
    cert_manager      = { preinstall = true }
  }
}
```

### Step 2: Install the Harmony chart

Use the `harmony_recommended_values` output as a starting point:

```bash
terraform output -raw harmony_recommended_values > harmony-values.yaml
```

Install the chart:

```bash
helm repo add harmony https://openedx.github.io/openedx-k8s-harmony
helm install harmony harmony/harmony-chart \
  --namespace harmony --create-namespace \
  -f harmony-values.yaml
```

### Step 3: Deploy Tutor instances

Install the Harmony Tutor plugin and configure your instance:

```bash
pip install tutor-contrib-harmony-plugin
tutor plugins enable k8s_harmony
tutor config save
tutor k8s launch
```

The plugin automatically creates Ingress resources with:
- `cert-manager.io/cluster-issuer: harmony-letsencrypt-global` — matched by this module's ClusterIssuer
- `ingressClassName: nginx` — matched by RKE2's built-in ingress controller
- `nginx.ingress.kubernetes.io/proxy-body-size: 100m` — matched by this module's ingress controller default

## 📖 Module Reference

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | ~> 1.44 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.11 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.4 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.19 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.4 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.5 |
| <a name="requirement_remote"></a> [remote](#requirement\_remote) | ~> 0.2 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |
### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.31.0 |
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | 1.60.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.1 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.19.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.0.1 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.6.2 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |
| <a name="provider_remote"></a> [remote](#provider\_remote) | 0.2.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.2.1 |
### Resources

| Name | Type |
|------|------|
| [aws_route53_record.wildcard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [hcloud_firewall.cluster](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/firewall) | resource |
| [hcloud_load_balancer.control_plane](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer) | resource |
| [hcloud_load_balancer.ingress](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer) | resource |
| [hcloud_load_balancer_network.control_plane_network](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_network) | resource |
| [hcloud_load_balancer_network.ingress_network](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_network) | resource |
| [hcloud_load_balancer_service.cp_k8s_api](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_service.cp_register](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_service.cp_ssh](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_service.ingress_custom](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_service.ingress_http](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_service.ingress_https](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_service) | resource |
| [hcloud_load_balancer_target.cp_additional_masters](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_target) | resource |
| [hcloud_load_balancer_target.cp_initial_master](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_target) | resource |
| [hcloud_load_balancer_target.ingress_workers](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/load_balancer_target) | resource |
| [hcloud_network.main](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/network) | resource |
| [hcloud_network_subnet.main](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/network_subnet) | resource |
| [hcloud_server.additional_masters](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/server) | resource |
| [hcloud_server.master](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/server) | resource |
| [hcloud_server.worker](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/server) | resource |
| [hcloud_ssh_key.main](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/ssh_key) | resource |
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.harmony](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.hccm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.hcloud_csi](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.istio_base](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.istiod](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kured](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.loki](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.prom_stack](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.tempo](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.cert_manager_issuer](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.config](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.gateway_api](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.ingress_configuration](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.otel](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.otel_svc](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.system_upgrade_controller](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.system_upgrade_controller_agent_plan](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.system_upgrade_controller_crds](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.system_upgrade_controller_ns](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.system_upgrade_controller_server_plan](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_cluster_role_binding_v1.oidc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_config_map_v1.dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_ingress_v1.monitoring_ingress](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1) | resource |
| [kubernetes_ingress_v1.oidc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1) | resource |
| [kubernetes_namespace_v1.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_namespace_v1.harmony](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_namespace_v1.istio_system](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_namespace_v1.kured](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_namespace_v1.monitoring](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.hcloud_ccm](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.hcloud_csi](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [local_file.ssh_private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.wait_for_api](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_cluster_ready](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_password.rke2_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.master_node_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [random_string.worker_node_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [tls_private_key.machines](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_domain"></a> [domain](#input\_domain) | Domain for the cluster | `string` | n/a | yes |
| <a name="input_hetzner_token"></a> [hetzner\_token](#input\_hetzner\_token) | Hetzner Cloud API Token | `string` | n/a | yes |
| <a name="input_additional_lb_service_ports"></a> [additional\_lb\_service\_ports](#input\_additional\_lb\_service\_ports) | Additional TCP ports to expose on the management load balancer (e.g. [8080, 8443]). | `list(number)` | `[]` | no |
| <a name="input_aws_access_key"></a> [aws\_access\_key](#input\_aws\_access\_key) | AWS access key for Route53 and cert-manager DNS-01 solver. If empty, uses default AWS credentials chain. | `string` | `""` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for the Route53 provider. | `string` | `"eu-central-1"` | no |
| <a name="input_aws_secret_key"></a> [aws\_secret\_key](#input\_aws\_secret\_key) | AWS secret key for Route53 and cert-manager DNS-01 solver. If empty, uses default AWS credentials chain. | `string` | `""` | no |
| <a name="input_cluster_configuration"></a> [cluster\_configuration](#input\_cluster\_configuration) | Define the cluster configuration. (See README.md for more information.) | <pre>object({<br/>    hcloud_controller = optional(object({<br/>      version    = optional(string, "1.19.0")<br/>      preinstall = optional(bool, true)<br/>    }), {})<br/>    monitoring_stack = optional(object({<br/>      kube_prom_stack_version = optional(string, "81.0.1")<br/>      loki_stack_version      = optional(string, "2.9.10")<br/>      preinstall              = optional(bool, false)<br/>    }), {})<br/>    istio_service_mesh = optional(object({<br/>      version    = optional(string, "1.18.0")<br/>      preinstall = optional(bool, false)<br/>    }), {})<br/>    tracing_stack = optional(object({<br/>      tempo_version = optional(string, "1.3.1")<br/>      preinstall    = optional(bool, false)<br/>    }), {})<br/>    hcloud_csi = optional(object({<br/>      version               = optional(string, "2.12.0")<br/>      preinstall            = optional(bool, true)<br/>      default_storage_class = optional(bool, true)<br/>      reclaim_policy        = optional(string, "Delete")<br/>    }), {})<br/>    cert_manager = optional(object({<br/>      version                         = optional(string, "v1.19.3")<br/>      preinstall                      = optional(bool, true)<br/>      use_for_preinstalled_components = optional(bool, true)<br/>    }), {})<br/>    self_maintenance = optional(object({<br/>      system_upgrade_controller_version = optional(string, "0.13.4")<br/>      kured_version                     = optional(string, "3.0.1")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_cluster_issuer_name"></a> [cluster\_issuer\_name](#input\_cluster\_issuer\_name) | Name of the cert-manager ClusterIssuer. Defaults to 'harmony-letsencrypt-global' for compatibility with openedx-k8s-harmony Tutor plugin (hardcoded in k8s-services patch). | `string` | `"harmony-letsencrypt-global"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Short name for the cluster, used as prefix for all resources (servers, LB, network, firewall). | `string` | `"rke2"` | no |
| <a name="input_create_dns_record"></a> [create\_dns\_record](#input\_create\_dns\_record) | Defines whether a Route53 DNS record should be created for the cluster load balancer. | `bool` | `false` | no |
| <a name="input_enable_auto_kubernetes_updates"></a> [enable\_auto\_kubernetes\_updates](#input\_enable\_auto\_kubernetes\_updates) | Whether the kubernetes version should be updated automatically. | `bool` | `true` | no |
| <a name="input_enable_auto_os_updates"></a> [enable\_auto\_os\_updates](#input\_enable\_auto\_os\_updates) | Whether the OS should be updated automatically. | `bool` | `true` | no |
| <a name="input_enable_nginx_modsecurity_waf"></a> [enable\_nginx\_modsecurity\_waf](#input\_enable\_nginx\_modsecurity\_waf) | Defines whether the nginx modsecurity waf should be enabled. | `bool` | `false` | no |
| <a name="input_enable_secrets_encryption"></a> [enable\_secrets\_encryption](#input\_enable\_secrets\_encryption) | Enable Kubernetes Secrets encryption at rest in etcd. Strongly recommended for production. | `bool` | `true` | no |
| <a name="input_enable_ssh_on_lb"></a> [enable\_ssh\_on\_lb](#input\_enable\_ssh\_on\_lb) | Expose SSH (port 22) via the management load balancer. Disabled by default for security. Enable only for debugging or when bastion access is unavailable. | `bool` | `false` | no |
| <a name="input_expose_kubernetes_metrics"></a> [expose\_kubernetes\_metrics](#input\_expose\_kubernetes\_metrics) | Defines whether the kubernetes metrics (scheduler, etcd, ...) should be exposed on the nodes. | `bool` | `false` | no |
| <a name="input_expose_oidc_issuer_url"></a> [expose\_oidc\_issuer\_url](#input\_expose\_oidc\_issuer\_url) | Expose the OIDC discovery endpoint via Ingress at oidc.<domain>. Enables anonymous-auth and custom service-account-issuer on the API server. | `bool` | `false` | no |
| <a name="input_gateway_api_version"></a> [gateway\_api\_version](#input\_gateway\_api\_version) | The version of the gateway api to install. | `string` | `"v0.7.1"` | no |
| <a name="input_generate_ssh_key_file"></a> [generate\_ssh\_key\_file](#input\_generate\_ssh\_key\_file) | Defines whether the generated ssh key should be stored as local file. | `bool` | `false` | no |
| <a name="input_harmony"></a> [harmony](#input\_harmony) | Harmony chart (openedx-k8s-harmony) integration.<br/>- enabled: Deploy Harmony chart via Helm. Disables RKE2 built-in ingress-nginx and routes HTTP/HTTPS through the management LB.<br/>- version: Chart version to install. Empty string means latest.<br/>- extra\_values: Additional values.yaml content (list of YAML strings) merged after infrastructure defaults. | <pre>object({<br/>    enabled      = optional(bool, true)<br/>    version      = optional(string, "")<br/>    extra_values = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_k8s_api_allowed_cidrs"></a> [k8s\_api\_allowed\_cidrs](#input\_k8s\_api\_allowed\_cidrs) | CIDR blocks allowed to access the Kubernetes API (port 6443). Defaults to open for module usability; restrict in production. | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_lb_location"></a> [lb\_location](#input\_lb\_location) | Define the location for the management cluster loadbalancer. | `string` | `"hel1"` | no |
| <a name="input_letsencrypt_issuer"></a> [letsencrypt\_issuer](#input\_letsencrypt\_issuer) | The email to send notifications regarding let's encrypt. | `string` | `""` | no |
| <a name="input_master_node_count"></a> [master\_node\_count](#input\_master\_node\_count) | Number of master (control-plane) nodes. Use 1 for non-HA or >= 3 for HA (etcd quorum). | `number` | `1` | no |
| <a name="input_master_node_image"></a> [master\_node\_image](#input\_master\_node\_image) | Define the image for the master nodes. | `string` | `"ubuntu-24.04"` | no |
| <a name="input_master_node_server_type"></a> [master\_node\_server\_type](#input\_master\_node\_server\_type) | Hetzner Cloud server type for control-plane nodes (e.g. 'cx22', 'cx32', 'cx42'). | `string` | `"cx23"` | no |
| <a name="input_network_address"></a> [network\_address](#input\_network\_address) | Define the network for the cluster in CIDR format (e.g., '10.0.0.0/16'). | `string` | `"10.0.0.0/16"` | no |
| <a name="input_network_zone"></a> [network\_zone](#input\_network\_zone) | Define the network location for the cluster. | `string` | `"eu-central"` | no |
| <a name="input_nginx_ingress_proxy_body_size"></a> [nginx\_ingress\_proxy\_body\_size](#input\_nginx\_ingress\_proxy\_body\_size) | Default max request body size for the nginx ingress controller. Set to 100m for Harmony/Open edX compatibility (course uploads). | `string` | `"100m"` | no |
| <a name="input_node_locations"></a> [node\_locations](#input\_node\_locations) | Define the location in which nodes will be deployed. (Must be in the same network zone.) | `list(string)` | <pre>[<br/>  "hel1",<br/>  "nbg1",<br/>  "fsn1"<br/>]</pre> | no |
| <a name="input_preinstall_gateway_api_crds"></a> [preinstall\_gateway\_api\_crds](#input\_preinstall\_gateway\_api\_crds) | Whether the gateway api crds should be preinstalled. | `bool` | `false` | no |
| <a name="input_rke2_cni"></a> [rke2\_cni](#input\_rke2\_cni) | CNI type to use for the cluster | `string` | `"canal"` | no |
| <a name="input_rke2_version"></a> [rke2\_version](#input\_rke2\_version) | RKE2 version to install (e.g. 'v1.30.2+rke2r1'). Empty string installs the latest stable release. | `string` | `""` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | The Route53 hosted zone ID. (Required if create\_dns\_record is true.) | `string` | `""` | no |
| <a name="input_ssh_allowed_cidrs"></a> [ssh\_allowed\_cidrs](#input\_ssh\_allowed\_cidrs) | CIDR blocks allowed to access SSH (port 22) on cluster nodes. Defaults to open because the module's provisioners require SSH to master[0]. Restrict to your runner/bastion CIDR in production (e.g. ['1.2.3.4/32']). | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_subnet_address"></a> [subnet\_address](#input\_subnet\_address) | Define the subnet for cluster nodes in CIDR format. Must be within network\_address range. | `string` | `"10.0.1.0/24"` | no |
| <a name="input_worker_node_count"></a> [worker\_node\_count](#input\_worker\_node\_count) | Number of dedicated worker nodes. Set to 0 to schedule workloads on control-plane nodes. | `number` | `0` | no |
| <a name="input_worker_node_image"></a> [worker\_node\_image](#input\_worker\_node\_image) | Define the image for the worker nodes. | `string` | `"ubuntu-24.04"` | no |
| <a name="input_worker_node_server_type"></a> [worker\_node\_server\_type](#input\_worker\_node\_server\_type) | Hetzner Cloud server type for worker nodes (e.g. 'cx22', 'cx32', 'cx42'). | `string` | `"cx23"` | no |
### Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_cert"></a> [client\_cert](#output\_client\_cert) | The client certificate for cluster authentication (PEM-encoded) |
| <a name="output_client_key"></a> [client\_key](#output\_client\_key) | The client private key for cluster authentication (PEM-encoded) |
| <a name="output_cluster_ca"></a> [cluster\_ca](#output\_cluster\_ca) | The cluster CA certificate (PEM-encoded) |
| <a name="output_cluster_host"></a> [cluster\_host](#output\_cluster\_host) | The Kubernetes API server endpoint URL |
| <a name="output_cluster_issuer_name"></a> [cluster\_issuer\_name](#output\_cluster\_issuer\_name) | The name of the cert-manager ClusterIssuer created by this module |
| <a name="output_cluster_master_nodes_ipv4"></a> [cluster\_master\_nodes\_ipv4](#output\_cluster\_master\_nodes\_ipv4) | The public IPv4 addresses of all master (control plane) nodes |
| <a name="output_cluster_worker_nodes_ipv4"></a> [cluster\_worker\_nodes\_ipv4](#output\_cluster\_worker\_nodes\_ipv4) | The public IPv4 addresses of all worker nodes |
| <a name="output_control_plane_lb_ipv4"></a> [control\_plane\_lb\_ipv4](#output\_control\_plane\_lb\_ipv4) | The IPv4 address of the control-plane load balancer (K8s API, registration) |
| <a name="output_harmony_infrastructure_values"></a> [harmony\_infrastructure\_values](#output\_harmony\_infrastructure\_values) | Infrastructure-specific Harmony values applied by this module (for reference only — already merged into the Helm release) |
| <a name="output_ingress_lb_ipv4"></a> [ingress\_lb\_ipv4](#output\_ingress\_lb\_ipv4) | The IPv4 address of the ingress load balancer (HTTP/HTTPS). Null when harmony is disabled. |
| <a name="output_kube_config"></a> [kube\_config](#output\_kube\_config) | The full kubeconfig file content for cluster access |
| <a name="output_management_network_id"></a> [management\_network\_id](#output\_management\_network\_id) | The ID of the Hetzner Cloud private network |
| <a name="output_management_network_name"></a> [management\_network\_name](#output\_management\_network\_name) | The name of the Hetzner Cloud private network |
<!-- END_TF_DOCS -->
