# Packer — RKE2 Base Image Builder

Builds a golden Hetzner Cloud snapshot with pre-installed packages and hardened kernel settings for RKE2 nodes.

## What Gets Pre-installed

- **open-iscsi** — Longhorn prerequisite
- **nfs-common** — Longhorn NFS backup support
- **curl, jq** — RKE2 installer and health checks
- **Kernel modules** — `iscsi_tcp`, `br_netfilter`, `overlay`
- **sysctl tuning** — IP forwarding, bridge-nf-call, inotify limits

## Usage

```bash
# Set your Hetzner Cloud API token
export PKR_VAR_hcloud_token="your-token-here"

# Initialize Packer plugins
packer init rke2-base.pkr.hcl

# Build the image
packer build rke2-base.pkr.hcl

# Use a custom base image or location
packer build -var base_image=ubuntu-24.04 -var location=nbg1 rke2-base.pkr.hcl
```

## After Building

Reference the snapshot in your Terraform deployment:

```hcl
module "rke2" {
  source = "../../"  # or git reference

  master_node_image = "rke2-base-1234567890"  # snapshot name
  worker_node_image = "rke2-base-1234567890"
  # ...
}
```

## Directory Structure

```
packer/
├── rke2-base.pkr.hcl          # Packer template
├── scripts/
│   └── install-ansible.sh      # Bootstrap Ansible on build instance
├── ansible/
│   ├── playbook.yml            # Main playbook
│   └── roles/
│       └── rke2-base/
│           ├── defaults/main.yml   # Default variables
│           └── tasks/main.yml      # Installation tasks
└── README.md                   # This file
```
