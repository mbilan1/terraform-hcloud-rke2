# Tests

Unit tests for the `terraform-hcloud-rke2` module using OpenTofu's native `tofu test` framework with `mock_provider`.

## Quick Start

```bash
cd /path/to/terraform-hcloud-rke2
tofu init
tofu test
```

All tests run **offline** with mocked providers — no cloud credentials, no infrastructure, no cost.

## Test Files

| File | Tests | Scope |
|------|:-----:|-------|
| `variables_and_guardrails.tftest.hcl` | 39 | Variable validations (10 blocks) + cross-variable guardrails (8 of 10 check blocks) |
| `conditional_logic.tftest.hcl` | 22 | Resource count assertions for all conditional branches (harmony, masters, workers, LB, SSH, cert-manager, HCCM, CSI, kured) |
| `examples.tftest.hcl` | 2 | Full-stack configuration patterns (minimal, OpenEdX-Tutor) |
| **Total** | **63** | |

> **Note:** 2 DNS check blocks (`dns_requires_zone_id`, `dns_requires_harmony_ingress`) cannot be tested
> with mock providers — the downstream `aws_route53_record` triggers uncatchable provider schema  
> errors. See the comment in `variables_and_guardrails.tftest.hcl` for details.

## Architecture

### Test Strategy: Plan-Only with Mock Providers

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  .tftest.hcl │────▶│  tofu test   │────▶│  mock_provider   │
│  (test cases)│     │  command=plan│     │  (all 11 provs)  │
└─────────────┘     └──────────────┘     └─────────────────┘
                           │
                    ┌──────┴──────┐
                    │  Validates  │
                    ├─────────────┤
                    │ • Variables │
                    │ • Checks   │
                    │ • Counts   │
                    │ • Outputs  │
                    └─────────────┘
```

All 11 providers are mocked at the file level:

```hcl
mock_provider "hcloud" {}
mock_provider "remote" {}
mock_provider "aws" {}
mock_provider "kubectl" {}
mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "null" {}
mock_provider "random" {}
mock_provider "tls" {}
mock_provider "local" {}
mock_provider "http" {}
```

### Test Categories

#### 1. Variable Validations (UT-V*)

Tests that each `validation {}` block in `variables.tf` correctly accepts valid input and rejects invalid input.

Covers: `domain`, `master_node_count`, `cluster_name`, `rke2_cni`, `additional_lb_service_ports`, `network_address`, `subnet_address`, `cluster_configuration.hcloud_csi.reclaim_policy`, `ssh_allowed_cidrs`, `k8s_api_allowed_cidrs`.

#### 2. Guardrails / Check Blocks (UT-G*)

Tests that `check {}` blocks produce warnings for inconsistent variable combinations.

Covers: `aws_credentials_pair_consistency`, `letsencrypt_email_required_when_issuer_enabled`, `system_upgrade_controller_version_format`, `remote_manifest_downloads_required_for_selected_features`, `rke2_version_format_when_pinned`, `auto_updates_require_ha`, `harmony_requires_cert_manager`, `harmony_requires_workers_for_lb`, `dns_requires_zone_id`, `dns_requires_harmony_ingress`.

#### 3. Conditional Logic (UT-C*)

Tests that conditional `count` and `for_each` expressions produce expected resource counts for all major feature toggles.

Covers: Harmony on/off, master counts (1/3/5), worker counts (0/N), SSH on LB, cert-manager, HCCM, CSI, SSH key file, DNS, ingress LB targets, kured/self-maintenance.

#### 4. Example Validation (UT-E*)

Tests that example configurations in `examples/` produce valid plans.

## Coverage Traceability

| Feature | Variables | Guardrail | Conditional | Total |
|---------|:---------:|:---------:|:-----------:|:-----:|
| Domain validation | 1 | — | — | 1 |
| Master count (etcd quorum) | 3 | — | 2 | 5 |
| Cluster name format | 4 | — | — | 4 |
| CNI selection | 2 | — | — | 2 |
| LB ports | 3 | — | — | 3 |
| Network CIDR | 2 | — | — | 2 |
| Subnet CIDR | 1 | — | — | 1 |
| CSI reclaim policy | 2 | — | 1 | 3 |
| SSH CIDRs | 1 | — | — | 1 |
| K8s API CIDRs | 2 | — | — | 2 |
| AWS credentials | — | 3 | — | 3 |
| Let's Encrypt email | — | 2 | — | 2 |
| SUC version format | — | 2 | — | 2 |
| Remote manifests | — | 2 | — | 2 |
| RKE2 version format | — | 3 | — | 3 |
| Auto-updates + HA | — | 2 | 2 | 4 |
| Harmony | — | 2 | 4 | 6 |
| Workers | — | — | 2 | 2 |
| SSH on LB | — | — | 2 | 2 |
| cert-manager | — | — | 2 | 2 |
| HCCM | — | — | 1 | 1 |
| SSH key file | — | — | 2 | 2 |
| DNS | — | 2 | 1 | 3 |
| Ingress LB targets | — | — | 1 | 1 |
| Control-plane LB | — | — | 1 | 1 |
| Output: ingress_lb_ipv4 | — | — | 1 | 1 |
| Example: minimal | — | — | — | 1 |

## CI Integration

Tests run automatically in CI via `.github/workflows/lint.yml` — the `tofu-tests` job:

```yaml
- name: Run OpenTofu Tests
  run: tofu test
```

The job is triggered on every push/PR when `*.tftest.hcl` files exist.

## Adding New Tests

1. Choose the appropriate file based on what you're testing
2. Follow the naming convention: `UT-V*` for variables, `UT-G*` for guardrails, `UT-C*` for conditional logic, `UT-E*` for examples
3. Always set required variables (`hetzner_token`, `domain`) in every `run` block
4. Use `expect_failures` for negative tests (validation rejections, check block warnings)
5. Use `assert {}` for positive tests (resource count, output values)
6. Run `tofu test` locally before pushing
