# Common Deployment Guide

## Prerequisites

All examples in this repository require:

- **[OpenTofu](https://opentofu.org/)** >= 1.5.0 or Terraform >= 1.5.0
- **Hetzner Cloud account** + API token ([Get token](https://console.hetzner.cloud/))
- **Domain name** for the cluster

Additional requirements for specific configurations:
- **AWS account** with Route53 hosted zone (for DNS automation and TLS certificates)
- **Python 3.12+** (for Open edX deployments with Tutor)

## Standard Deployment Steps

### 1. Configure Variables

Copy the example variables file and edit with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values
```

### 2. Initialize OpenTofu

Initialize the Terraform/OpenTofu providers:

```bash
tofu init
```

### 3. Plan Deployment

Review the planned infrastructure changes:

```bash
tofu plan
```

### 4. Apply Configuration

Deploy the infrastructure:

```bash
tofu apply
```

### 5. Access the Cluster

Extract the kubeconfig and verify cluster access:

```bash
# Save kubeconfig
tofu output -raw kubeconfig > ~/.kube/config
chmod 600 ~/.kube/config

# Verify cluster is accessible
kubectl get nodes
```

## Cleanup

To destroy all created infrastructure:

```bash
tofu destroy
```

**⚠️ Warning**: This will permanently delete all cluster resources and data.

## Next Steps

See the specific example README for:
- Example-specific configuration options
- Additional setup steps
- Architecture details
- Troubleshooting guidance
