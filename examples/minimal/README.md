# Minimal RKE2 Cluster Example

Smallest viable cluster configuration — 1 master, 0 workers, all defaults.

## Prerequisites & Deployment

See [../../docs/COMMON_DEPLOYMENT.md](../../docs/COMMON_DEPLOYMENT.md) for standard deployment steps.

## Required Variables

| Variable | Description |
|----------|-------------|
| `hcloud_token` | Hetzner Cloud API token |
| `domain` | Cluster domain (default: `test.example.com`) |

## What Gets Created

- 1 control-plane node (cx23, Ubuntu 24.04)
- 1 control-plane load balancer (lb11)
- Private network + subnet
- Firewall
- SSH key pair
- HCCM, CSI driver, cert-manager (all defaults)

## Cost

~€15/month (1× cx23 + 1× lb11)
