# Operational Readiness Plan

> **Module**: `terraform-hcloud-rke2`
> **Status**: **Planning Phase** — operational strategy definition
> **Target**: Production-ready operational procedures
> **Last updated**: 2026-02-16

---

## Table of Contents

- [Overview](#overview)
- [Backup Strategy](#backup-strategy)
- [Storage Architecture](#storage-architecture)
- [Node Pool Configuration](#node-pool-configuration)
- [Scaling Strategy](#scaling-strategy)
- [Network Considerations](#network-considerations)
- [Operational Complexity Assessment](#operational-complexity-assessment)
- [Implementation Roadmap](#implementation-roadmap)
- [Open Questions](#open-questions)

---

## Overview

This document outlines the operational readiness strategy for production deployments of RKE2 clusters on Hetzner Cloud. It addresses backup and recovery, storage management, scaling, and operational complexity considerations.

### Key Operational Objectives

1. **Data Protection**: Multi-layer backup strategy for cluster state and persistent data
2. **Operational Simplicity**: Balance between robustness and operational overhead
3. **Cost Efficiency**: Optimize for EU hosting costs while maintaining reliability
4. **Scalability**: Support dynamic scaling for variable workloads (e.g., Open edX peak loads)
5. **Recovery Capability**: Define and validate RTO/RPO targets

---

## Backup Strategy

### Multi-Layer Backup Approach

The operational strategy implements a defense-in-depth backup approach with three complementary layers:

#### Layer 1: Cluster Configuration Backup (Velero)

**Tool**: [Velero](https://velero.io/)

**Purpose**: Kubernetes cluster state and resource configuration backup

**Coverage**:
- Kubernetes resources (Deployments, ConfigMaps, Secrets, PVCs, etc.)
- Namespace configurations
- RBAC policies
- Custom Resource Definitions (CRDs)

**Backup Targets**:
- S3-compatible object storage (Hetzner Object Storage or AWS S3)
- Retention: 30 days for daily backups, 90 days for weekly

**Advantages**:
- Native Kubernetes resource backup
- Supports pre/post-backup hooks
- Disaster recovery and cluster migration capabilities
- Well-established in CNCF ecosystem

**Limitations**:
- Does not handle volume data by default (requires volume snapshots or file-level backup)
- Requires additional configuration for persistent volume backup

#### Layer 2: Volume Data Backup (Kopia)

**Tool**: [Kopia](https://kopia.io/)

**Purpose**: File-level backup for persistent volume data

**Coverage**:
- Application data in persistent volumes
- Database dumps
- User-uploaded content
- Configuration files

**Backup Strategy**:
- Incremental backups with deduplication
- Encryption at rest
- Compression for storage efficiency
- Retention: 7 daily, 4 weekly, 12 monthly snapshots

**Integration Approach**:
- Deploy Kopia as DaemonSet on worker nodes
- Use Velero's restic integration OR run Kopia independently
- Schedule backups via CronJobs for database dumps

**Advantages**:
- Efficient deduplication reduces storage costs
- Fast incremental backups
- Cross-platform compatibility
- Strong encryption

**Considerations**:
- Adds operational complexity
- Requires monitoring and alerting setup
- Needs separate restore procedures

#### Layer 3: Infrastructure Snapshots

**Tool**: Hetzner Cloud Snapshots (via Hetzner CSI)

**Purpose**: Block-level volume snapshots for rapid recovery

**Coverage**:
- Persistent volume snapshots
- Boot disk snapshots (optional, for node recovery)

**Backup Strategy**:
- Automated snapshots via CSI driver
- Retention: 7 daily snapshots
- Scheduled via Kubernetes VolumeSnapshot resources

**Advantages**:
- Fast recovery (direct volume restore)
- Native Hetzner integration
- Cost-effective for short-term retention

**Limitations**:
- Tied to Hetzner infrastructure (no portability)
- Limited retention (cost increases with snapshot count)
- No cross-region backup capability

### Backup Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    RKE2 Cluster (Hetzner)                   │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Master     │  │   Worker     │  │   Worker     │     │
│  │    Node      │  │    Node      │  │    Node      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                 │                 │               │
│         │                 │                 │               │
│  ┌──────▼─────────────────▼─────────────────▼──────┐       │
│  │         Persistent Volumes (Hetzner CSI)        │       │
│  └──────┬──────────────────┬──────────────────┬────┘       │
│         │                  │                  │             │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          │                  │                  │
    ┌─────▼─────┐      ┌─────▼─────┐     ┌─────▼─────┐
    │  Velero   │      │   Kopia   │     │  Hetzner  │
    │  (K8s     │      │  (Volume  │     │   CSI     │
    │ Resources)│      │   Data)   │     │ Snapshots │
    └─────┬─────┘      └─────┬─────┘     └─────┬─────┘
          │                  │                  │
          │                  │                  │
    ┌─────▼──────────────────▼─────┐      ┌────▼─────┐
    │   Object Storage (S3)        │      │ Hetzner  │
    │ (Hetzner or AWS S3)          │      │  Cloud   │
    └──────────────────────────────┘      └──────────┘
```

### Operational Complexity Assessment

**Complexity Rating**: 6/10

**Justification**:
- **Layer 1 (Velero)**: Moderate complexity, well-documented, single deployment
- **Layer 2 (Kopia)**: Adds complexity through separate backup scheduling, monitoring, and restore procedures
- **Layer 3 (CSI Snapshots)**: Low complexity, automated via CSI driver

**Trade-offs**:
- **Pro**: Comprehensive data protection with multiple recovery options
- **Pro**: Flexibility to recover at different granularities (cluster state vs. volume data)
- **Con**: Requires monitoring and alerting for three backup systems
- **Con**: More complex restore procedures (must coordinate across layers)
- **Con**: Higher operational overhead for team training and runbooks

**Simplified Alternative** (if complexity is a concern):
- Use Velero with restic/kopia integration for both K8s resources and volumes
- Rely on Hetzner CSI snapshots as a fallback
- Accept slightly longer recovery times for simplified operations

---

## Storage Architecture

### Storage Strategy: Hetzner CSI + Optional Longhorn

The module uses Hetzner CSI driver as the default storage provider. For advanced storage features, Longhorn can be added as an optional layer.

#### Default: Hetzner CSI Driver

**Current Implementation**:
- Deployed via `cluster-csi.tf`
- Provides `hcloud-volumes` StorageClass
- Block storage volumes attached to worker nodes
- CSI snapshot support for backups

**Characteristics**:
- Native Hetzner integration
- Reliable and well-maintained
- Automatic volume attachment/detachment
- Snapshot capabilities

**Limitations**:
- No built-in replication (single-node access)
- No volume migration across nodes without downtime
- Limited to Hetzner's volume types and sizes

#### Optional: Longhorn Storage Layer

**Use Case**: When advanced storage features are required

**Benefits**:
1. **Volume Replication**: Multiple replicas for data redundancy
2. **Distributed Storage**: Replicate across availability zones
3. **Backup Integration**: Native S3 backup support
4. **Volume Migration**: Move volumes between nodes without downtime
5. **Snapshot Management**: Advanced snapshot scheduling and retention

**Cost Implications**:

For a 3-node cluster with 1TB total storage:

| Configuration | Storage | Replication | Total Required | Monthly Cost (Hetzner) |
|---------------|---------|-------------|----------------|------------------------|
| CSI only      | 1TB     | None        | 1TB            | ~€40 (volume storage)  |
| Longhorn (3x) | 1TB     | 3 replicas  | 3TB            | ~€120 (volume storage) |

**Additional Costs**:
- Increased network traffic between nodes (included in Hetzner traffic limits)
- Higher IOPS demand on volumes
- Additional CPU/memory overhead for Longhorn services (minimal)

**Decision Criteria**:

Use Longhorn if:
- ✅ Require high availability for stateful applications
- ✅ Need cross-zone replication
- ✅ Application cannot tolerate any downtime during node failures
- ✅ Budget allows for 3x storage cost

Stay with CSI only if:
- ✅ Stateful applications can tolerate brief downtime during node failures
- ✅ Backup and recovery from snapshots is acceptable
- ✅ Cost optimization is a priority
- ✅ Single-zone deployment is acceptable

**Recommendation**: Start with Hetzner CSI for initial deployments. Add Longhorn when:
1. Production workloads require guaranteed uptime
2. Storage budget has been validated
3. Operations team is trained on Longhorn management

---

## Node Pool Configuration

### Dedicated Node Pools for Workload Isolation

For production environments, consider separating workloads into dedicated node pools to optimize resource allocation and cost.

#### Proposed Node Pool Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Control Plane                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Master-01   │  │  Master-02   │  │  Master-03   │     │
│  │   (cx22)     │  │   (cx22)     │  │   (cx22)     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
    ┌───────────▼───────┐ ┌──▼──────────┐ ┌▼──────────────┐
    │  Application Pool │ │ Database    │ │  Monitoring   │
    │  (General Workload│ │    Pool     │ │     Pool      │
    │       )           │ │ (Stateful)  │ │  (Observ.)    │
    └───────────────────┘ └─────────────┘ └───────────────┘
    │ 3+ worker nodes   │ │ 3+ nodes    │ │ 1-2 nodes     │
    │ (cpx31-cpx41)     │ │ (cpx31+)    │ │ (cx31)        │
    │ Labels:           │ │ Labels:     │ │ Labels:       │
    │   workload=app    │ │   workload= │ │   workload=   │
    │                   │ │   database  │ │   monitoring  │
    └───────────────────┘ └─────────────┘ └───────────────┘
```

#### Node Pool Strategy

**1. Application Pool** (General Workloads)
- **Purpose**: Web servers, application pods, stateless services
- **Server Type**: cpx31 (4 vCPU, 8GB RAM) or cpx41 (8 vCPU, 16GB RAM)
- **Count**: 3-6 nodes (scale based on load)
- **Labels**: `workload=application`, `pool=general`
- **Taints**: None (accept all workloads by default)

**2. Database Pool** (Stateful Services)
- **Purpose**: MySQL, MongoDB, PostgreSQL, Redis
- **Server Type**: cpx31+ (optimize for storage and memory)
- **Count**: 3 nodes minimum (for replication/HA)
- **Labels**: `workload=database`, `pool=stateful`
- **Taints**: `workload=database:NoSchedule` (dedicated for databases)
- **Storage**: Attach large volumes, consider Longhorn for replication

**3. Monitoring Pool** (Observability Stack)
- **Purpose**: Prometheus, Grafana, Loki, Alertmanager
- **Server Type**: cx31 (2 vCPU, 8GB RAM)
- **Count**: 1-2 nodes
- **Labels**: `workload=monitoring`, `pool=observability`
- **Taints**: `workload=monitoring:NoSchedule` (optional, for isolation)

#### Implementation Considerations

**Current Module Limitations**:
- The module currently supports only homogeneous worker pools
- All workers use the same `worker_server_type`
- Node pool heterogeneity requires module enhancement

**Workaround** (until module supports multiple worker pools):
1. Deploy cluster with general-purpose workers
2. Manually add nodes with different types via Hetzner API
3. Label and taint nodes post-deployment
4. Use node selectors in workload manifests

**Future Module Enhancement**:
```hcl
worker_pools = [
  {
    name        = "general"
    server_type = "cpx31"
    count       = 3
    labels      = { workload = "application" }
  },
  {
    name        = "database"
    server_type = "cpx41"
    count       = 3
    labels      = { workload = "database" }
    taints      = [{ key = "workload", value = "database", effect = "NoSchedule" }]
  },
  {
    name        = "monitoring"
    server_type = "cx31"
    count       = 2
    labels      = { workload = "monitoring" }
  }
]
```

---

## Scaling Strategy

### Capacity Planning for Peak Loads

For Open edX deployments and similar workloads with predictable peak times (e.g., exam periods, course launches):

#### Baseline Capacity

**Development/Staging**:
- 1 master (cx22)
- 2 workers (cpx21 or cpx31)
- Total: ~€50-70/month

**Production (Small - <1000 concurrent users)**:
- 3 masters (cx22)
- 3 workers (cpx31)
- Total: ~€150-180/month

**Production (Medium - 1000-5000 concurrent users)**:
- 3 masters (cx32)
- 5-8 workers (cpx41)
- Total: ~€400-600/month

**Production (Large - 5000+ concurrent users)**:
- 3 masters (cx32 or cpx41)
- 10-15 workers (cpx41 or cpx51)
- Load balancers with more capacity (lb21 or lb31)
- Total: ~€1000-1500/month

#### Horizontal Pod Autoscaling (HPA)

**Configuration**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: openedx-lms
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: lms
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

**Best Practices**:
- Set conservative `averageUtilization` targets (70-80%)
- Define `minReplicas` based on baseline load
- Set `maxReplicas` below total cluster capacity to leave headroom
- Monitor HPA metrics via Prometheus

#### Cluster Autoscaling

**Option 1: Manual Scaling** (Current Approach)
- Monitor cluster resource utilization
- Manually add worker nodes during predicted peak times
- Scale down after peak periods

**Advantages**:
- Full control over costs
- Predictable billing
- No surprises from autoscaling bugs

**Disadvantages**:
- Requires manual intervention
- May miss unexpected load spikes
- Delayed response to scaling needs

**Option 2: Cluster Autoscaler** (Future Enhancement)
- Deploy [Kubernetes Cluster Autoscaler](https://github.com/kubernetes/autoscaler)
- Integrate with Hetzner Cloud API
- Automatically add/remove nodes based on pod scheduling pressure

**Advantages**:
- Automated response to load changes
- Cost optimization (scale down during low usage)
- Better handling of unexpected traffic

**Challenges**:
- Requires Hetzner Cloud API credentials in-cluster
- Potential for cost overruns if misconfigured
- Module does not currently support dynamic node management

**Recommendation**: Start with manual scaling. Add cluster autoscaler once:
1. Workload patterns are well-understood
2. Budget and cost controls are in place
3. Module supports dynamic worker management

---

## Network Considerations

### Network Traffic and Overhead

#### Hetzner Cloud Traffic Limits

**Included Traffic** (per server):
- cx22: 20TB/month
- cx32: 20TB/month
- cpx31: 20TB/month
- cpx41: 20TB/month

**Overage Pricing**: €1.19 per TB

#### Traffic Patterns

**Internal Cluster Traffic** (between nodes):
- Control plane to workers: etcd sync, API requests
- Worker to worker: pod-to-pod communication, Longhorn replication (if enabled)
- Monitoring: Prometheus scraping, log aggregation

**External Traffic**:
- User requests (HTTP/HTTPS)
- Object storage backup (Velero, Kopia)
- Container image pulls

#### Network Overhead Analysis

**Baseline Internal Traffic** (per day, 3-node cluster):
- etcd replication: ~1-5GB
- Monitoring/logging: ~2-10GB
- Pod-to-pod (application-dependent): ~10-100GB

**With Longhorn** (3x replication):
- Storage replication: 3x write traffic
- Example: 100GB/day writes = 300GB/day internal traffic

**Backup Traffic**:
- Velero daily backup: ~5-20GB (depends on cluster size)
- Kopia incremental backup: ~10-50GB (depends on data change rate)
- CSI snapshots: No external traffic (Hetzner-internal)

#### Network Cost Estimation

**Scenario**: 5-node cluster, 100GB/day application traffic, daily backups

| Traffic Type | Daily | Monthly | Included? |
|--------------|-------|---------|-----------|
| Internal (cluster) | 50GB | 1.5TB | ✅ Yes (within Hetzner) |
| External (users) | 100GB | 3TB | ✅ Yes (within limits) |
| Backups (to S3) | 30GB | 900GB | ⚠️ Depends on S3 location |
| Total External | 130GB | 3.9TB | ✅ Under 20TB limit |

**Monitoring Recommendation**:
- Deploy network monitoring (e.g., Prometheus with node-exporter)
- Set alerts for traffic approaching 80% of included limits
- Use `hcloud` CLI to check current traffic usage:
  ```bash
  hcloud server list -o columns=name,traffic
  ```

**Cost Optimization**:
- Use Hetzner Object Storage for backups (stays within Hetzner network)
- Schedule large backup transfers during off-peak hours
- Consider compression for backup data
- Monitor and tune Longhorn replication if used

---

## Operational Complexity Assessment

### Complexity Matrix

| Aspect | Complexity | Mitigation |
|--------|------------|------------|
| **Backup Management** | High (3 systems) | Unified monitoring, automated scheduling |
| **Storage Configuration** | Medium | Start with CSI only, add Longhorn later |
| **Node Pool Management** | Medium | Manual scaling initially, automate later |
| **Network Monitoring** | Low | Hetzner built-in metrics + Prometheus |
| **Scaling Operations** | Medium | HPA for pods, manual for nodes |
| **Disaster Recovery** | High | Regular DR drills, documented runbooks |

### Operational Maturity Progression

**Phase 1: Initial Deployment** (Months 1-3)
- ✅ Hetzner CSI for storage
- ✅ Velero for cluster backups
- ✅ CSI snapshots for volume backups
- ✅ Manual scaling
- ✅ Basic monitoring

**Phase 2: Production Hardening** (Months 3-6)
- ✅ Add Kopia for volume data backup
- ✅ Implement dedicated node pools
- ✅ Set up comprehensive monitoring and alerting
- ✅ Develop and test DR procedures
- ✅ Implement HPA for critical workloads

**Phase 3: Advanced Operations** (Months 6-12)
- ✅ Add Longhorn for HA storage (if needed)
- ✅ Implement cluster autoscaler
- ✅ Automated capacity planning
- ✅ Advanced observability (distributed tracing)
- ✅ Self-healing automation

---

## Implementation Roadmap

### Immediate Actions (Next Sprint)

1. **Document Backup Procedures**
   - [ ] Create Velero installation guide
   - [ ] Document backup schedules and retention policies
   - [ ] Create restore runbooks

2. **Validate Storage Strategy**
   - [ ] Test Hetzner CSI snapshot functionality
   - [ ] Measure baseline storage performance
   - [ ] Evaluate Longhorn for future use

3. **Network Monitoring Setup**
   - [ ] Deploy Prometheus with network metrics
   - [ ] Set up traffic alerts
   - [ ] Document traffic patterns

### Short-term Goals (1-3 Months)

1. **Backup Implementation**
   - Deploy Velero with S3 backend
   - Configure CSI snapshots
   - Test restore procedures

2. **Scaling Validation**
   - Load test with peak user simulation
   - Validate HPA configuration
   - Document manual scaling procedures

3. **Monitoring Enhancement**
   - Deploy Grafana dashboards for operational metrics
   - Set up alerting for backup failures
   - Implement traffic monitoring

### Medium-term Goals (3-6 Months)

1. **Advanced Backup Layer**
   - Evaluate and deploy Kopia if needed
   - Integrate with Velero or run independently
   - Set up automated backup verification

2. **Node Pool Implementation**
   - Enhance module to support heterogeneous worker pools
   - Deploy dedicated database nodes
   - Implement node taints and tolerations

3. **Operational Automation**
   - Automate backup reporting
   - Implement automated scaling recommendations
   - Create self-service DR testing

---

## Open Questions

### Backup Strategy
1. **Kopia vs. Velero+Restic**: Should Kopia be integrated with Velero or run as a separate system?
2. **Retention Policies**: What are the specific RTO/RPO requirements for different data types?
3. **Backup Verification**: How often should restore tests be performed? (Recommendation: Monthly)

### Storage
4. **Longhorn Adoption**: What is the trigger point for adding Longhorn? (User count? Data volume?)
5. **Volume Sizing**: What is the expected growth rate for persistent volumes?
6. **Cross-region Backups**: Is geographic redundancy required? (E.g., backup to non-EU region)

### Scaling
7. **Autoscaling Budget**: What is the maximum acceptable monthly cost for autoscaling?
8. **Peak Load Prediction**: Can peak load times be predicted for pre-scaling? (E.g., exam schedules)
9. **Node Warmup Time**: What is the acceptable time for new nodes to become available? (Currently ~3-5 minutes)

### Operations
10. **On-call Coverage**: Who is responsible for responding to backup failures? Infrastructure alerts?
11. **Runbook Maintenance**: Who owns the operational runbooks? How often are they reviewed?
12. **DR Testing Schedule**: How often should full disaster recovery drills be conducted? (Recommendation: Quarterly)

---

## Next Steps

### For Infrastructure Team
1. Review and approve backup strategy
2. Define RTO/RPO requirements
3. Allocate budget for backup storage and Longhorn (if needed)
4. Schedule DR drill

### For Development Team
1. Review node pool architecture
2. Define pod resource requests/limits for HPA
3. Identify stateful applications requiring Longhorn
4. Implement application-level backup hooks (database dumps)

### For Cloud Agent
1. Implement Velero deployment in Terraform module (optional addon)
2. Configure Hetzner CSI snapshot automation
3. Set up network traffic monitoring
4. Validate backup and restore procedures in test environment

---

## References

- [Velero Documentation](https://velero.io/docs/)
- [Kopia Documentation](https://kopia.io/docs/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [Hetzner CSI Driver](https://github.com/hetznercloud/csi-driver)
- [Kubernetes Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [Hetzner Cloud Pricing](https://www.hetzner.com/cloud)

---

**Document Status**: ✅ Ready for Review
**Next Review**: After implementation of Phase 1 items
**Approvers**: Infrastructure Lead, Operations Team, Cloud Architect
