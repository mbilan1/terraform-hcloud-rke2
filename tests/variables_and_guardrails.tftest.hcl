# ──────────────────────────────────────────────────────────────────────────────
# Unit Tests: Variable Validations & Cross-Variable Guardrails
#
# DECISION: All tests use command = plan with mock_provider to run offline
#           without cloud credentials, at zero cost, in ~2 seconds.
# Why: tofu test with mock providers evaluates validation and check blocks
#      during the plan phase. No real infrastructure is created.
# See: docs/ARCHITECTURE.md
# ──────────────────────────────────────────────────────────────────────────────

# ── Mock all 11 providers so plan runs without credentials ──────────────────
#
# WORKAROUND: Hetzner provider uses numeric IDs internally, but Terraform
# resource `id` attribute is always a string. With mock providers, the
# auto-generated string IDs (e.g. "72oy3AZL") cannot be coerced to numbers,
# causing plan failures. We override IDs with numeric strings that coerce
# correctly (e.g. "10001" → 10001).
# TODO: Remove mock_resource overrides if OpenTofu adds type-aware mock generation

mock_provider "hcloud" {
  mock_resource "hcloud_network" {
    defaults = {
      id = "10001"
    }
  }
  mock_resource "hcloud_network_subnet" {
    defaults = {
      id = "10002"
    }
  }
  mock_resource "hcloud_load_balancer" {
    defaults = {
      id   = "10003"
      ipv4 = "1.2.3.4"
    }
  }
  mock_resource "hcloud_server" {
    defaults = {
      id           = "10004"
      ipv4_address = "1.2.3.4"
    }
  }
  mock_resource "hcloud_ssh_key" {
    defaults = {
      id = "10005"
    }
  }
  mock_resource "hcloud_firewall" {
    defaults = {
      id = "10006"
    }
  }
  mock_data "hcloud_load_balancers" {
    defaults = {
      load_balancers = []
    }
  }
}

# WORKAROUND: remote_file mock must return empty content to avoid yamldecode()
# failure in locals.tf kubeconfig parsing. Empty string triggers the safe
# conditional branch: `content == "" ? "" : base64decode(yamldecode(...))`.
mock_provider "remote" {
  mock_data "remote_file" {
    defaults = {
      content = ""
    }
  }
}

mock_provider "aws" {}
mock_provider "kubectl" {}
mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "null" {}
mock_provider "random" {}
mock_provider "tls" {}
mock_provider "local" {}
mock_provider "http" {}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V01: Default values pass validation                                   ║
# ║  Verifies the module is valid with only required variables set.            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "defaults_pass_validation" {
  command = plan

  variables {
    hetzner_token = "mock-token-for-testing"
    domain        = "test.example.com"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V02: domain — must not be empty                                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "domain_rejects_empty_string" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = ""
  }

  expect_failures = [var.domain]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V03: master_node_count — rejects 2 (split-brain)                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "master_count_rejects_two" {
  command = plan

  variables {
    hetzner_token     = "mock-token"
    domain            = "test.example.com"
    master_node_count = 2
  }

  expect_failures = [var.master_node_count]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V04: master_node_count — accepts 1 (non-HA)                           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "master_count_accepts_one" {
  command = plan

  variables {
    hetzner_token     = "mock-token"
    domain            = "test.example.com"
    master_node_count = 1
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V05: master_node_count — accepts 3 (HA)                               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "master_count_accepts_three" {
  command = plan

  variables {
    hetzner_token     = "mock-token"
    domain            = "test.example.com"
    master_node_count = 3
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V06: master_node_count — accepts 5 (large HA)                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "master_count_accepts_five" {
  command = plan

  variables {
    hetzner_token     = "mock-token"
    domain            = "test.example.com"
    master_node_count = 5
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V07: cluster_name — rejects invalid characters                        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "cluster_name_rejects_uppercase" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    cluster_name  = "MyCluster"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_rejects_hyphens" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    cluster_name  = "my-cluster"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_rejects_too_long" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    cluster_name  = "aaaaabbbbbcccccddddde"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_accepts_valid" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    cluster_name  = "prod01"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V08: rke2_cni — rejects invalid value                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "rke2_cni_rejects_invalid" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    rke2_cni      = "flannel"
  }

  expect_failures = [var.rke2_cni]
}

run "rke2_cni_accepts_cilium" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    rke2_cni      = "cilium"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V09: additional_lb_service_ports — rejects out-of-range ports          ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "lb_ports_rejects_zero" {
  command = plan

  variables {
    hetzner_token               = "mock-token"
    domain                      = "test.example.com"
    additional_lb_service_ports = [0]
  }

  expect_failures = [var.additional_lb_service_ports]
}

run "lb_ports_rejects_too_large" {
  command = plan

  variables {
    hetzner_token               = "mock-token"
    domain                      = "test.example.com"
    additional_lb_service_ports = [65536]
  }

  expect_failures = [var.additional_lb_service_ports]
}

run "lb_ports_accepts_valid" {
  command = plan

  variables {
    hetzner_token               = "mock-token"
    domain                      = "test.example.com"
    additional_lb_service_ports = [8080, 8443]
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V10: network_address — rejects invalid CIDR                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "network_address_rejects_invalid" {
  command = plan

  variables {
    hetzner_token   = "mock-token"
    domain          = "test.example.com"
    network_address = "not-a-cidr"
  }

  expect_failures = [var.network_address]
}

run "network_address_accepts_valid" {
  command = plan

  variables {
    hetzner_token   = "mock-token"
    domain          = "test.example.com"
    network_address = "172.16.0.0/12"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V11: subnet_address — rejects invalid CIDR                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "subnet_address_rejects_invalid" {
  command = plan

  variables {
    hetzner_token  = "mock-token"
    domain         = "test.example.com"
    subnet_address = "999.999.999.0/24"
  }

  expect_failures = [var.subnet_address]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V12: cluster_configuration.hcloud_csi.reclaim_policy — enum            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "reclaim_policy_rejects_invalid" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    cluster_configuration = {
      hcloud_csi = {
        reclaim_policy = "Recycle"
      }
    }
  }

  expect_failures = [var.cluster_configuration]
}

run "reclaim_policy_accepts_retain" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    cluster_configuration = {
      hcloud_csi = {
        reclaim_policy = "Retain"
      }
    }
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V13a: ssh_allowed_cidrs — rejects invalid CIDR entries                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "ssh_cidrs_rejects_invalid" {
  command = plan

  variables {
    hetzner_token     = "mock-token"
    domain            = "test.example.com"
    ssh_allowed_cidrs = ["not-a-cidr"]
  }

  expect_failures = [var.ssh_allowed_cidrs]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-V13b: k8s_api_allowed_cidrs — rejects empty list                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "k8s_api_cidrs_rejects_empty" {
  command = plan

  variables {
    hetzner_token         = "mock-token"
    domain                = "test.example.com"
    k8s_api_allowed_cidrs = []
  }

  expect_failures = [var.k8s_api_allowed_cidrs]
}

run "k8s_api_cidrs_rejects_invalid" {
  command = plan

  variables {
    hetzner_token         = "mock-token"
    domain                = "test.example.com"
    k8s_api_allowed_cidrs = ["192.168.1.0/24", "garbage"]
  }

  expect_failures = [var.k8s_api_allowed_cidrs]
}

# ══════════════════════════════════════════════════════════════════════════════
# GUARDRAILS (cross-variable check blocks)
# ══════════════════════════════════════════════════════════════════════════════

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G01: aws_credentials_pair_consistency                                  ║
# ║  Only one of aws_access_key / aws_secret_key set → warning                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "aws_credentials_rejects_partial" {
  command = plan

  variables {
    hetzner_token  = "mock-token"
    domain         = "test.example.com"
    aws_access_key = "AKIAEXAMPLE"
    aws_secret_key = ""
  }

  expect_failures = [check.aws_credentials_pair_consistency]
}

run "aws_credentials_accepts_both_set" {
  command = plan

  variables {
    hetzner_token  = "mock-token"
    domain         = "test.example.com"
    aws_access_key = "AKIAEXAMPLE"
    aws_secret_key = "secretkey123"
  }
}

run "aws_credentials_accepts_both_empty" {
  command = plan

  variables {
    hetzner_token  = "mock-token"
    domain         = "test.example.com"
    aws_access_key = ""
    aws_secret_key = ""
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G02: letsencrypt_email_required_when_issuer_enabled                    ║
# ║  cert_manager with route53_zone_id but no email → warning                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "letsencrypt_email_required_with_route53" {
  command = plan

  variables {
    hetzner_token      = "mock-token"
    domain             = "test.example.com"
    route53_zone_id    = "Z1234567890"
    letsencrypt_issuer = ""
    aws_access_key     = "AKIAEXAMPLE"
    aws_secret_key     = "secretkey123"
  }

  expect_failures = [check.letsencrypt_email_required_when_issuer_enabled]
}

run "letsencrypt_email_passes_when_set" {
  command = plan

  variables {
    hetzner_token      = "mock-token"
    domain             = "test.example.com"
    route53_zone_id    = "Z1234567890"
    letsencrypt_issuer = "admin@example.com"
    aws_access_key     = "AKIAEXAMPLE"
    aws_secret_key     = "secretkey123"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G03: system_upgrade_controller_version_format                          ║
# ║  Version must be numeric semver (no 'v' prefix)                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "suc_version_rejects_v_prefix" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    cluster_configuration = {
      self_maintenance = {
        system_upgrade_controller_version = "v0.13.4"
      }
    }
  }

  expect_failures = [check.system_upgrade_controller_version_format]
}

run "suc_version_accepts_valid" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    cluster_configuration = {
      self_maintenance = {
        system_upgrade_controller_version = "0.13.4"
      }
    }
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G04: remote_manifest_downloads_required_for_selected_features          ║
# ║  auto k8s updates ON + downloads OFF → warning                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "remote_downloads_required_for_k8s_updates" {
  command = plan

  variables {
    hetzner_token                   = "mock-token"
    domain                          = "test.example.com"
    enable_auto_kubernetes_updates  = true
    allow_remote_manifest_downloads = false
  }

  expect_failures = [check.remote_manifest_downloads_required_for_selected_features]
}

run "remote_downloads_passes_when_enabled" {
  command = plan

  variables {
    hetzner_token                   = "mock-token"
    domain                          = "test.example.com"
    enable_auto_kubernetes_updates  = true
    allow_remote_manifest_downloads = true
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G05: rke2_version_format_when_pinned                                   ║
# ║  Pinned version must match v1.31.6+rke2r1 format                           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "rke2_version_rejects_bad_format" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    rke2_version  = "1.31.6"
  }

  expect_failures = [check.rke2_version_format_when_pinned]
}

run "rke2_version_accepts_empty" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    rke2_version  = ""
  }
}

run "rke2_version_accepts_valid_format" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    rke2_version  = "v1.31.6+rke2r1"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G06: auto_updates_require_ha (cluster-selfmaintenance.tf)              ║
# ║  Auto-updates ON + single master → warning                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "auto_updates_warns_on_single_master" {
  command = plan

  variables {
    hetzner_token          = "mock-token"
    domain                 = "test.example.com"
    master_node_count      = 1
    enable_auto_os_updates = true
  }

  expect_failures = [check.auto_updates_require_ha]
}

run "auto_updates_passes_on_ha" {
  command = plan

  variables {
    hetzner_token          = "mock-token"
    domain                 = "test.example.com"
    master_node_count      = 3
    enable_auto_os_updates = true
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G07: harmony_requires_cert_manager (cluster-harmony.tf)                ║
# ║  Harmony ON + cert_manager OFF → warning                                   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "harmony_requires_cert_manager" {
  command = plan

  variables {
    hetzner_token = "mock-token"
    domain        = "test.example.com"
    harmony = {
      enabled = true
    }
    cluster_configuration = {
      cert_manager = {
        preinstall = false
      }
    }
  }

  expect_failures = [check.harmony_requires_cert_manager]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G08: harmony_requires_workers_for_lb (cluster-harmony.tf)              ║
# ║  Harmony ON + 0 workers → warning                                          ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
run "harmony_requires_workers" {
  command = plan

  variables {
    hetzner_token     = "mock-token"
    domain            = "test.example.com"
    worker_node_count = 0
    harmony = {
      enabled = true
    }
  }

  expect_failures = [check.harmony_requires_workers_for_lb]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  UT-G09 / UT-G10: dns_requires_zone_id / dns_requires_harmony_ingress     ║
# ║                                                                            ║
# ║  COMPROMISE: These two check blocks cannot be tested with mock_provider.   ║
# ║  Why: Setting create_dns_record=true with invalid inputs triggers both      ║
# ║  the check block WARNING and a downstream provider schema error on          ║
# ║  aws_route53_record.wildcard (zone_id required, ingress[0] index OOB).     ║
# ║  Provider schema errors are not catchable via expect_failures — only        ║
# ║  checkable objects (variables, check blocks, postconditions) can be         ║
# ║  expected. The uncatchable schema error causes test failure regardless.     ║
# ║  These check blocks are validated in real deployments and via code review.  ║
# ║  TODO: Add when OpenTofu supports expect_failures for provider errors.     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
