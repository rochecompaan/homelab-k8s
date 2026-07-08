# Strict-placement RWO Storage Benchmark Placement Audit

## Placement contract

- Writer node: `fordyce`.
- Reader nodes: `dauwalter`, `selassie`.
- Reader Jobs are separate pods and separate Kubernetes Jobs from the writer Job.
- Reader nodes may have local or up-to-date replicas/resources. That condition is recorded and does not invalidate the result.
- These are not cache-cold remote reads and do not claim cold remote/no-replica reads.

## Backend placement evidence

| Backend | Writer evidence | Reader evidence | Storage placement evidence | Validity/storage-placement notes |
| --- | --- | --- | --- | --- |
| Piraeus/LINSTOR RWO | `piraeus-run-001-health.md` writer pod placement and `piraeus-writer-placement-run-001.txt`. | `piraeus-run-001-health.md` reader pod placement, `piraeus-reader-dauwalter-placement-run-001.txt`, and `piraeus-reader-selassie-placement-run-001.txt`. | LINSTOR resource and volume sections in `piraeus-run-001-health.md`. | Writer pod is on `fordyce`; reader pods are on `dauwalter` and `selassie`; `piraeus-rwo-strict-dauwalter` completed but LINSTOR reported the `dauwalter` resource as `Diskless, SkipDisk (R)`, so that result must not be interpreted as a normal local-replica or up-to-date-local-resource read on `dauwalter`. |
| Longhorn NVMe RWO | `longhorn-nvme-run-001-health.md` writer pod placement and `longhorn-nvme-writer-placement-run-001.txt`. | `longhorn-nvme-run-001-health.md` reader pod placement, `longhorn-nvme-reader-dauwalter-placement-run-001.txt`, and `longhorn-nvme-reader-selassie-placement-run-001.txt`. | Longhorn volume, replica, and engine sections in `longhorn-nvme-run-001-health.md`. | Writer pod is on `fordyce`; reader pods are on `dauwalter` and `selassie`; storage placement is recorded as locality-allowed replicated RWO behavior. |
| Mayastor RWO | `mayastor-run-001-health.md` writer pod placement and `mayastor-writer-placement-run-001.txt`. | `mayastor-run-001-health.md` reader pod placement, `mayastor-reader-dauwalter-placement-run-001.txt`, and `mayastor-reader-selassie-placement-run-001.txt`. | Mayastor DiskPool sections and PVC/PV identity in `mayastor-run-001-health.md`; Mayastor volume/replica CRD queries were unavailable in this cluster and their exact errors are recorded there. | Writer pod is on `fordyce`; reader pods are on `dauwalter` and `selassie`; storage placement evidence is limited to pod placement, PVC/PV identity, and DiskPool state rather than volume/replica CRD placement. |

## Read/cache note

The benchmark controls writer and reader consumer placement. Locality is allowed. These results do not claim cold remote/no-replica reads. Local or up-to-date reader-side replicas/resources are allowed and should be interpreted as normal replicated RWO backend behavior except for the explicit Piraeus `dauwalter` caveat above.

## Piraeus caveat carried forward

The Piraeus run completed all required writer and reader Jobs and produced valid `RESULT` rows for both required read-only profiles on both reader nodes. However, `piraeus-run-001-health.md` records LINSTOR reporting the `dauwalter` resource as `Diskless, SkipDisk (R)` before and after the reader phase. Therefore, the `piraeus-rwo-strict-dauwalter` rows are included only with this caveat and must not be described as normal local/up-to-date-replica locality results.
