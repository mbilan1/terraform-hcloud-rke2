# Simple Setup Example

Deploys a minimal HA RKE2 cluster on Hetzner Cloud: 3 control-plane nodes, 1 worker.

## Prerequisites

- OpenTofu >= 1.5
- Hetzner Cloud API token (`HCLOUD_TOKEN` env var or `hcloud_api_token` variable)

## Usage

```bash
tofu init
tofu plan
tofu apply
```

After provisioning, a `kubeconfig.yaml` file is written to the working directory:

```bash
export KUBECONFIG="$(pwd)/kubeconfig.yaml"
kubectl get nodes
```

## What This Example Deploys

- 3 master nodes (etcd quorum)
- 1 worker node
- Hetzner Cloud Controller Manager (HCCM)
- Hetzner CSI driver with default StorageClass
- cert-manager (ClusterIssuer-ready)
- RKE2 built-in ingress-nginx with ModSecurity WAF enabled
- Automatic Kubernetes upgrades via System Upgrade Controller

## Cleanup

```bash
tofu destroy
```