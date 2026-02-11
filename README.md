<div align="center" width="100%">
    <h2>hcloud rke2 module</h2>
    <p>Simple and fast creation of a rke2 Kubernetes cluster on Hetzner Cloud.</p>
    <a target="_blank" href="https://github.com/mbilan1/terraform-hcloud-rke2/releases"><img src="https://img.shields.io/github/v/release/mbilan1/terraform-hcloud-rke2?display_name=tag" /></a>
    <a target="_blank" href="https://github.com/mbilan1/terraform-hcloud-rke2/commits/main"><img src="https://img.shields.io/github/last-commit/mbilan1/terraform-hcloud-rke2" /></a>
</div>

> **This is a fork of [wenzel-felix/terraform-hcloud-rke2](https://github.com/wenzel-felix/terraform-hcloud-rke2).**
> The original module is available on the [Terraform Registry](https://registry.terraform.io/modules/wenzel-felix/rke2/hcloud/latest).

## Changes from upstream

This fork includes the following improvements over the original module:

### Reliability
- **Cluster readiness check** — replaced `time_sleep` with a two-phase `null_resource` that polls `/readyz` and waits for all nodes to report `Ready` status before deploying workloads
- **Firewall attachment fix** — removed `hcloud_firewall_attachment` (only one per firewall allowed by the provider); firewall is now bound via `firewall_ids` on each `hcloud_server`, fixing `tofu destroy` race conditions
- **cert-manager helm fix** — use `installCRDs` (correct for v1.13.x), increased timeout to 600s and `startupapicheck.timeout` to 5m
- **Load balancer health checks** — HTTP `/healthz` for K8s API (6443), TCP for SSH (22), RKE2 registration (9345), and custom ports

### Security
- **Firewall rules** — proper ingress rules for all required ports; internal-only access for etcd, kubelet, RKE2 registration, and NodePort ranges
- **Sensitive variables** — `sensitive = true` on `hetzner_token`, `cloudflare_token`, and all credential outputs
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
* (Optional) If you want any DNS related configurations you need a doamin setup with cloudflare and a corresponding API key

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
