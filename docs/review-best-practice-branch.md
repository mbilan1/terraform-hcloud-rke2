# Deep Review: `feat/bestpractice-room` Branch

**Reviewer:** Claude (AI)
**Date:** 2026-02-25
**Branch:** `feat/bestpractice-room` vs `master`
**Scope:** Full codebase — Terraform, Packer/Ansible, Helmfile, CI/CD, documentation

---

## Executive Summary

The branch makes a **major correct architectural decision**: removing all L4 addon
management from Terraform and delegating it to Helmfile (`charts/`). This eliminates
the fundamental coupling between infrastructure changes (servers, LBs, DNS) and
Helm chart updates. The addition of CIS Level 1 hardening via Packer/Ansible,
SECURITY.md, CHANGELOG.md, CODEOWNERS, PR template, and gitleaks scanning
represents genuine quality improvement.

**Net verdict:** Merge-ready after fixing items marked [BUG] and [SECURITY].
Items marked [QUALITY] and [DISCUSSION] can go into follow-up issues.

---

## Breakdown by Category

### ✅ What's Good (Significant Improvements)

| # | What | Why It Matters |
|---|------|----------------|
| G1 | L4 addons removed from Terraform (`modules/addons/` gone) | Correct separation of concerns. `tofu apply` no longer risks touching servers when a Helm value changes. |
| G2 | 23 `removed { lifecycle { destroy = false } }` blocks for state migration | Zero-destroy migration of running K8s resources. Requires OpenTofu ≥ 1.7.0 — correctly enforced. |
| G3 | `providers.tf` simplified from 11 to 5 providers | kubernetes/helm/kubectl/http removed. Eliminates the awkward "providers point to cluster during plan" problem. |
| G4 | `variables.tf` down from 593 to 413 lines (−380) | `cluster_configuration` now only holds `etcd_backup` (a genuine infrastructure concern). Cleaner public API. |
| G5 | `harmony` simplified from complex object to single `harmony_enabled: bool` | Infrastructure only needs to know whether to create the ingress LB and disable built-in ingress. Chart config belongs in `charts/harmony/values.yaml`. |
| G6 | `guardrails.tf` down from 15 to 5 check blocks | Removed addon-specific guardrails that no longer apply. Kept the 5 that guard infrastructure. |
| G7 | `cluster_ready` exported at root module | Downstream consumers (CI pipelines, GitOps) can gate on this before running Helmfile. |
| G8 | Packer CIS Level 1 hardening with `enable_cis_hardening` flag | Proper opt-in design. Ansible Galaxy `requirements.yml` for dependency management. Snapshot labels (`cis-hardened`, `cis-benchmark`) for image identification. |
| G9 | tfsec changed from soft-fail to hard-fail | Real blocking gate now. |
| G10 | `sast-gitleaks.yml` added to CI | Secrets detection at PR time. |
| G11 | SECURITY.md, CHANGELOG.md, CODEOWNERS, PR template | Basic OSS governance artefacts. |
| G12 | `required_version = ">= 1.7.0"` | Correctly bumped for `removed {}` block support. Was `>= 1.5.0`. |
| G13 | Bootstrap script: `detect_private_ipv4_metadata()` with kernel fallback + 300 s retry | Handles Hetzner's async private NIC attachment. Real improvement over `curl | grep`. |

---

### 🐛 Bugs / Defects

#### [BUG-1] `extra_lb_ports` description says "management load balancer" — code applies to ingress LB

**File:** `variables.tf:144`
```hcl
description = "Additional TCP ports to expose on the management load balancer..."
```
**Reality** (`modules/infrastructure/load_balancer.tf:267`):
```hcl
for_each = var.harmony_enabled ? toset([for p in var.extra_lb_ports : tostring(p)]) : toset([])
load_balancer_id = hcloud_load_balancer.ingress[0].id   # ← ingress LB, not CP LB
```

The ports are on the **ingress LB** (worker targets, ports 80/443/custom), not the
"management" control-plane LB. An operator trying to expose a custom management port
(e.g. Prometheus Node Exporter via the CP LB) would be confused.

**Fix options:**
- If the intent is to expose extra ports on the **ingress LB** → update the description.
- If the intent is the **CP LB** → move the `for_each` to the CP LB resources.

---

#### [BUG-2] AWS provider version constraint lost its upper bound

**File:** `providers.tf:37`

Before (master): `version = ">= 5.0.0, < 7.0.0"`
After (this branch): `version = ">= 5.0.0"`  ← **no upper bound**

The master branch had a documented reason for widening to `< 7.0.0`. This branch
silently dropped the ceiling entirely. A future AWS provider v7 with breaking changes
(e.g. resource removals, auth changes) would be pulled in automatically.

```hcl
# Suggested fix:
aws = {
  source  = "hashicorp/aws"
  version = ">= 5.0.0, < 7.0.0"
}
```

---

#### [BUG-3] `etcd_backup.description` silently dropped in infrastructure module

**File:** `variables.tf:69` (root) vs `modules/infrastructure/variables.tf:172`

Root `cluster_configuration.etcd_backup` has:
```hcl
description = optional(string, "")   # ← present in root type
```
Infrastructure module `etcd_backup` variable type does **not** include `description`:
```hcl
type = object({
  enabled               = bool
  schedule_cron         = string
  ...
  s3_bucket_lookup_type = string
  # description is NOT here
})
```

OpenTofu silently drops `description` during type conversion. This is not a runtime
bug (it's an intentional metadata field), but it creates confusion: an operator who
sets `description = "daily backups"` gets no error and no effect. A comment in
the infrastructure module's type definition would prevent future surprise.

---

#### [BUG-4] Helmfile `cert-manager` lacks `needs: [hccm]` — risk of scheduling Pending

**File:** `charts/helmfile.yaml:58-75`

The comment at the top correctly states "HCCM must be deployed FIRST after cluster
bootstrap" because nodes have `node.cloudprovider.kubernetes.io/uninitialized` taint
until HCCM clears it. Without HCCM, no pods can schedule.

Current `needs:` graph:
```
hccm      (no needs — first)
cert-manager (no needs — parallel with hccm by default)
longhorn  (needs: cert-manager)
harmony   (needs: cert-manager, longhorn)
```

If Helmfile deploys cert-manager in parallel with hccm, cert-manager pods remain
`Pending` until HCCM clears the taint. Helmfile may timeout on `cert-manager` sync.

```yaml
# Fix:
- name: cert-manager
  needs:
    - hccm          # ← add this
```

---

#### [BUG-5] Duplicate effective-location computation

**File:** `main.tf:19-20` AND `modules/infrastructure/main.tf:33-34`

Root module:
```hcl
effective_master_locations = length(var.master_node_locations) > 0 ? var.master_node_locations : var.node_locations
```
Infrastructure module receives `master_node_locations = local.effective_master_locations` (never empty)
and then re-applies the SAME fallback logic:
```hcl
effective_master_locations = length(var.master_node_locations) > 0 ? var.master_node_locations : var.node_locations
```

The inner computation is dead code — the outer always produces a non-empty list.
If the fallback logic ever needs to change, it must be changed in two places.
The infrastructure module's `node_locations` variable receives the same value as
`master_node_locations` in this state, making the fallback branch unreachable.

---

### 🔒 Security Issues

#### [SECURITY-1] CIS hardening re-enables root SSH — partially undoes CIS SSH hardening

**File:** `modules/infrastructure/scripts/rke-master.sh.tpl:17-27`

```bash
if grep -q '^PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null; then
  sed -i 's/^PermitRootLogin no$/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
  systemctl restart ssh || systemctl restart sshd || true
fi
```

**What happens:** CIS UBUNTU24-CIS rule 5.2.7 sets `PermitRootLogin no`. This
script immediately undoes it (to `prohibit-password`) so that Terraform's
`remote-exec` provisioners can SSH as root.

**Impact:**
- CIS-hardened images do NOT receive the CIS 5.2.7 SSH hardening benefit.
- The SSH daemon is restarted mid-bootstrap, which could race with cloud-init.
- The `prohibit-password` setting is acceptable (key-only root login), but it
  contradicts the security claim of CIS-hardened images.

The TODO is correct: implement a non-root provisioner user. Until then, the
SECURITY.md and packer README should explicitly document this limitation so
operators know their hardened images retain root key-based SSH access.

**Recommended action:** Add a warning to `packer/README.md`:
> **Note:** When using CIS-hardened images, the bootstrap script re-enables
> `PermitRootLogin prohibit-password` to allow Terraform provisioners to function.
> This is a known limitation. See TODO in `rke-master.sh.tpl`.

---

#### [SECURITY-2] `hccm/manifests/secret.yaml` contains a placeholder dummy token committed to git

**File:** `charts/hccm/manifests/secret.yaml:21-22`

```yaml
token: "Q0hBTkdFTUU="    # base64("CHANGEME")
network: "Q0hBTkdFTUU="  # base64("CHANGEME")
```

This is committed to the repository. While gitleaks won't flag a base64("CHANGEME")
string, it creates a dangerous pattern: operators may forget to replace it and
`kubectl apply -f hccm/manifests/` would create a real Secret with "CHANGEME" as
the Hetzner token. HCCM would then fail with auth errors, and nodes would stay
`NotReady` (taint not cleared). The failure mode is confusing.

**Recommended fix:** Use environment variable substitution via envsubst or Helmfile's
template engine rather than placeholder values in YAML:
```yaml
# charts/hccm/manifests/secret.yaml
token: "${HCLOUD_TOKEN_B64}"   # Set HCLOUD_TOKEN_B64 before helmfile sync
```
Or document prominently with a gitleaks rule exception and a pre-sync check script
that aborts if token == base64("CHANGEME").

---

#### [SECURITY-3] `health_check_urls` URL injection in shell script

**File:** `modules/infrastructure/readiness.tf:266`

```hcl
"URLS='${join(" ", var.health_check_urls)}'",
```

If a URL contains a space, single-quote, or shell metacharacter (e.g.
`https://example.com/path?a=1&b=2`), the shell variable assignment breaks.
The `&` is valid in URLs but a shell background operator. The validation only
checks for `^https?://` prefix.

**Fix:** Pass each URL as a separate shell argument, not a space-joined string:
```hcl
# Each URL as separate inline command
for u in var.health_check_urls :
  "CODE=$(curl -sk -o /dev/null -w '%%{http_code}' '${u}' || echo '000') ..."
```
Or join with a null delimiter and use `read -d` if portable shell (sh) is
required.

---

#### [SECURITY-4] Harmony chart unpinned in helmfile.yaml

**File:** `charts/helmfile.yaml:112`

```yaml
- name: harmony
  # version: ""  # Uncomment and pin when needed
```

This is the only chart without a version pin. An unpinned release pulls the
`latest` chart on every `helmfile sync`, which is non-reproducible and could
silently upgrade to a breaking version. Even if Harmony is optional, the
reference config should show a commented example version.

```yaml
version: "0.12.0"   # example — pin to a known-good release
```

---

### 🔍 Code Quality

#### [QUALITY-1] `master_node_server_type` description uses old Hetzner type names

**File:** `variables.tf:290`
```hcl
description = "Hetzner Cloud server type for control-plane nodes (e.g. 'cx22', 'cx32', 'cx42')."
```
Default is `"cx23"`. Hetzner renamed `cx22→cx23` in 2025 (acknowledged in packer
variable at line 46: "cx22 was renamed to cx23 by Hetzner in 2025"). The description
examples are stale. Same issue for `worker_node_server_type:408`.

```hcl
# Correct examples:
description = "Hetzner Cloud server type for control-plane nodes (e.g. 'cx23', 'cx33', 'cx43')."
```

---

#### [QUALITY-2] Packer `server_name` is hardcoded — parallel builds conflict

**File:** `packer/rke2-base.pkr.hcl:80`

```hcl
server_name = "packer-rke2-base"
```

If two Packer builds run in parallel (e.g., in CI with matrix builds for different
RKE2 versions), both try to create a server named `packer-rke2-base` and the second
fails with Hetzner's "name already in use" error.

```hcl
# Fix: include timestamp or random suffix
server_name = "packer-rke2-base-{{timestamp}}"
```

---

#### [QUALITY-3] `_conventions` local is dead code in infrastructure module

**File:** `modules/infrastructure/main.tf:52-73`

```hcl
_conventions = {
  roles  = { ... }
  ports  = { kube_api = 6443, rke2_register = 9345, ssh = 22 }
  labels = { bootstrap_key = "bootstrap", bootstrap_value = "true" }
}
```

No resource references `local._conventions.*`. This was documented as "reserved
for future refactors" in the earlier branch. In a best-practice branch, dead code
should be removed or converted to an actual shared reference.

---

#### [QUALITY-4] `node_locations` described as "(Deprecated)" but still primary fallback

**File:** `variables.tf:297`
```hcl
description = "(Deprecated) Fallback placement locations when master_node_locations/worker_node_locations are unset."
```

A "(Deprecated)" variable implies it will be removed in a future major version.
If that's the intent, add:
1. A `# TODO: Remove in v1.0.0` comment.
2. A `check {}` block warning when someone uses it (i.e., when
   `master_node_locations` and `worker_node_locations` are both empty).

If it's not actually going away, remove "(Deprecated)" from the description.

---

#### [QUALITY-5] SSH connection timeout equals inner script timeout — too tight

**File:** `modules/infrastructure/readiness.tf:83,143`

Both `wait_for_api` and `wait_for_cluster_ready` have:
- SSH connection `timeout = "15m"`
- Inner script max timeout = 600 s (10 min) + 300 s (5 min) = 15 min

If Phase 1 (API wait) runs to its full 600 s and Phase 2 (nodes ready) also runs
to 600 s, the total shell time is 1200 s = 20 min — exceeding the 15 min SSH
timeout. The connection would be forcibly closed before the diagnostic output is
printed.

```hcl
# Fix: increase SSH timeout to 25m (safe margin above max script time)
timeout = "25m"
```

---

#### [QUALITY-6] Helmfile missing Hetzner CSI driver — undocumented design decision

**File:** `charts/helmfile.yaml`

The old Terraform code had Hetzner CSI as the **default storage driver** with
Longhorn as experimental opt-in. The new Helmfile only includes Longhorn
(no CSI). This is a valid design decision (Longhorn is now primary), but it
should be documented:
- `charts/README.md` should state "Longhorn is the default storage driver;
  Hetzner CSI is not included by default."
- The README should note this is a breaking change for existing users who relied
  on Hetzner CSI as the default.

---

#### [QUALITY-7] `hcloud_network_zone` has no validation

**File:** `variables.tf:193-198`

```hcl
variable "hcloud_network_zone" {
  default = "eu-central"
  # no validation block
}
```

A typo (e.g., `eu_central` or `eu-west`) produces an obscure Hetzner API error
at apply time rather than a clear validation failure at plan time. Even a simple
allowlist check would help:

```hcl
validation {
  condition     = contains(["eu-central", "us-east", "ap-southeast"], var.hcloud_network_zone)
  error_message = "hcloud_network_zone must be one of: eu-central, us-east, ap-southeast."
}
```

---

### 💬 Discussion Points

#### [DISCUSSION-1] State migration requires `tofu apply` BEFORE running Helmfile

**Files:** `moved.tf:207-end`, `CHANGELOG.md`

The migration path requires:
1. Run `tofu apply` with the new code (processes `removed {}` blocks, drops addon
   state without destroying real resources).
2. Then run `helmfile sync` to take over addon management.

If an operator runs Helmfile FIRST (thinking "Helmfile now manages addons") and
THEN runs `tofu apply`, the `removed {}` blocks will try to remove resources from
state that Helmfile already owns. The order matters. This should be prominently
documented in the README migration guide.

---

#### [DISCUSSION-2] Packer `enable_cis_hardening` flag defaults to `false`

**File:** `packer/rke2-base.pkr.hcl:69-73`

The CIS hardening opt-in is good (avoid breaking changes). However, for a
"best-practice" module, consider whether the default should be `true` with
an opt-out for development environments, rather than opt-in for production.

Current UX: developer must explicitly set `enable_cis_hardening = true`.
Alternative: default `true`, provide `enable_cis_hardening = false` for dev.

This is a design discussion, not a bug.

---

#### [DISCUSSION-3] `charts/` are reference configs, not production manifests

**File:** `SECURITY.md:50`
> "Helm chart vulnerabilities in `charts/` (reference configs, not production manifests)"

This out-of-scope statement in SECURITY.md is important but easy to miss.
Operators may assume `charts/helmfile.yaml` is production-ready. Consider adding
a `charts/README.md` banner:
> ⚠️ These are reference configurations. Review and customize all values, especially
> secrets and version pins, before running in production.

(Actually `charts/README.md` does exist — verify it contains this warning.)

---

## Checklist Summary

| ID | Severity | Status |
|----|----------|--------|
| BUG-1 | Medium | ❌ Fix before merge: `extra_lb_ports` description mismatch |
| BUG-2 | Medium | ❌ Fix before merge: AWS provider upper bound dropped |
| BUG-3 | Low | ⚠️ Add comment: `etcd_backup.description` silently dropped |
| BUG-4 | Medium | ❌ Fix before merge: cert-manager missing `needs: [hccm]` |
| BUG-5 | Low | ⚠️ Refactor: duplicate location computation |
| SECURITY-1 | High | ❌ Document in packer README: root SSH re-enabled by bootstrap |
| SECURITY-2 | High | ❌ Fix before merge: CHANGEME placeholder in git-committed secret |
| SECURITY-3 | Low | ⚠️ Fix: URL injection in health_check_urls shell join |
| SECURITY-4 | Medium | ❌ Fix before merge: harmony chart unpinned in helmfile |
| QUALITY-1 | Low | ⚠️ Fix: stale server type names in description |
| QUALITY-2 | Medium | ⚠️ Fix: hardcoded Packer server name conflicts with parallel builds |
| QUALITY-3 | Low | ⚠️ Remove: dead `_conventions` local |
| QUALITY-4 | Low | ⚠️ Clarify: `node_locations` deprecation intent |
| QUALITY-5 | Low | ⚠️ Fix: SSH timeout too tight (15m = script max) |
| QUALITY-6 | Medium | ⚠️ Document: Longhorn replaces CSI as default storage driver |
| QUALITY-7 | Low | ⚠️ Add: validation for `hcloud_network_zone` |
| DISCUSSION-1 | Info | 📝 Document migration order in README |
| DISCUSSION-2 | Info | 📝 Consider CIS default flip |
| DISCUSSION-3 | Info | 📝 Verify charts/README.md has "reference only" warning |

**Legend:** ❌ Must fix before merge | ⚠️ Should fix in follow-up | 📝 Discussion

---

## Files Reviewed

- `main.tf`
- `variables.tf`
- `guardrails.tf`
- `providers.tf`
- `output.tf`
- `moved.tf`
- `modules/infrastructure/main.tf`
- `modules/infrastructure/variables.tf`
- `modules/infrastructure/outputs.tf`
- `modules/infrastructure/firewall.tf`
- `modules/infrastructure/load_balancer.tf`
- `modules/infrastructure/readiness.tf`
- `modules/infrastructure/cloudinit.tf`
- `modules/infrastructure/scripts/rke-master.sh.tpl`
- `charts/helmfile.yaml`
- `charts/hccm/values.yaml`
- `charts/hccm/manifests/secret.yaml`
- `charts/cert-manager/manifests/clusterissuer.yaml`
- `packer/rke2-base.pkr.hcl`
- `packer/ansible/roles/cis-hardening/defaults/main.yml`
- `SECURITY.md`
- `CHANGELOG.md`
- `AGENTS.md` (partial)
- `docs/ARCHITECTURE.md` (partial)
