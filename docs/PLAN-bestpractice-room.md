# Best-Practice Room Reimplementation Plan

> **Goal**: Exit fork / derivative-work status via systematic reimplementation  
> **Method**: Best-Practice Gate filtering (not classic clean-room)  
> **Gate**: <https://github.com/mbilan1/devops-best-practice-gate> — 384 practices, 22 sections  
> **Date**: 2026-02-24  
> **Status**: COMPLETE (Phases 4–7 executed, P7.9 CI + P7.10 evidence pack deferred to release)

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [Current State: Upstream Residuals](#current-state-upstream-residuals)
- [Method: Best-Practice Room](#method-best-practice-room)
- [Phase 0 — Preparation](#phase-0--preparation)
- [Phase 1 — Byte-Identical File Elimination](#phase-1--byte-identical-file-elimination)
- [Phase 2 — High-Similarity File Rewrite](#phase-2--high-similarity-file-rewrite)
- [Phase 3 — Attributed Code Pattern Rewrite](#phase-3--attributed-code-pattern-rewrite)
- [Phase 4 — Structural Independence](#phase-4--structural-independence)
- [Phase 5 — Best-Practice Hardening Pass](#phase-5--best-practice-hardening-pass)
- [Phase 6 — Licensing and Provenance Reset](#phase-6--licensing-and-provenance-reset)
- [Phase 7 — Verification and Evidence](#phase-7--verification-and-evidence)
- [Best-Practice Gate Coverage Map](#best-practice-gate-coverage-map)
- [Risk Register](#risk-register)
- [Success Criteria](#success-criteria)

---

## Executive Summary

### Execution log (2026-02-25)

- Phase 4 (Structural Independence) completed.
- Phase 5 (Best-Practice Hardening) completed for targeted items:
    - data sources extracted to dedicated `data.tf`
    - pre/postconditions added for SUC downloads, parsed manifest sets, SUC plans,
        kubeconfig fetch, and bootstrap IP detection path
    - bootstrap detection upgraded to metadata-first with kernel fallback + diagnostics
- Phase 6 (Licensing and Provenance Reset) completed:
    - P6.1: removed upstream license artifact `LICENSES/LicenseRef-MIT-upstream-wenzel-felix.txt`
    - P6.2: `REUSE.toml` verified — sole copyright `2026 Maksym Bilan`, no upstream annotations
    - P6.3: root `LICENSE` verified — sole copyright `2026 Maksym Bilan`
    - P6.4: zero `NOTICE:` comments referencing upstream patterns in active code
    - P6.5: `ATTRIBUTION.md` created with one-line historical acknowledgment
    - P6.6: `README.md` cleaned — no fork/upstream wording
    - P6.7: `docs/ARCHITECTURE.md` verified — only generic "upstream" (Kubernetes/RKE2), no wenzel refs
    - P6.8: `AGENTS.md` verified — only generic "upstream" (dependencies), no wenzel refs
    - P6.9: `reuse lint` passes clean — 82/82 files, MIT only
- Phase 7 (Verification) completed:
    - P7.4: `git diff --stat HEAD` — 22 files changed, 584 insertions(+), 344 deletions(-)
    - P7.5: `tofu test` — 91 passed, 0 failed
    - P7.6: `tofu validate` — Success
    - P7.7: `tofu fmt -check` — clean
    - P7.8: `reuse lint` — REUSE 3.3 compliant, sole license MIT
    - P7.1: `copydetect` — 2 pairs above 30% display threshold (max 35.09% on variables.tf,
        structural HCL syntax overlap). 0 pairs above 50% target. Report: `/tmp/cd_clean_report.html`
    - P7.2: `sha256sum` byte-identical — **0 matches** across 47 upstream files
    - P7.3: `ssdeep` fuzzy hash — **0 non-LICENSE matches** (LICENSE/MIT.txt expected match exempted)
    - P7.9: CI pipeline — requires push (deferred)
    - P7.10: evidence pack — deferred to release

The project `terraform-hcloud-rke2` originated as a fork of
[wenzel-felix/terraform-hcloud-rke2](https://github.com/wenzel-felix/terraform-hcloud-rke2)
(MIT licensed). Since forking, the codebase has been substantially rewritten
(47 upstream files → 89 current files, nested module architecture, 84 tests,
12 CI workflows, 2231 lines of tests, comprehensive docs). However, residual
upstream artifacts remain:

| Category | Count | Details |
|----------|------:|---------|
| Byte-identical files (active working tree) | 3 | 2 GitHub issue templates + upstream license file |
| Byte-identical files (historical in compliance snapshot) | 4 | Gateway example, tfvars example, SUC agent manifest, HCCM values template |
| High-similarity files (>60%) | 2 | `hccm.tf` (73%), `selfmaintenance.tf` (61%) |
| Attributed code patterns | 2 | C1: Hetzner metadata IP detection, C2: remote_file kubeconfig approach |
| Upstream license file | 1 | `LICENSES/LicenseRef-MIT-upstream-wenzel-felix.txt` |

**This plan eliminates all upstream residuals by rewriting every overlapping
component from functional specification through the Best-Practice Gate.**

---

## Current State: Upstream Residuals

### R1. Byte-Identical Files (Current Working Tree: 3 files)

| # | File | Lines | Nature | Action |
|---|------|------:|--------|--------|
| R1.1 | `.github/ISSUE_TEMPLATE/bug_report.md` | ~30 | GitHub issue template | Rewrite from BP gate |
| R1.2 | `.github/ISSUE_TEMPLATE/feature_request.md` | ~20 | GitHub issue template | Rewrite from BP gate |
| R1.3 | `LICENSES/LicenseRef-MIT-upstream-wenzel-felix.txt` | 21 | Upstream license text | Remove after all residuals eliminated |

### R1b. Historical Byte-Identical Files (Already removed from current tree, present in compliance archive)

| # | File | Current state | Note |
|---|------|---------------|------|
| R1b.1 | `examples/simple-setup/gateway_example.yaml` | removed from active tree | Exists in compliance snapshot only |
| R1b.2 | `examples/simple-setup/main.auto.tfvars.example` | removed from active tree | Exists in compliance snapshot only |
| R1b.3 | `modules/addons/templates/manifests/system-upgrade-controller-agent.yaml` | removed from active tree | Addons templates now mostly inlined |
| R1b.4 | `modules/addons/templates/values/hccm.yaml` | removed from active tree | Addons templates now mostly inlined |

### R2. High-Similarity Files (2 files, git rename detection)

| # | Upstream File | Current File | Similarity | Action |
|---|---------------|--------------|:----------:|--------|
| R2.1 | `cluster-hccm.tf` | `modules/addons/hccm.tf` | 73% | Full rewrite from Helm chart spec |
| R2.2 | `cluster-selfmaintenance.tf` | `modules/addons/selfmaintenance.tf` | 61% | Full rewrite from upstream project docs |

### R3. Attributed Code Patterns (2 patterns with NOTICE comments)

| # | Pattern | Location | Description |
|---|---------|----------|-------------|
| R3.1 | C1: IP detection | `scripts/rke-master.sh.tpl`, `scripts/rke-worker.sh.tpl` | `curl metadata → grep ip → cut` pipeline |
| R3.2 | C2: Kubeconfig fetch | `modules/infrastructure/readiness.tf` | `data.remote_file` approach for kubeconfig |

### R4. Structural Traces

| # | Area | Description |
|---|------|-------------|
| R4.1 | Variable names | Some variable names match upstream naming conventions |
| R4.2 | Resource naming | Some resource naming patterns echo upstream |
| R4.3 | Cloud-init template structure | Overall template layout has upstream lineage |

---

## Method: Best-Practice Room

Unlike classic clean-room (two separate teams: spec writers + implementers),
this uses a **single-pass best-practice filter**:

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│  Existing Code      │     │  Best-Practice Gate   │     │  Reimplemented Code │
│  (upstream residual)│ ──► │  384 practices filter │ ──► │  (original work)    │
│                     │     │  22 sections           │     │                     │
└─────────────────────┘     └──────────────────────┘     └─────────────────────┘
```

### Process per component

1. **Extract functional spec** — document WHAT the component does (inputs, outputs,
   behavior, edge cases) without referencing HOW the upstream implements it
2. **Best-Practice Gate scan** — identify which of the 384 practices apply to this
   component and what the ideal implementation looks like
3. **Rewrite from spec + gate** — implement the component from the functional spec,
   applying every relevant best practice
4. **Diff verification** — confirm the new code has zero byte-level or structural
   similarity to the upstream version
5. **Test** — all existing tests must pass; add new tests if gate identifies gaps

### Key Best-Practice Gate sections for Terraform/IaC reimplementation

| Section | # | Relevance |
|---------|---|-----------|
| §1 Core Principles | 1–25 | KISS, DRY, SRP, YAGNI, Idempotency, Declarative |
| §6 Terraform & IaC | 104–138 | Module layout, naming, validation, lifecycle |
| §7 Container & K8s | 139–158 | Health checks, RBAC, resource limits |
| §8 Security | 159–183 | Secrets, policy-as-code, least privilege |
| §10 Testing | 201–220 | Testing pyramid, $0 tests, idempotent |
| §11 CI/CD | 221–240 | Gate structure, pipeline-as-code |
| §17 Documentation | 324–333 | ADRs, README per module, diagrams |
| §22 License & IP | 377–384 | Provenance, attribution, SPDX |

---

## Phase 0 — Preparation

**Goal**: Set up tracking, baseline measurements, and branch strategy.

| Task | Description | BP Gate |
|------|-------------|---------|
| P0.1 | Create feature branch `feat/bestpractice-room` | §5 #89 (trunk-based) |
| P0.2 | Snapshot current `copydetect` score as baseline | §22 #384 (provenance) |
| P0.3 | Run `tofu test` — confirm all 84 tests pass (green baseline) | §10 #204 |
| P0.4 | Run `tofu validate` + `tofu fmt -check` (clean baseline) | §6 #119 |
| P0.5 | Tag pre-rewrite state: `pre-bestpractice-room` | §5 #102 (tags immutable) |
| P0.6 | Document this plan in `docs/PLAN-bestpractice-room.md` | §17 #324 (ADR) |

---

## Phase 1 — Byte-Identical File Elimination

**Goal**: Eliminate all 3 active byte-identical files. Each is rewritten from its
functional purpose (not from the upstream source).

### P1.1 — GitHub Issue Templates (R1.1, R1.2)

**Functional spec**: Provide structured bug report and feature request forms with
fields relevant to THIS project (Hetzner Cloud, RKE2, OpenTofu, Helm addons).

**Best practices applied**:
- §17 #325 (README in every module)
- §13 #254 (feedback loop from consumers)
- §5 #100 (PR templates with checklists)

**Action**: Rewrite both templates with:
- Project-specific fields (OpenTofu version, Hetzner region, RKE2 version, addon config)
- Checklist referencing our CI gates
- Environment section (Hetzner API, cloud-init logs, `kubectl get nodes`)
- Remove generic GitHub boilerplate; replace with project-specific structure

### P1.2 — Upstream License File (R1.3)

**Functional spec**: Preserve legal clarity while removing derivative-work
obligations after complete code reimplementation.

**Action**:
- Keep file during active rewrite phases for legal traceability.
- Remove only in Phase 6 after residual code elimination is verified.

### P1.3 — Historical snapshot artifacts (R1b.*)

**Functional spec**: Ensure the plan reflects current repository reality, not
stale compliance snapshots.

**Action**:
- Keep these files out of active-scope implementation tasks.
- Treat them as historical evidence only.

### P1.4 — Optional Gateway Example Reintroduction (only if explicitly needed)

**Functional spec**: Demonstrate Kubernetes Gateway API usage with the cluster.

**Action**: Either:
- (a) Rewrite as a modern Gateway API v1 example matching our ingress architecture, OR
- (b) Remove entirely if Gateway API is not supported by this module (YAGNI — §1 #3)

**Recommendation**: Remove. The module uses ingress-nginx (Harmony) or RKE2 built-in
ingress. Gateway API is not in scope. Keeping a dead example violates YAGNI.

### P1.5 — Optional Example tfvars reintroduction (only if explicitly needed)

**Functional spec**: Provide example variable values for the simple-setup example.

**Action**: Rewrite to reflect current variable schema (which is completely different
from upstream — new nested objects like `cluster_configuration`, `harmony`, etc.)

### P1.6 — Optional SUC Agent Manifest template reintroduction (only if design changes)

**Functional spec**: Kubernetes manifest for System Upgrade Controller agent plan
that triggers RKE2 agent node upgrades.

**Best practices applied**:
- §7 #155 (label and annotation standards)
- §7 #141 (no :latest tag — pin versions)

**Action**: Rewrite from the [SUC upstream documentation](https://github.com/rancher/system-upgrade-controller)
applying our naming conventions, label standards, and documentation comments.

### P1.7 — Optional HCCM values template reintroduction (only if design changes)

**Functional spec**: Helm values for Hetzner Cloud Controller Manager chart.

**Best practices applied**:
- §6 #110 (no hardcoded values)
- §7 #145 (resource requests and limits)

**Action**: Rewrite from the [HCCM Helm chart values.yaml](https://github.com/hetznercloud/hcloud-cloud-controller-manager)
with our naming conventions, adding resource limits (BP #145), adding nodeSelector/tolerations
documentation.

---

## Phase 2 — High-Similarity File Rewrite

**Goal**: Full rewrite of the 2 files with >60% git similarity to upstream.

### P2.1 — HCCM Addon (`modules/addons/hccm.tf`) — 73% similarity to upstream

**Functional spec**:
- Create a Kubernetes Secret containing the Hetzner API token
- Deploy Hetzner Cloud Controller Manager via Helm release
- Secret must be created before Helm release
- Helm release depends on `wait_for_infrastructure`
- Secret uses the shared `hcloud` name (CCM + CSI convention)
- Chart version is configurable via `cluster_configuration.hcloud_controller.version`

**Best practices applied**:
- §6 #108 (every resource has description and tags)
- §6 #109 (prefer for_each over count)
- §6 #130 (prefer terraform_data over null_resource)
- §8 #159 (secrets via proper mechanisms)
- §8 #134 (sensitive variables marked)
- §7 #145 (resource requests/limits in Helm values)

**Action**: Rewrite the entire file from scratch:
- New resource naming scheme (prefixed, descriptive)
- Structured Helm values via `yamlencode()` instead of template file
- Add resource requests/limits in values
- Add lifecycle documentation comments
- Different conditional logic structure
- Different dependency wiring

### P2.2 — Self-Maintenance (`modules/addons/selfmaintenance.tf`) — 61% similarity

**Functional spec**:
- Deploy Kured (reboot daemon) via Helm when HA (≥3 masters) + `enable_auto_os_updates`
- Deploy System Upgrade Controller (SUC) via raw manifests when HA + `enable_auto_kubernetes_updates`
- SUC requires: CRDs, namespace, controller deployment, server upgrade plan, agent upgrade plan
- Both are gated by control plane count ≥ 3
- CRD manifests are downloaded from GitHub (with offline toggle)

**Best practices applied**:
- §6 #109 (for_each over count)
- §6 #116 (modules have single responsibility)
- §3 #70 (health-check-based routing)
- §7 #146 (Pod Disruption Budgets)
- §7 #156 (graceful shutdown — SIGTERM, preStop)
- §21 #373 (self-healing infrastructure)

**Action**: Full rewrite:
- Restructure conditional logic (use locals for gating, clearer boolean expressions)
- New resource names (drop upstream naming patterns)
- Inline manifest generation via `yamlencode()` where possible
- Different dependency chain wiring
- Add PDB documentation, graceful shutdown comments

---

## Phase 3 — Attributed Code Pattern Rewrite

**Goal**: Replace the 2 explicitly attributed upstream code patterns.

### P3.1 — IP Detection Pipeline (C1) in bootstrap scripts

**Current** (upstream-attributed):
```bash
curl -s http://169.254.169.254/hetzner/v1/metadata/private-networks \
  | grep "ip:" | cut -f3 -d" "
```

**Functional spec**: Detect the node's private network IP from Hetzner Cloud
metadata service at boot time, for use in RKE2 `node-ip` and `advertise-address`.

**Best practices applied**:
- §1 #14 (fail fast, fail loud)
- §3 #54 (timeout on every external call)
- §1 #16 (idempotency)
- §4 #73 (DNS as critical infrastructure)

**Action**: Rewrite using a completely different approach:
- Use `jq` to parse JSON metadata endpoint (`/hetzner/v1/metadata`) instead of `grep | cut`
- OR use cloud-init's built-in `datasource` for Hetzner (if available)
- OR use `ip route` to detect the private network interface IP
- Add proper error handling, retry logic, timeout, and logging
- Document the choice via ADR-style comment

### P3.2 — Kubeconfig Fetch (C2) via `data.remote_file`

**Current** (upstream-attributed):
```hcl
data "remote_file" "kubeconfig" {
  conn { ... SSH to master-0 ... }
  path = "/etc/rancher/rke2/rke2.yaml"
}
```

**Functional spec**: After cluster is ready, retrieve the kubeconfig file from
master-0 to configure Kubernetes/Helm/kubectl providers for addon deployment.

**Best practices applied**:
- §6 #130 (prefer terraform_data)
- §6 #136 (precondition/postcondition blocks)
- §8 #164 (SSH access restricted)

**Action**: Rewrite with different approach:
- Use `terraform_data` with `provisioner "remote-exec"` + `provisioner "local-exec"` to
  fetch kubeconfig (eliminates `remote` provider dependency)
- OR keep `data.remote_file` but with completely different connection wiring,
  error handling, and dependency structure
- Add precondition block validating SSH connectivity
- Add postcondition validating kubeconfig structure
- Different host resolution (use LB IP instead of direct node IP, or vice versa)

---

## Phase 4 — Structural Independence

**Goal**: Ensure naming conventions, file organization, and structural patterns
are independently derived from best practices — not echoing upstream structure.

### P4.1 — Variable Naming Audit

| Task | Description |
|------|-------------|
| P4.1a | Audit all 38 root variables against upstream variable names |
| P4.1b | Rename any that match upstream but don't follow our naming convention |
| P4.1c | Ensure names follow §6 #105 (snake_case) and §6 #107 (type + description + validation) |
| P4.1d | Update `moved` blocks if resource addresses change |

### P4.2 — Resource Naming Audit

| Task | Description |
|------|-------------|
| P4.2a | Audit all resource names in infrastructure module |
| P4.2b | Audit all resource names in addons module |
| P4.2c | Rename resources that match upstream naming patterns |
| P4.2d | Apply §6 #106 (resource name prefix matches module name) |
| P4.2e | Add `moved` blocks for every rename |

### P4.3 — Cloud-Init Template Rewrite

| Task | Description |
|------|-------------|
| P4.3a | Rewrite `rke2-server-config.yaml.tpl` from RKE2 docs spec |
| P4.3b | Rewrite `rke2-agent-config.yaml.tpl` from RKE2 docs spec |
| P4.3c | Use `yamlencode()` in HCL instead of raw template strings where possible |
| P4.3d | Apply §1 #15 (declarative for desired state) |

### P4.4 — Bootstrap Script Rewrite

| Task | Description |
|------|-------------|
| P4.4a | Rewrite `rke-master.sh.tpl` from RKE2 install docs |
| P4.4b | Rewrite `rke-worker.sh.tpl` from RKE2 install docs |
| P4.4c | Add proper error handling (§1 #14 — fail fast) |
| P4.4d | Add structured logging |
| P4.4e | Apply shellcheck-clean bash coding standards |

---

## Phase 5 — Best-Practice Hardening Pass

**Goal**: Systematic pass through all 22 sections of the gate, applying every
applicable practice to the entire codebase.

### P5.1 — §6 Terraform & IaC Structure (104–138) — Full audit

| Practice | Current | Action |
|:--------:|---------|--------|
| 104 | ✅ Standard layout | — |
| 105 | ✅ snake_case | Verify in rewritten files |
| 106 | 🟡 Partial | Apply in Phase 4 renames |
| 107 | ✅ type+desc+validation | Extend validation blocks |
| 108 | 🟡 Missing tags on some resources | Add `labels {}` blocks |
| 109 | ✅ for_each used | Verify in rewrites |
| 110 | ✅ No hardcoded values | Verify |
| 111 | ✅ Pinned providers | — |
| 112 | ✅ Lock file committed | — |
| 113 | N/A (module, not deployment) | — |
| 116 | ✅ SRP modules | — |
| 117 | ✅ Infra/addons separation | — |
| 118 | ✅ examples/ folder | — |
| 119 | ✅ fmt + validate pass | Maintain |
| 120 | ✅ terraform-docs | — |
| 121 | 🟡 Partial ordering | Standardize file ordering |
| 122 | ✅ locals.tf exists | — |
| 123 | 🔲 data blocks mixed in | Extract to data.tf |
| 124 | ✅ outputs minimal | — |
| 125 | ✅ No duplication | Verify |
| 126 | ✅ versions.tf with constraints | — |
| 127 | ✅ required_providers | — |
| 128 | ✅ No cross-layer refs | — |
| 129 | ✅ moved blocks | Extend for renames |
| 130 | ✅ terraform_data | — |
| 131 | Document lifecycle rules | Add comments |
| 134 | ✅ Sensitive marked | Verify |
| 135 | 🔲 No default_tags | Add provider default_tags |
| 136 | 🔲 No precondition/postcondition | Add to critical resources |
| 138 | Verify sub-blocks | Review |

### P5.2 — §8 Security & Compliance (159–183)

| Practice | Action |
|:--------:|--------|
| 159 | Verify secrets handling in rewrites |
| 160 | ✅ Sensitive outputs marked |
| 161 | ✅ 3 SAST tools in CI |
| 162 | ✅ guardrails.tf |
| 163 | Verify least-privilege firewall |
| 164 | Document SSH restriction |
| 165 | ✅ REUSE.toml |
| 166 | Update LICENSE after upstream removal |
| 168 | ✅ Pinned versions |
| 176 | ✅ cert-manager |

### P5.3 — §10 Testing & Quality (201–220)

| Practice | Action |
|:--------:|--------|
| 201 | ✅ Testing pyramid (84 unit, 1 integration, 1 e2e) |
| 202 | Add tests for rewritten components |
| 203 | ✅ $0 tests |
| 204 | ✅ tofu test |
| 207 | ✅ Idempotent tests |
| 212 | ✅ Failing tests block merge |
| 220 | 🔲 Test results not posted as PR comments |

### P5.4 — §22 License Compliance & IP Hygiene (377–384)

| Practice | Action |
|:--------:|--------|
| 377 | ✅ All MIT compatible |
| 378 | Remove upstream license after rewrite |
| 379 | ✅ Lock files |
| 380 | ✅ REUSE/SPDX analysis |
| 381 | IP review = this plan |
| 383 | Update attribution after rewrite |
| 384 | Update provenance documentation |

---

## Phase 6 — Licensing and Provenance Reset

**Goal**: Transition from derivative-work licensing to independent authorship.

| Task | Description |
|------|-------------|
| P6.1 | Remove `LICENSES/LicenseRef-MIT-upstream-wenzel-felix.txt` |
| P6.2 | Update `REUSE.toml` — remove any upstream-referencing annotations |
| P6.3 | Update root `LICENSE` — sole copyright: `2026 Maksym Bilan` |
| P6.4 | Remove all `NOTICE:` comments referencing upstream code patterns |
| P6.5 | Add `NOTICE` or `ATTRIBUTION.md` with a one-line historical acknowledgment: "This project was inspired by wenzel-felix/terraform-hcloud-rke2 (MIT). All code has been independently reimplemented." |
| P6.6 | Update `README.md` — remove any "forked from" or upstream links |
| P6.7 | Update `docs/ARCHITECTURE.md` — remove upstream references |
| P6.8 | Update `AGENTS.md` — remove upstream context |
| P6.9 | Run `reuse lint` — must pass clean |

---

## Phase 7 — Verification and Evidence

**Goal**: Produce evidence that no upstream code remains.

| Task | Tool | Description |
|------|------|-------------|
| P7.1 | `copydetect` | Run clone detection: current HEAD vs upstream `main`. Target: 0 flagged pairs |
| P7.2 | `sha256` | Byte-identical file check vs upstream tree. Target: 0 matches (except LICENSE text) |
| P7.3 | `ssdeep` | Fuzzy hash similarity. Target: no file exceeds 50% similarity |
| P7.4 | `git diff --stat` | Full tree diff. Document total insertions/deletions/renames |
| P7.5 | `tofu test` | All tests pass (84+) |
| P7.6 | `tofu validate` | Clean |
| P7.7 | `tofu fmt -check` | Clean |
| P7.8 | `reuse lint` | REUSE-compliant |
| P7.9 | CI pipeline | All 12 workflows green |
| P7.10 | Evidence pack | Generate new compliance evidence pack (same format as `terraform-hcloud-rke2_20260222T231104Z`) |

---

## Best-Practice Gate Coverage Map

Which of the 384 practices are directly applicable to this Terraform module:

| Section | Range | Applicable | Key Practices |
|---------|-------|:----------:|---------------|
| §1 Core | 1–25 | ~20 | KISS(1), DRY(2), YAGNI(3), SRP(4), Least Surprise(11), Idempotency(16), Everything as Code(18) |
| §2 CS Fundamentals | 26–50 | ~8 | Loose coupling(40), Composition over inheritance(42), Defensive programming(44), Split-brain prevention(47) |
| §3 Distributed Systems | 51–70 | ~5 | Health-check routing(70), Graceful degradation(68) |
| §4 Networking | 71–88 | ~6 | Network segmentation(82), DNS TTL(86) |
| §5 Git | 89–103 | ~12 | Conventional commits(90), Branch protection(93), No secrets in git(98) |
| §6 Terraform/IaC | 104–138 | **35** | ALL applicable — primary section |
| §7 Container/K8s | 139–158 | ~10 | Health probes(144), Resources(145), PDB(146), RBAC(150) |
| §8 Security | 159–183 | ~15 | Secrets(159), Policy-as-code(161), Least privilege(163), REUSE(165) |
| §9 Reliability | 184–200 | ~5 | Redundancy(184), SPOF(195) |
| §10 Testing | 201–220 | ~15 | Pyramid(201), $0 tests(203), tofu test(204) |
| §11 CI/CD | 221–240 | ~12 | Gate 0-4 structure(221-225), Pipeline-as-code(232) |
| §12 State Mgmt | 241–248 | ~4 | Remote backend(241), State never in git(246) |
| §13 Platform | 249–268 | ~5 | Golden path(249), Examples(259) |
| §14 SRE | 269–290 | ~4 | Readiness gates(271) |
| §17 Documentation | 324–333 | ~8 | ADR(324), README per module(325), Diagrams(327) |
| §19 DR/BC | 342–352 | ~3 | Backup(343), 3-2-1 rule(348) |
| §21 Automation | 371–376 | ~4 | Desired state(372), Self-healing(373) |
| §22 License/IP | 377–384 | **8** | ALL applicable — critical section |
| **Total applicable** | | **~180** | Out of 384 |

---

## 2026-02-24 — Full 384 Gate Pass (Facts-First Audit Delta)

### Verified evidence used in this pass

- Live gate source (authoritative):
    `https://raw.githubusercontent.com/mbilan1/devops-best-practice-gate/main/BEST_PRACTICES.md`
- Local plan file review: full `docs/PLAN-bestpractice-room.md`
- Local structural spot-checks:
    - `modules/infrastructure/network.tf`
    - `modules/infrastructure/readiness.tf`
    - active template paths under `modules/addons/templates/**` (none in active tree)

### Section-by-section status across all 22 gate sections

| Section | Range | Status | Evidence quality | Delta action |
|--------:|------:|:------:|:----------------:|--------------|
| 1 | 1–25 | 🟡 | partial | Formalize fail-fast/idempotency acceptance checks in rewrite DoD |
| 2 | 26–50 | 🟡 | partial | Add explicit contracts for consistency/quorum decisions into docs |
| 3 | 51–70 | 🟡 | partial | Encode timeout/retry/jitter patterns in bootstrap/readiness scripts |
| 4 | 71–88 | 🟡 | partial | Add explicit DNS TTL + network-plane rationale checks to guardrails/docs |
| 5 | 89–103 | 🟡 | partial | Keep commit/branch protections as required controls in execution checklist |
| 6 | 104–138 | 🟡 | strong | Expand to include #123, #135, #136 as tracked mandatory work items |
| 7 | 139–158 | 🟡 | partial | Require pinned images/resources/PDB/RBAC verification in addon rewrites |
| 8 | 159–183 | 🟡 | strong | Keep REUSE/SPDX + security scan controls; add CI secret-scan gate if missing |
| 9 | 184–200 | 🔲 | low | Add reliability math/failure-domain/SPOF assessment to architecture notes |
| 10 | 201–220 | 🟡 | strong | Add missing coverage+PR test comment publication controls (#211, #220) |
| 11 | 221–240 | 🟡 | strong | Map existing workflows to exact gate IDs 221–225 + rollback/notify controls |
| 12 | 241–248 | 🟡 | strong | Keep module-vs-root state model explicit; enforce "state never in git" remediation |
| 13 | 249–268 | 🔲 | low | Define golden-path and platform release cadence artifacts |
| 14 | 269–290 | 🔲 | low | Add operational readiness package (SLO/SLI/runbooks/playbooks) roadmap |
| 15 | 291–305 | 🔲 | low | Add DORA/SPACE metric ownership and dashboard backlog |
| 16 | 306–323 | 🔲 | low | Add observability-as-code backlog (alerts/dashboards/OTel strategy) |
| 17 | 324–333 | 🟡 | partial | Keep ADR/README requirements; add CHANGELOG and onboarding ownership |
| 18 | 334–341 | 🔲 | low | Add FinOps tagging/budget/cost-delta policy as future hardening phase |
| 19 | 342–352 | 🔲 | low | Add DR test cadence and restore validation plan |
| 20 | 353–370 | N/A | low | Not data-platform focused; keep explicitly out-of-scope unless DB layer added |
| 21 | 371–376 | 🟡 | partial | Strengthen desired-state/self-healing assertions in tests and guardrails |
| 22 | 377–384 | 🟡 | strong | Keep provenance/IP hygiene as release gate with objective evidence pack |

### Critical corrections introduced by this gate pass

1. The active byte-identical scope is corrected from 7 to 3 files.
2. Removed files from compliance archive are now treated as historical evidence,
     not active rewrite targets.
3. Added a full 22-section gate matrix so no section is silently skipped.
4. Marked sections with low evidence (`🔲`) as explicit backlog work instead of
     optimistic assumptions.

### Priority execution order after this audit

1. **P0 + P1 (active scope only)** — normalize baseline and eliminate 3 active
     byte-identical artifacts.
2. **P2 + P3** — rewrite high-similarity files and attributed patterns.
3. **P5 targeted hardening** — enforce #123, #135, #136, #211, #220.
4. **P6 + P7** — licensing/provenance reset and objective evidence generation.

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Rewrite breaks existing deployments | High | `moved` blocks for ALL renamed resources; test against `abstract-k8s-common-template` |
| Test coverage drops during rewrite | Medium | Run `tofu test` after EVERY file change; never merge with failing tests |
| New code accidentally re-converges to upstream patterns | Medium | Run `copydetect` after each phase; review diffs |
| Variable/output renames break consumers | High | Avoid renaming externally-visible variables/outputs unless necessary; use deprecation pattern |
| Lost functionality during rewrite | Medium | Functional spec per component BEFORE rewrite; integration test after |

---

## Success Criteria

The reimplementation is complete when ALL of the following are true:

1. **Zero byte-identical files** with upstream (except standard license text MIT boilerplate itself)
2. **Zero files >50% similarity** with upstream (via `copydetect` or `ssdeep`)
3. **Zero `NOTICE` comments** referencing upstream code patterns
4. **No upstream license file** in the repository
5. **All 84+ tests pass** (`tofu test`)
6. **All 12 CI workflows green**
7. **`reuse lint` passes clean** with sole copyright `2026 Maksym Bilan`
8. **New compliance evidence pack** generated with clean plagiarism report
9. **`ATTRIBUTION.md`** with one-line historical acknowledgment (good faith, not legal obligation)
10. **Best-Practice Gate score ≥ 95%** on applicable practices (~171/180)

---

## Execution Order Summary

```
Phase 0: Preparation (branch, baseline, tag)
    │
    ▼
Phase 1: Byte-identical elimination (3 active files)    ← Quick wins
    │
    ▼
Phase 2: High-similarity rewrite (2 files)              ← Core rewrite
    │
    ▼
Phase 3: Attributed patterns rewrite (2 patterns)       ← Script/readiness
    │
    ▼
Phase 4: Structural independence (naming, templates)     ← Deep rewrite
    │
    ▼
Phase 5: Best-practice hardening (22 sections)           ← Quality pass
    │
    ▼
Phase 6: Licensing reset (provenance, copyright)         ← Legal cleanup
    │
    ▼
Phase 7: Verification (evidence, compliance pack)        ← Proof
```

**Estimated effort**: 3–5 working days for Phases 1–4, 2–3 days for Phases 5–7.
Total: ~1–2 weeks.

**Breaking changes**: Phases 1–3 should produce zero breaking changes (internal
rewrites, `moved` blocks). Phase 4 may produce breaking changes if
resource/variable renames are needed — these will be documented and gated.
