# Strict-placement RWO Benchmark Runbook

## Safety rules

- Do not run `kubectl apply`, `kubectl patch`, `kubectl delete`, or `helm upgrade` for homelab resources.
- Activate and deactivate benchmark resources by editing this repository and allowing ArgoCD to reconcile from Git.
- Run one backend app at a time.
- Run one reader node at a time for each backend so the RWO PVC is mounted by only one reader consumer.
- Do not run legacy `storage-benchmark-v2-*` or `storage-benchmark-rwx-*` benchmark apps at the same time as the strict RWO benchmark.
- Run backends in this order: Longhorn NVMe, Mayastor, then Piraeus/LINSTOR last.
- Stop ArgoCD sync/prune polling after 5 minutes, inspect Application status, make any Git fixes, and only then terminate a stuck ArgoCD operation through approved ArgoCD controls.
- Stop benchmark Job polling after 10 minutes, inspect Job/pod/log progress, and only start another 10-minute polling interval after recording what changed or what is still running.

## Run order

Run strict RWO backends in this order:

1. Longhorn NVMe
2. Mayastor
3. Piraeus/LINSTOR last

Piraeus/LINSTOR runs last because it is the backend whose original v2 read result motivated this strict-placement benchmark.

## Backend map

| Backend | ArgoCD app base path | Homelab path | PVC | Writer Job | Dauwalter reader Job | Selassie reader Job |
| --- | --- | --- | --- | --- | --- | --- |
| Longhorn NVMe | `argocd/base/storage-benchmark-rwo-strict-longhorn` | `argocd/homelab/storage-benchmark-rwo-strict-longhorn` | `longhorn-nvme-rwo-strict-pvc-run-001` | `longhorn-nvme-rwo-strict-writer-fordyce-run-001` | `longhorn-nvme-rwo-strict-reader-dauwalter-run-001` | `longhorn-nvme-rwo-strict-reader-selassie-run-001` |
| Mayastor | `argocd/base/storage-benchmark-rwo-strict-mayastor` | `argocd/homelab/storage-benchmark-rwo-strict-mayastor` | `mayastor-rwo-strict-pvc-run-001` | `mayastor-rwo-strict-writer-fordyce-run-001` | `mayastor-rwo-strict-reader-dauwalter-run-001` | `mayastor-rwo-strict-reader-selassie-run-001` |
| Piraeus/LINSTOR | `argocd/base/storage-benchmark-rwo-strict-piraeus` | `argocd/homelab/storage-benchmark-rwo-strict-piraeus` | `piraeus-rwo-strict-pvc-run-001` | `piraeus-rwo-strict-writer-fordyce-run-001` | `piraeus-rwo-strict-reader-dauwalter-run-001` | `piraeus-rwo-strict-reader-selassie-run-001` |

## ArgoCD polling checkpoint

Use this 5-minute ArgoCD polling checkpoint after every activation, reader-enable, and cleanup commit. Replace `APP` with the active ArgoCD Application name. Do not poll longer than 5 minutes without checking status.

```bash
app=APP
for attempt in $(seq 1 30); do
  kubectl -n argocd get application "${app}" -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}' || true
  sleep 10
done
kubectl -n argocd describe application "${app}"
kubectl -n argocd get application "${app}" -o yaml > "docs/storage-benchmark-rwo-strict/${app}-argocd-timeout.yaml"
echo "Reached 5-minute ArgoCD polling checkpoint for ${app}; inspect status, make Git fixes, and only then terminate a stuck operation through approved ArgoCD controls." >&2
exit 1
```

If the app syncs before the 5-minute checkpoint, continue to the benchmark Job checks. If the app is stuck, stop and fix the Git state before any operation termination.

## Activate writer phase for one backend

1. Add one app base path to `argocd/homelab/apps/kustomization.yaml`.
2. Commit with a subject such as `chore(storage): activate piraeus strict RWO writer`.
3. Merge or fast-forward the commit onto `main`, the branch ArgoCD tracks.
4. Poll ArgoCD for at most 5 minutes using the ArgoCD polling checkpoint below; if the app is still stuck, inspect and fix before continuing.
5. Confirm the writer Job completed with read-only commands:

```bash
kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/benchmark=rwo-strict
kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-writer-fordyce-run-001
```

For Longhorn and Mayastor, replace the Job name with the name from the backend map.

## Benchmark Job polling checkpoint

Every benchmark Job wait uses a 10-minute checkpoint. If a Job is still running after 10 minutes, inspect Job state, pod placement, and recent logs before starting another wait interval. Do not let an agent poll a benchmark Job for more than 10 minutes without checking progress.

```bash
job=JOB_NAME
backend=BACKEND_LABEL
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete "job/${job}" --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l "storage.compaan.io/backend=${backend}"
  kubectl -n storage-benchmark-rwo-strict logs "job/${job}" --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for ${job}; inspect progress before continuing." >&2
  exit 1
}
```

## Capture writer evidence

```bash
mkdir -p docs/storage-benchmark-rwo-strict
kubectl -n storage-benchmark-rwo-strict get pods -o wide -l storage.compaan.io/benchmark=rwo-strict > docs/storage-benchmark-rwo-strict/pods-run-001.txt
kubectl -n storage-benchmark-rwo-strict get pvc,pv -o wide > docs/storage-benchmark-rwo-strict/pvc-pv-run-001.txt
kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-writer-fordyce-run-001 > docs/storage-benchmark-rwo-strict/piraeus-writer-fordyce-run-001.log
kubectl -n storage-benchmark-rwo-strict logs job/longhorn-nvme-rwo-strict-writer-fordyce-run-001 > docs/storage-benchmark-rwo-strict/longhorn-nvme-writer-fordyce-run-001.log
kubectl -n storage-benchmark-rwo-strict logs job/mayastor-rwo-strict-writer-fordyce-run-001 > docs/storage-benchmark-rwo-strict/mayastor-writer-fordyce-run-001.log
```

Only run the `kubectl logs` command for the backend currently active.

## Enable one reader node

1. Edit the active backend `kustomization.yaml` and add exactly one reader file after `writer-job.yaml`.
2. For the first reader, add `reader-dauwalter-job.yaml`.
3. Commit with a subject such as `chore(storage): activate piraeus strict RWO dauwalter reader`.
4. Merge or fast-forward the commit onto `main`, the branch ArgoCD tracks.
5. Wait for the reader Job to complete before enabling the next reader.
6. Repeat the edit with `reader-selassie-job.yaml` after the `dauwalter` reader completes.

## Capture reader logs

```bash
kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-reader-dauwalter-run-001 > docs/storage-benchmark-rwo-strict/piraeus-reader-dauwalter-run-001.log
kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-reader-selassie-run-001 > docs/storage-benchmark-rwo-strict/piraeus-reader-selassie-run-001.log
kubectl -n storage-benchmark-rwo-strict logs job/longhorn-nvme-rwo-strict-reader-dauwalter-run-001 > docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-dauwalter-run-001.log
kubectl -n storage-benchmark-rwo-strict logs job/longhorn-nvme-rwo-strict-reader-selassie-run-001 > docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-selassie-run-001.log
kubectl -n storage-benchmark-rwo-strict logs job/mayastor-rwo-strict-reader-dauwalter-run-001 > docs/storage-benchmark-rwo-strict/mayastor-reader-dauwalter-run-001.log
kubectl -n storage-benchmark-rwo-strict logs job/mayastor-rwo-strict-reader-selassie-run-001 > docs/storage-benchmark-rwo-strict/mayastor-reader-selassie-run-001.log
```

Run only the commands for Jobs that exist and have completed.

## Backend placement evidence commands

Piraeus/LINSTOR:

```bash
kubectl -n piraeus-datastore get linstorclusters,linstorsatellites -o wide > docs/storage-benchmark-rwo-strict/piraeus-linstor-crs-run-001.txt
kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor node list > docs/storage-benchmark-rwo-strict/piraeus-linstor-nodes-run-001.txt
kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor resource list > docs/storage-benchmark-rwo-strict/piraeus-linstor-resources-run-001.txt
kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor volume list > docs/storage-benchmark-rwo-strict/piraeus-linstor-volumes-run-001.txt
```

Longhorn:

```bash
kubectl -n longhorn-system get volumes.longhorn.io -o wide > docs/storage-benchmark-rwo-strict/longhorn-volumes-run-001.txt
kubectl -n longhorn-system get replicas.longhorn.io -o wide > docs/storage-benchmark-rwo-strict/longhorn-replicas-run-001.txt
kubectl -n longhorn-system get engines.longhorn.io -o wide > docs/storage-benchmark-rwo-strict/longhorn-engines-run-001.txt
```

Mayastor:

```bash
kubectl -n openebs get diskpools.openebs.io -o wide > docs/storage-benchmark-rwo-strict/mayastor-diskpools-run-001.txt
kubectl get volumes.openebs.io -A -o wide > docs/storage-benchmark-rwo-strict/mayastor-volumes-run-001.txt
kubectl get replicas.openebs.io -A -o wide > docs/storage-benchmark-rwo-strict/mayastor-replicas-run-001.txt
```

If a Mayastor CRD command exits because the CRD name is not installed in this cluster, record the exact command and error text in `mayastor-run-001-health.md`.

## Summarize completed reader logs

```bash
python3 scripts/summarize-storage-benchmark.py \
docs/storage-benchmark-rwo-strict/piraeus-reader-dauwalter-run-001.log \
docs/storage-benchmark-rwo-strict/piraeus-reader-selassie-run-001.log \
  > docs/storage-benchmark-rwo-strict/piraeus-run-001-summary.md
python3 scripts/summarize-storage-benchmark.py \
docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-dauwalter-run-001.log \
docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-selassie-run-001.log \
  > docs/storage-benchmark-rwo-strict/longhorn-nvme-run-001-summary.md
python3 scripts/summarize-storage-benchmark.py \
docs/storage-benchmark-rwo-strict/mayastor-reader-dauwalter-run-001.log \
docs/storage-benchmark-rwo-strict/mayastor-reader-selassie-run-001.log \
  > docs/storage-benchmark-rwo-strict/mayastor-run-001-summary.md
```

## Deactivate after artifacts are captured

1. Remove the active strict RWO app path from `argocd/homelab/apps/kustomization.yaml`.
2. Commit with a subject such as `chore(storage): deactivate piraeus strict RWO benchmark`.
3. Merge or fast-forward the cleanup commit onto `main`, the branch ArgoCD tracks.
4. Poll ArgoCD prune for at most 5 minutes using the ArgoCD polling checkpoint; if prune is stuck, inspect and fix before continuing.
5. Capture post-cleanup app and namespace status in the backend health document.
