# charts/ — GitOps-Ready Addon Deployment

> **These Helm charts are NOT managed by Terraform.**
> Terraform provisions infrastructure (L3); this directory manages
> Kubernetes workloads (L4) via Helmfile, ArgoCD, or Flux.

## Architecture

```
Terraform (L3)                     GitOps / Helmfile (L4)
┌─────────────────────┐           ┌──────────────────────────┐
│ Servers, LBs, DNS   │           │ cert-manager             │
│ Network, Firewall   │──────────►│ Longhorn                 │
│ Cloud-init (HCCM)   │ kubeconfig│ Kured + SUC              │
│ SSH keys            │           │ Harmony (Open edX)       │
└─────────────────────┘           │ Ingress configuration    │
                                  └──────────────────────────┘
```

HCCM (Hetzner Cloud Controller Manager) deploys at bootstrap via RKE2
HelmChart manifests in cloud-init — it is the only chart managed by
the infrastructure layer (chicken-egg: nodes need CCM to reach Ready).

## Quick Start

```bash
# Install Helmfile (https://helmfile.readthedocs.io/)
# Ensure KUBECONFIG points to your cluster

# Review what will be deployed
helmfile -f helmfile.yaml diff

# Deploy all addons
helmfile -f helmfile.yaml apply
```

## Directory Structure

```
charts/
├── helmfile.yaml              # Declarative release definitions
├── cert-manager/
│   └── values.yaml            # cert-manager Helm values
├── longhorn/
│   └── values.yaml            # Longhorn distributed storage values
├── kured/
│   └── values.yaml            # Kured reboot daemon values
├── system-upgrade-controller/
│   ├── values.yaml            # SUC (if Helm chart available)
│   └── manifests/             # Raw manifests for SUC + upgrade plans
│       ├── server-plan.yaml
│       └── agent-plan.yaml
├── harmony/
│   └── values.yaml            # OpenEdX Harmony values
└── ingress/
    └── helmchartconfig.yaml   # RKE2 built-in ingress tuning (non-Harmony)
```

## Deployment Order

Addons have dependencies. Deploy in this order (Helmfile handles this
automatically via `needs:`):

1. **cert-manager** — CRDs and controller (other charts reference ClusterIssuers)
2. **Longhorn** — distributed storage (PVCs depend on StorageClass)
3. **Kured** — reboot daemon (independent, but after storage)
4. **SUC** — System Upgrade Controller + plans (independent)
5. **Harmony** — Open edX platform (depends on cert-manager + storage)

## Migration from Terraform-Managed Addons

If upgrading from a version where Terraform managed addons:

```bash
# 1. Import existing Helm releases into Helmfile state
#    (Helmfile detects existing releases automatically)

# 2. Remove addon resources from Terraform state
tofu state rm 'module.addons.helm_release.cloud_controller["primary"]'
tofu state rm 'module.addons.helm_release.certificate_manager["cert-manager"]'
tofu state rm 'module.addons.helm_release.longhorn[0]'
tofu state rm 'module.addons.helm_release.reboot_daemon["kured"]'
tofu state rm 'module.addons.helm_release.harmony["harmony"]'
# ... (see migration guide in docs/)

# 3. Apply Terraform (no addon changes)
tofu apply

# 4. Deploy via Helmfile
helmfile apply
```

## ArgoCD / Flux Integration

For GitOps operators, point your Application/Kustomization at the
individual chart directories. Each `values.yaml` is self-contained.

Example ArgoCD Application:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
spec:
  source:
    repoURL: https://charts.jetstack.io
    chart: cert-manager
    targetRevision: "v1.17.2"
    helm:
      valueFiles:
        - $values/charts/cert-manager/values.yaml
```
