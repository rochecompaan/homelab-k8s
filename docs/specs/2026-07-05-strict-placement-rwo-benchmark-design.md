# Strict-placement RWO read-after-write benchmark design

## Goal

Add a replicated RWO storage benchmark that measures read performance when the test file was fully written by a different consumer node first.

The benchmark replaces the ambiguous part of the existing `docs/storage-benchmark-v2` read results, where the same fio Job wrote and read on `fordyce`. It must prove that the read consumer is not the same pod or node that wrote/preconditioned the file.

## Scope

In scope:

- Piraeus/LINSTOR RWO
- Longhorn NVMe RWO
- Mayastor RWO
- direct I/O fio read profiles after a full-file writer phase
- placement/resource evidence for writer and reader phases

Out of scope:

- `local-path`; the original local-path v2 results remain the accepted local baseline
- cold remote reads with no local/up-to-date replica
- cache-flush or node page-cache invalidation runbooks
- reader-phase write, mixed read/write, or sync-write profiles

## Placement contract

For every replicated backend:

1. A writer Job mounts the backend RWO PVC on `fordyce`.
2. The writer fully writes `/volume/fio-test-file` using `fio --direct=1` and a fixed size, not a time-based partial warmup.
3. The writer exits so the RWO PVC can detach from `fordyce`.
4. A separate reader Job mounts the same PVC on `dauwalter` and runs read-only fio profiles.
5. A separate reader Job mounts the same PVC on `selassie` and runs the same read-only fio profiles.
6. Results are labeled as different-consumer-node reads with locality allowed.

The reader node may have a local or up-to-date replica/resource. That is valid for this benchmark and must be documented instead of treated as a failure.

## GitOps structure

Add one ArgoCD app per replicated backend, parallel to the existing v2 benchmark apps:

- `argocd/base/storage-benchmark-rwo-strict-piraeus`
- `argocd/base/storage-benchmark-rwo-strict-longhorn`
- `argocd/base/storage-benchmark-rwo-strict-mayastor`
- `argocd/homelab/storage-benchmark-rwo-strict-piraeus`
- `argocd/homelab/storage-benchmark-rwo-strict-longhorn`
- `argocd/homelab/storage-benchmark-rwo-strict-mayastor`

Each homelab backend directory contains:

- `namespace.yaml`
- backend-specific `storageclass.yaml` or pool setup when needed
- `pvc.yaml`
- `fio-script-configmap.yaml`
- `writer-job.yaml`
- `reader-jobs.yaml`
- `kustomization.yaml`

Create the ArgoCD `Application` resources, but do not add them to `argocd/homelab/apps/kustomization.yaml` by default. Benchmarks should not re-run unexpectedly until deliberately enabled through GitOps.

## Job and script behavior

Use a shared script pattern per backend, mounted from a ConfigMap.

The writer phase:

- requires `ROLE=writer`
- requires `WRITER_NODE=fordyce`
- writes the complete fio file once with `--rw=write`, `--bs=1m`, `--size=16G`, `--direct=1`
- records writer setup output separately from reader comparison results
- exits without deleting `/volume/fio-test-file`

The reader phase:

- requires `ROLE=reader`
- requires `READER_NODE=dauwalter` or `READER_NODE=selassie`
- verifies the preconditioned file exists before starting fio
- runs only:
  - `seq-read-1m`
  - `rand-read-4k`
- keeps `--direct=1`
- emits existing `RESULT,...` CSV lines so `scripts/summarize-storage-benchmark.py` can summarize logs unchanged

Use labels on Jobs and pods for auditability:

- `storage.compaan.io/benchmark: rwo-strict`
- `storage.compaan.io/backend: piraeus|longhorn-nvme|mayastor`
- `storage.compaan.io/phase: writer|reader`
- `storage.compaan.io/writer-node: fordyce`
- `storage.compaan.io/reader-node: dauwalter|selassie` for readers

Reader result backend names should include the consumer node, for example:

- `piraeus-rwo-strict-dauwalter`
- `piraeus-rwo-strict-selassie`
- `longhorn-nvme-rwo-strict-dauwalter`
- `mayastor-rwo-strict-selassie`

## Execution sequencing

Do not rely on ArgoCD sync waves to prove that readers start only after the writer Job succeeds and the PVC detaches. The runbook must sequence phases explicitly through GitOps:

1. Enable/sync a backend app with namespace, storage setup, PVC, ConfigMap, and writer Job.
2. Wait for the writer Job to complete.
3. Capture writer pod placement and backend placement/resource evidence.
4. Enable/sync reader Jobs after writer completion.
5. Wait for the `dauwalter` reader Job to complete and capture evidence.
6. Wait for the `selassie` reader Job to complete and capture evidence.
7. Summarize reader `RESULT` rows.
8. Deactivate/prune benchmark resources through GitOps when artifacts are captured.

## Evidence to capture

For each backend, create artifacts under `docs/storage-benchmark-rwo-strict/`:

- raw writer and reader logs
- writer pod node evidence showing completion on `fordyce`
- reader pod node evidence showing completion on `dauwalter` and `selassie`
- PVC/PV identity
- backend placement/resource state after writer completion and during/after each reader phase
- whether each reader node had a local or up-to-date replica/resource
- per-backend summary generated from reader `RESULT` rows

Backend-specific placement evidence:

- Piraeus/LINSTOR: LINSTOR resource/replica state and which node is `InUse`
- Longhorn: volume attachment/current node and replica state
- Mayastor: volume/replica/control-plane state available from existing tooling

## Reporting

The final comparison must:

- include only read profiles from the reader Jobs
- report `dauwalter` and `selassie` separately for each backend
- clearly state that locality is allowed
- avoid describing the results as cold remote/no-replica reads unless a separate artifact explicitly proves that condition
- compare replicated RWO strict-placement results against the original v2 replicated results as context, not as the same methodology
- keep local-path v2 results as the local baseline without rerunning local-path

## Validation

Use the repository-appropriate checks for this GitOps-only repo state:

- Kustomize build or equivalent YAML validation for each new backend app when available
- YAML syntax checks for new manifests
- existing `scripts/summarize-storage-benchmark.py` tests if the summarizer changes
- direct dry-run/static verification instead of new tests for static manifest content

No direct-write cluster commands are part of implementation. Cluster changes must flow through this repo and ArgoCD.