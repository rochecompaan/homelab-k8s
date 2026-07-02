# RWX Storage Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add and run a GitOps-only RWX benchmark for Longhorn, LINSTOR/Piraeus, and OpenEBS Mayastor, then publish raw logs, summaries, health captures, and a final comparison under `docs/storage-benchmark-rwx/`.

**Architecture:** Create dormant benchmark ArgoCD apps for each backend and activate only one backend at a time through `argocd/homelab/apps/kustomization.yaml`. Each backend app provisions an RWX PVC, keeps two proof pods on different nodes, and runs one sequenced fio Job that first runs single-client fio and then runs two concurrent fio clients with unique files in the same RWX mount. Mayastor also uses a temporary NFS CSI app and an NFS server pod backed by a Mayastor RWO PVC.

**Tech Stack:** Kubernetes YAML, ArgoCD Applications, Kustomize, Longhorn CSI, LINSTOR/Piraeus CSI, OpenEBS Mayastor, Kubernetes NFS CSI driver, fio, jq, Python summary script, Git.

## Global Constraints

- Use provider-native RWX per backend: Longhorn share-manager NFS, Piraeus direct LINSTOR CSI RWX, and Mayastor-backed NFS via NFS CSI.
- Do not describe Mayastor RWX as native block RWX; it is Mayastor-backed RWX via NFS.
- Use new result directory `docs/storage-benchmark-rwx/`.
- Every backend must prove multi-attach with two pods on different nodes before fio results are accepted.
- Single-client fio uses 20Gi PVC, 16G fio file, 5 passes, 60 second runtime, 10 second ramp, default `iodepth=16`, and `sync-write-4k` at `iodepth=1`.
- Concurrent fio uses two client processes in one sequenced Job, unique filenames under the same RWX mount, and one pass per profile.
- Homelab changes are GitOps-only: do not run `kubectl apply`, `kubectl patch`, `kubectl delete`, or `helm upgrade` against homelab resources.
- Read-only `kubectl get`, `kubectl describe`, `kubectl logs`, `kubectl wait`, and `kubectl exec` for inspection are allowed.
- Do not bypass git commit signing or hooks.
- No new automated tests are needed for static benchmark YAML/docs; use Kustomize render checks, grep checks, existing Python tests, and read-only cluster checks.

## Approved Execution Correction

The committed plan originally used three independent fio Jobs per backend. That would let the single-client and concurrent jobs start together and corrupt the single-client measurement. The implementation uses one sequenced Job per backend instead: single-client profiles run first, then two concurrent fio clients run together with unique filenames. Any later step that mentions separate `*-single`, `*-concurrent-a`, or `*-concurrent-b` Jobs is superseded by the single `*-fio-run-001` Job and its combined log.

---

## File Structure

Create dormant manifests:

- `argocd/homelab/storage-benchmark-rwx-longhorn/` — Longhorn RWX StorageClass, PVC, proof pods, fio jobs, script ConfigMap.
- `argocd/base/storage-benchmark-rwx-longhorn/` — ArgoCD Application wrapper.
- `argocd/homelab/storage-benchmark-rwx-piraeus/` — LINSTOR cluster config, Piraeus RWX StorageClass, PVC, proof pods, fio jobs, script ConfigMap.
- `argocd/base/storage-benchmark-rwx-piraeus/` — ArgoCD Application wrapper.
- `argocd/homelab/storage-benchmark-rwx-mayastor/` — Mayastor DiskPools, backend RWO StorageClass/PVC, NFS server, RWX PVC, proof pods, fio jobs, script ConfigMap.
- `argocd/base/storage-benchmark-rwx-mayastor/` — ArgoCD Application wrapper.
- `argocd/base/csi-driver-nfs-rwx-benchmark/` — temporary NFS CSI driver Application with StorageClass `mayastor-rwx-nfs-csi`.

Create result artifacts:

- `docs/storage-benchmark-rwx/longhorn-rwx-run-001.log`
- `docs/storage-benchmark-rwx/longhorn-rwx-run-001-summary.md`
- `docs/storage-benchmark-rwx/longhorn-rwx-run-001-health.md`
- `docs/storage-benchmark-rwx/piraeus-rwx-run-001.log`
- `docs/storage-benchmark-rwx/piraeus-rwx-run-001-summary.md`
- `docs/storage-benchmark-rwx/piraeus-rwx-run-001-health.md`
- `docs/storage-benchmark-rwx/mayastor-rwx-run-001.log`
- `docs/storage-benchmark-rwx/mayastor-rwx-run-001-summary.md`
- `docs/storage-benchmark-rwx/mayastor-rwx-run-001-health.md`
- `docs/storage-benchmark-rwx/combined-summary.md`
- `docs/storage-benchmark-rwx/final-comparison.md`

Modify during activation/cleanup:

- `argocd/homelab/apps/kustomization.yaml` — temporarily add/remove benchmark apps and dependency apps.

---

### Task 1: Add dormant RWX benchmark manifests

**Files:**
- Create: `argocd/homelab/storage-benchmark-rwx-longhorn/*`
- Create: `argocd/base/storage-benchmark-rwx-longhorn/*`
- Create: `argocd/homelab/storage-benchmark-rwx-piraeus/*`
- Create: `argocd/base/storage-benchmark-rwx-piraeus/*`
- Create: `argocd/homelab/storage-benchmark-rwx-mayastor/*`
- Create: `argocd/base/storage-benchmark-rwx-mayastor/*`
- Create: `argocd/base/csi-driver-nfs-rwx-benchmark/*`

**Interfaces:**
- Consumes: approved spec `docs/specs/2026-07-02-rwx-storage-benchmark-design.md`.
- Produces: dormant Kustomize paths and ArgoCD Application wrappers used by Tasks 2-4.

- [ ] **Step 1: Generate the dormant manifests**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

NS = "storage-benchmark-rwx"
REPO = "git@github.com:rochecompaan/homelab-k8s.git"
NODES = ("fordyce", "selassie")

FIO_SCRIPT = r'''#!/bin/sh
set -eu

echo "RESULT_HEADER,backend,profile,pass,read_iops,write_iops,read_mib_s,write_mib_s,read_mean_ms,write_mean_ms,read_p95_ms,write_p95_ms,read_p99_ms,write_p99_ms,read_p999_ms,write_p999_ms,errors"

BACKEND="${BACKEND:?BACKEND is required}"
CLIENT_ID="${CLIENT_ID:-single}"
CLIENT_COUNT="${CLIENT_COUNT:-1}"
PASSES="${PASSES:-5}"
FIO_SIZE="${FIO_SIZE:-16G}"
FIO_RUNTIME="${FIO_RUNTIME:-60}"
FIO_RAMP="${FIO_RAMP:-10}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
result_dir="/volume/results/${BACKEND}/${CLIENT_ID}/${timestamp}"
mkdir -p "${result_dir}"

if [ "${CLIENT_COUNT}" -gt 1 ]; then
  mkdir -p /volume/barriers
  touch "/volume/barriers/${BACKEND}-${CLIENT_ID}.ready"
  while :; do
    ready_count="$(ls /volume/barriers/${BACKEND}-*.ready 2>/dev/null | wc -l | tr -d ' ')"
    [ "${ready_count}" -ge "${CLIENT_COUNT}" ] && break
    echo "waiting for ${CLIENT_COUNT} clients; ready=${ready_count}"
    sleep 2
  done
fi

fio_file="/volume/${CLIENT_ID}-fio-test-file"

fio \
  --name=warmup \
  --filename="${fio_file}" \
  --rw=write \
  --bs=1m \
  --size="${FIO_SIZE}" \
  --ioengine=libaio \
  --iodepth=16 \
  --numjobs=1 \
  --direct=1 \
  --time_based \
  --runtime=30 \
  --group_reporting \
  --output-format=json \
  --output="${result_dir}/warmup.json"

run_profile() {
  profile="$1"
  pass="$2"
  rw="$3"
  bs="$4"
  rwmixread="${5:-}"
  iodepth="${6:-16}"
  output="${result_dir}/${profile}-pass-${pass}.json"

  fio \
    --name="${profile}" \
    --filename="${fio_file}" \
    --rw="${rw}" \
    --bs="${bs}" \
    --size="${FIO_SIZE}" \
    --ioengine=libaio \
    --iodepth="${iodepth}" \
    --numjobs=1 \
    --direct=1 \
    --time_based \
    --runtime="${FIO_RUNTIME}" \
    --ramp_time="${FIO_RAMP}" \
    --group_reporting \
    --output-format=json \
    ${rwmixread:+--rwmixread="${rwmixread}"} \
    --output="${output}"

  jq -r --arg backend "${BACKEND}" --arg profile "${profile}" --arg pass "${pass}" '
    .jobs[0] as $job |
    [
      "RESULT",
      $backend,
      $profile,
      $pass,
      ($job.read.iops // 0),
      ($job.write.iops // 0),
      (($job.read.bw_bytes // 0) / 1048576),
      (($job.write.bw_bytes // 0) / 1048576),
      (($job.read.clat_ns.mean // 0) / 1000000),
      (($job.write.clat_ns.mean // 0) / 1000000),
      (($job.read.clat_ns.percentile["95.000000"] // 0) / 1000000),
      (($job.write.clat_ns.percentile["95.000000"] // 0) / 1000000),
      (($job.read.clat_ns.percentile["99.000000"] // 0) / 1000000),
      (($job.write.clat_ns.percentile["99.000000"] // 0) / 1000000),
      (($job.read.clat_ns.percentile["99.900000"] // 0) / 1000000),
      (($job.write.clat_ns.percentile["99.900000"] // 0) / 1000000),
      ($job.error // 0)
    ] | @csv | sub("^\\\"RESULT\\\","; "RESULT,")
  ' "${output}"
}

for pass in $(seq 1 "${PASSES}"); do
  label="${pass}"
  [ "${CLIENT_COUNT}" -gt 1 ] && label="${CLIENT_ID}-${pass}"
  run_profile seq-write-1m "${label}" write 1m
  run_profile seq-read-1m "${label}" read 1m
  run_profile rand-write-4k "${label}" randwrite 4k
  run_profile rand-read-4k "${label}" randread 4k
  run_profile randrw-4k-70r30w "${label}" randrw 4k 70
  run_profile sync-write-4k "${label}" write 4k "" 1
done
'''


def w(path: str, text: str) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text.strip() + "\n")


def app(name: str, path: str, namespace: str, wave: str = "5") -> str:
    return f'''
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {name}
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: '{wave}'
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {REPO}
    targetRevision: main
    path: {path}
  destination:
    server: https://kubernetes.default.svc
    namespace: {namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
'''


def app_kustomization() -> str:
    return '''
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
  - app.yaml
'''


def namespace() -> str:
    return f'''
apiVersion: v1
kind: Namespace
metadata:
  name: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
'''


def fio_configmap(name: str) -> str:
    script = "\n".join("    " + line for line in FIO_SCRIPT.splitlines())
    return f'''
apiVersion: v1
kind: ConfigMap
metadata:
  name: {name}
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "1"
data:
  fio-rwx.sh: |
{script}
'''


def proof_pods(backend: str, pvc: str) -> str:
    node_a, node_b = NODES
    return f'''
apiVersion: v1
kind: Pod
metadata:
  name: {backend}-proof-a
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: {backend}
    storage.compaan.io/role: proof
spec:
  restartPolicy: Always
  nodeSelector:
    kubernetes.io/hostname: {node_a}
  containers:
    - name: proof
      image: alpine:3.20
      command: ["sh", "-c"]
      args:
        - |
          set -eu
          echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) proof-a $(hostname)" >> /volume/rwx-proof.txt
          while true; do echo "--- proof-a sees ---"; cat /volume/rwx-proof.txt; sleep 30; done
      volumeMounts:
        - name: data
          mountPath: /volume
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: {pvc}
---
apiVersion: v1
kind: Pod
metadata:
  name: {backend}-proof-b
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: {backend}
    storage.compaan.io/role: proof
spec:
  restartPolicy: Always
  nodeSelector:
    kubernetes.io/hostname: {node_b}
  containers:
    - name: proof
      image: alpine:3.20
      command: ["sh", "-c"]
      args:
        - |
          set -eu
          echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) proof-b $(hostname)" >> /volume/rwx-proof.txt
          while true; do echo "--- proof-b sees ---"; cat /volume/rwx-proof.txt; sleep 30; done
      volumeMounts:
        - name: data
          mountPath: /volume
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: {pvc}
'''


def fio_job(backend: str, pvc: str, configmap: str, job: str, mode: str, node: str, client: str, count: int, passes: int, size: str = "16G") -> str:
    backend_value = f"{backend}-{mode}"
    return f'''
apiVersion: batch/v1
kind: Job
metadata:
  name: {job}
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: {backend}
    storage.compaan.io/role: fio
    storage.compaan.io/mode: {mode}
spec:
  activeDeadlineSeconds: 14400
  backoffLimit: 0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: storage-benchmark-rwx
        storage.compaan.io/backend: {backend}
        storage.compaan.io/role: fio
        storage.compaan.io/mode: {mode}
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: {node}
      containers:
        - name: fio
          image: nixery.dev/shell/fio/jq/coreutils
          env:
            - name: BACKEND
              value: {backend_value}
            - name: CLIENT_ID
              value: {client}
            - name: CLIENT_COUNT
              value: "{count}"
            - name: PASSES
              value: "{passes}"
            - name: FIO_SIZE
              value: {size}
            - name: FIO_RUNTIME
              value: "60"
            - name: FIO_RAMP
              value: "10"
          command: ["/bin/sh", "/scripts/fio-rwx.sh"]
          volumeMounts:
            - name: data
              mountPath: /volume
            - name: script
              mountPath: /scripts
              readOnly: true
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: {pvc}
        - name: script
          configMap:
            name: {configmap}
            defaultMode: 0555
'''


def fio_jobs(backend: str, pvc: str, configmap: str) -> str:
    return "---\n".join([
        fio_job(backend, pvc, configmap, f"{backend}-single", "single", "fordyce", "single", 1, 5),
        fio_job(backend, pvc, configmap, f"{backend}-concurrent-a", "concurrent", "fordyce", "client-a", 2, 1),
        fio_job(backend, pvc, configmap, f"{backend}-concurrent-b", "concurrent", "selassie", "client-b", 2, 1),
    ])


def longhorn() -> None:
    base = "argocd/homelab/storage-benchmark-rwx-longhorn"
    app_base = "argocd/base/storage-benchmark-rwx-longhorn"
    w(f"{base}/namespace.yaml", namespace())
    w(f"{base}/storageclass.yaml", '''
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-rwx-nvme-bench-3r
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  labels:
    storage.compaan.io/benchmark: "true"
    storage.compaan.io/backend: longhorn-rwx
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  backupTargetName: default
  dataEngine: v1
  dataLocality: disabled
  disableRevisionCounter: "true"
  diskSelector: nvme
  fromBackup: ""
  fsType: ext4
  numberOfReplicas: "3"
  staleReplicaTimeout: "30"
  unmapMarkSnapChainRemoved: ignored
''')
    w(f"{base}/pvc.yaml", f'''
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-rwx-pvc-run-001
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: longhorn-rwx
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn-rwx-nvme-bench-3r
  resources:
    requests:
      storage: 20Gi
''')
    w(f"{base}/fio-script-configmap.yaml", fio_configmap("longhorn-rwx-fio-script"))
    w(f"{base}/multiattach-proof.yaml", proof_pods("longhorn-rwx", "longhorn-rwx-pvc-run-001"))
    w(f"{base}/fio-jobs.yaml", fio_jobs("longhorn-rwx", "longhorn-rwx-pvc-run-001", "longhorn-rwx-fio-script"))
    w(f"{base}/kustomization.yaml", '''
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - storageclass.yaml
  - pvc.yaml
  - fio-script-configmap.yaml
  - multiattach-proof.yaml
  - fio-jobs.yaml
''')
    w(f"{app_base}/app.yaml", app("storage-benchmark-rwx-longhorn", base, NS, "5"))
    w(f"{app_base}/kustomization.yaml", app_kustomization())


def piraeus() -> None:
    base = "argocd/homelab/storage-benchmark-rwx-piraeus"
    app_base = "argocd/base/storage-benchmark-rwx-piraeus"
    w(f"{base}/namespace.yaml", namespace())
    w(f"{base}/linstor-cluster.yaml", '''
apiVersion: piraeus.io/v1
kind: LinstorCluster
metadata:
  name: linstorcluster
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  nodeSelector:
    storage.compaan.io/linstor-benchmark: "true"
---
apiVersion: piraeus.io/v1
kind: LinstorSatelliteConfiguration
metadata:
  name: linstor-bench-storage
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  nodeSelector:
    storage.compaan.io/linstor-benchmark: "true"
  podTemplate:
    spec:
      volumes:
        - name: usr-src
          hostPath:
            path: /usr/src
            type: DirectoryOrCreate
  storagePools:
    - name: linstor-bench
      lvmThinPool:
        volumeGroup: vg-nvme
        thinPool: linstor-bench-thin
''')
    w(f"{base}/storageclass.yaml", '''
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: piraeus-rwx-bench-3r
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  labels:
    storage.compaan.io/benchmark: "true"
    storage.compaan.io/backend: piraeus-rwx
provisioner: linstor.csi.linbit.com
allowVolumeExpansion: false
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  linstor.csi.linbit.com/storagePool: linstor-bench
  linstor.csi.linbit.com/placementCount: "3"
''')
    w(f"{base}/pvc.yaml", f'''
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: piraeus-rwx-pvc-run-001
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: piraeus-rwx
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: piraeus-rwx-bench-3r
  resources:
    requests:
      storage: 20Gi
''')
    w(f"{base}/fio-script-configmap.yaml", fio_configmap("piraeus-rwx-fio-script"))
    w(f"{base}/multiattach-proof.yaml", proof_pods("piraeus-rwx", "piraeus-rwx-pvc-run-001"))
    w(f"{base}/fio-jobs.yaml", fio_jobs("piraeus-rwx", "piraeus-rwx-pvc-run-001", "piraeus-rwx-fio-script"))
    w(f"{base}/kustomization.yaml", '''
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - linstor-cluster.yaml
  - storageclass.yaml
  - pvc.yaml
  - fio-script-configmap.yaml
  - multiattach-proof.yaml
  - fio-jobs.yaml
''')
    w(f"{app_base}/app.yaml", app("storage-benchmark-rwx-piraeus", base, "piraeus-datastore", "5"))
    w(f"{app_base}/kustomization.yaml", app_kustomization())


def mayastor() -> None:
    base = "argocd/homelab/storage-benchmark-rwx-mayastor"
    app_base = "argocd/base/storage-benchmark-rwx-mayastor"
    w(f"{base}/namespace.yaml", namespace())
    w(f"{base}/diskpools.yaml", '''
apiVersion: openebs.io/v1beta3
kind: DiskPool
metadata:
  name: mayastor-rwx-bench-dauwalter
  namespace: openebs
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  node: dauwalter
  disks:
    - aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench
  maxExpansion: "1x"
---
apiVersion: openebs.io/v1beta3
kind: DiskPool
metadata:
  name: mayastor-rwx-bench-fordyce
  namespace: openebs
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  node: fordyce
  disks:
    - aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench
  maxExpansion: "1x"
---
apiVersion: openebs.io/v1beta3
kind: DiskPool
metadata:
  name: mayastor-rwx-bench-selassie
  namespace: openebs
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  node: selassie
  disks:
    - aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench
  maxExpansion: "1x"
''')
    w(f"{base}/storageclass-backend.yaml", '''
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mayastor-rwx-backend-3r
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  labels:
    storage.compaan.io/benchmark: "true"
    storage.compaan.io/backend: mayastor-rwx
provisioner: io.openebs.csi-mayastor
allowVolumeExpansion: false
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  protocol: nvmf
  repl: "3"
''')
    w(f"{base}/nfs-server.yaml", f'''
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mayastor-rwx-nfs-backend-pvc-run-001
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: mayastor-rwx
    storage.compaan.io/role: nfs-backend
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: mayastor-rwx-backend-3r
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mayastor-rwx-nfs-server
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: mayastor-rwx
    storage.compaan.io/role: nfs-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mayastor-rwx-nfs-server
  template:
    metadata:
      labels:
        app: mayastor-rwx-nfs-server
        app.kubernetes.io/name: storage-benchmark-rwx
        storage.compaan.io/backend: mayastor-rwx
        storage.compaan.io/role: nfs-server
    spec:
      nodeSelector:
        kubernetes.io/hostname: fordyce
      containers:
        - name: nfs-server
          image: itsthenetwork/nfs-server-alpine:latest
          env:
            - name: SHARED_DIRECTORY
              value: /nfsshare
          ports:
            - name: nfs
              containerPort: 2049
          securityContext:
            privileged: true
          volumeMounts:
            - name: nfs-vol
              mountPath: /nfsshare
      volumes:
        - name: nfs-vol
          persistentVolumeClaim:
            claimName: mayastor-rwx-nfs-backend-pvc-run-001
---
apiVersion: v1
kind: Service
metadata:
  name: mayastor-rwx-nfs-server
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: mayastor-rwx
    storage.compaan.io/role: nfs-server
spec:
  type: ClusterIP
  selector:
    app: mayastor-rwx-nfs-server
  ports:
    - name: nfs
      port: 2049
      targetPort: 2049
''')
    w(f"{base}/rwx-pvc.yaml", f'''
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mayastor-rwx-pvc-run-001
  namespace: {NS}
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: mayastor-rwx
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: mayastor-rwx-nfs-csi
  resources:
    requests:
      storage: 20Gi
''')
    w(f"{base}/fio-script-configmap.yaml", fio_configmap("mayastor-rwx-fio-script"))
    w(f"{base}/multiattach-proof.yaml", proof_pods("mayastor-rwx", "mayastor-rwx-pvc-run-001"))
    w(f"{base}/fio-jobs.yaml", fio_jobs("mayastor-rwx", "mayastor-rwx-pvc-run-001", "mayastor-rwx-fio-script"))
    w(f"{base}/kustomization.yaml", '''
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - diskpools.yaml
  - storageclass-backend.yaml
  - nfs-server.yaml
  - rwx-pvc.yaml
  - fio-script-configmap.yaml
  - multiattach-proof.yaml
  - fio-jobs.yaml
''')
    w(f"{app_base}/app.yaml", app("storage-benchmark-rwx-mayastor", base, NS, "6"))
    w(f"{app_base}/kustomization.yaml", app_kustomization())


def nfs_csi_app() -> None:
    base = "argocd/base/csi-driver-nfs-rwx-benchmark"
    w(f"{base}/app.yaml", f'''
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: csi-driver-nfs-rwx-benchmark
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: '5'
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    chart: csi-driver-nfs
    repoURL: https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
    targetRevision: 4.13.3
    helm:
      releaseName: csi-driver-nfs-rwx-benchmark
      valuesObject:
        storageClass:
          create: true
          name: mayastor-rwx-nfs-csi
          parameters:
            server: mayastor-rwx-nfs-server.{NS}.svc.cluster.local
            share: /
          reclaimPolicy: Delete
          volumeBindingMode: Immediate
          mountOptions:
            - nfsvers=4.1
  destination:
    server: https://kubernetes.default.svc
    namespace: csi-nfs
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
''')
    w(f"{base}/kustomization.yaml", app_kustomization())


longhorn()
piraeus()
mayastor()
nfs_csi_app()
PY
```

Expected: the command exits 0 and creates the dormant benchmark and app wrapper files.

- [ ] **Step 2: Render and grep-check every dormant app**

Run:

```bash
for path in \
  argocd/homelab/storage-benchmark-rwx-longhorn \
  argocd/homelab/storage-benchmark-rwx-piraeus \
  argocd/homelab/storage-benchmark-rwx-mayastor \
  argocd/base/storage-benchmark-rwx-longhorn \
  argocd/base/storage-benchmark-rwx-piraeus \
  argocd/base/storage-benchmark-rwx-mayastor \
  argocd/base/csi-driver-nfs-rwx-benchmark; do
  kubectl kustomize "$path" > "/tmp/$(basename "$path").yaml"
done

grep -n 'storageClassName: longhorn-rwx-nvme-bench-3r' /tmp/storage-benchmark-rwx-longhorn.yaml
grep -n 'diskSelector: nvme' /tmp/storage-benchmark-rwx-longhorn.yaml
grep -n 'storageClassName: piraeus-rwx-bench-3r' /tmp/storage-benchmark-rwx-piraeus.yaml
grep -n 'ReadWriteMany' /tmp/storage-benchmark-rwx-piraeus.yaml
grep -n 'storageClassName: mayastor-rwx-nfs-csi' /tmp/storage-benchmark-rwx-mayastor.yaml
grep -n 'mayastor-rwx-nfs-server.storage-benchmark-rwx.svc.cluster.local' /tmp/csi-driver-nfs-rwx-benchmark.yaml
grep -n '/volume/${CLIENT_ID}-fio-test-file' /tmp/storage-benchmark-rwx-longhorn.yaml
```

Expected: every `kubectl kustomize` exits 0 and every `grep` prints at least one matching line.

- [ ] **Step 3: Run existing lightweight tests**

Run:

```bash
python3 scripts/test_summarize_storage_benchmark.py
python3 scripts/test-just-targets.py
```

Expected: both commands pass.

- [ ] **Step 4: Commit dormant manifests**

Run:

```bash
git status --short
git add \
  argocd/homelab/storage-benchmark-rwx-longhorn \
  argocd/base/storage-benchmark-rwx-longhorn \
  argocd/homelab/storage-benchmark-rwx-piraeus \
  argocd/base/storage-benchmark-rwx-piraeus \
  argocd/homelab/storage-benchmark-rwx-mayastor \
  argocd/base/storage-benchmark-rwx-mayastor \
  argocd/base/csi-driver-nfs-rwx-benchmark
git commit -m "feat(storage): add rwx benchmark manifests"
```

Expected: commit succeeds and the working tree is clean.

---

### Task 2: Activate, run, capture, and prune Longhorn RWX

**Files:**
- Modify: `argocd/homelab/apps/kustomization.yaml`
- Create: `docs/storage-benchmark-rwx/longhorn-rwx-run-001.log`
- Create: `docs/storage-benchmark-rwx/longhorn-rwx-run-001-summary.md`
- Create: `docs/storage-benchmark-rwx/longhorn-rwx-run-001-health.md`

**Interfaces:**
- Consumes: dormant Longhorn app from Task 1.
- Produces: Longhorn RWX artifacts used by Task 5.

- [ ] **Step 1: Activate only the Longhorn RWX benchmark app**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
text = path.read_text()
anchor = '  - ../../base/longhorn-admission-hooks\n'
insert = '  - ../../base/storage-benchmark-rwx-longhorn\n'
if insert not in text:
    if anchor not in text:
        raise SystemExit('missing longhorn-admission-hooks anchor')
    text = text.replace(anchor, anchor + insert)
path.write_text(text)
PY

kubectl kustomize argocd/homelab/apps > /tmp/homelab-apps-longhorn-rwx.yaml
grep -n 'name: storage-benchmark-rwx-longhorn' /tmp/homelab-apps-longhorn-rwx.yaml
grep -n 'path: argocd/homelab/storage-benchmark-rwx-longhorn' /tmp/homelab-apps-longhorn-rwx.yaml
```

Expected: the rendered root app includes only `storage-benchmark-rwx-longhorn` from the new RWX benchmark apps.

- [ ] **Step 2: Commit and publish the Longhorn activation**

Run:

```bash
git add argocd/homelab/apps/kustomization.yaml
git commit -m "feat(storage): activate longhorn rwx benchmark"
```

Expected: commit succeeds.

Then get the activation commit onto GitOps `main` using the normal signed/hooked path. ArgoCD tracks `targetRevision: main`, so the benchmark will not run until the activation commit reaches `main`.

- [ ] **Step 3: Wait for proof pods and fio jobs**

After the activation commit reaches `main`, run read-only checks:

```bash
kubectl -n argocd get applications storage-benchmark-rwx-longhorn -o wide
kubectl -n storage-benchmark-rwx get pvc,pod,job -l storage.compaan.io/backend=longhorn-rwx -o wide
kubectl -n storage-benchmark-rwx wait --for=condition=Ready pod/longhorn-rwx-proof-a --timeout=15m
kubectl -n storage-benchmark-rwx wait --for=condition=Ready pod/longhorn-rwx-proof-b --timeout=15m
kubectl -n storage-benchmark-rwx logs pod/longhorn-rwx-proof-a --tail=20
kubectl -n storage-benchmark-rwx logs pod/longhorn-rwx-proof-b --tail=20
kubectl -n storage-benchmark-rwx wait --for=condition=complete job/longhorn-rwx-single --timeout=5h
kubectl -n storage-benchmark-rwx wait --for=condition=complete job/longhorn-rwx-concurrent-a --timeout=5h
kubectl -n storage-benchmark-rwx wait --for=condition=complete job/longhorn-rwx-concurrent-b --timeout=5h
```

Expected:

- Both proof pod logs include both `proof-a` and `proof-b` marker lines.
- Single and concurrent jobs complete successfully.

If a pod fails to mount with an NFS client/helper error, stop and record the failure; do not fix nodes by hand.

- [ ] **Step 4: Capture Longhorn logs and summary**

Run:

```bash
mkdir -p docs/storage-benchmark-rwx
{
  echo '# longhorn-rwx proof logs'
  kubectl -n storage-benchmark-rwx logs pod/longhorn-rwx-proof-a --tail=80
  kubectl -n storage-benchmark-rwx logs pod/longhorn-rwx-proof-b --tail=80
  echo '# longhorn-rwx single fio'
  kubectl -n storage-benchmark-rwx logs job/longhorn-rwx-single
  echo '# longhorn-rwx concurrent fio client-a'
  kubectl -n storage-benchmark-rwx logs job/longhorn-rwx-concurrent-a
  echo '# longhorn-rwx concurrent fio client-b'
  kubectl -n storage-benchmark-rwx logs job/longhorn-rwx-concurrent-b
} > docs/storage-benchmark-rwx/longhorn-rwx-run-001.log

grep -c '^RESULT,' docs/storage-benchmark-rwx/longhorn-rwx-run-001.log
python3 scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-rwx/longhorn-rwx-run-001.log \
  > docs/storage-benchmark-rwx/longhorn-rwx-run-001-summary.md
```

Expected:

- `grep -c '^RESULT,'` prints `42`.
- Summary has 12 rows: 6 `longhorn-rwx-single` rows and 6 `longhorn-rwx-concurrent` rows.

- [ ] **Step 5: Capture Longhorn health and placement**

Run:

```bash
{
  echo '# Longhorn RWX run 001 health'
  echo
  echo "Captured: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo '## ArgoCD application'
  kubectl -n argocd get applications storage-benchmark-rwx-longhorn -o wide
  echo
  echo '## Benchmark resources'
  kubectl -n storage-benchmark-rwx get pvc,pv,pod,job -l storage.compaan.io/backend=longhorn-rwx -o wide
  echo
  echo '## PVC YAML'
  kubectl -n storage-benchmark-rwx get pvc longhorn-rwx-pvc-run-001 -o yaml
  echo
  PV="$(kubectl -n storage-benchmark-rwx get pvc longhorn-rwx-pvc-run-001 -o jsonpath='{.spec.volumeName}')"
  echo "## PV ${PV}"
  kubectl get pv "${PV}" -o yaml
  echo
  echo "## Longhorn volume ${PV}"
  kubectl -n longhorn-system get volumes.longhorn.io "${PV}" -o yaml
  echo
  echo "## Longhorn replicas for ${PV}"
  kubectl -n longhorn-system get replicas.longhorn.io -l "longhornvolume=${PV}" -o wide
  kubectl -n longhorn-system get replicas.longhorn.io -l "longhornvolume=${PV}" -o yaml
  echo
  echo '## Longhorn share managers'
  kubectl -n longhorn-system get sharemanagers.longhorn.io -o wide || true
  kubectl -n longhorn-system get pod,svc -o wide | grep -E "share-manager|${PV}" || true
  echo
  echo '## Longhorn node disks'
  kubectl -n longhorn-system get nodes.longhorn.io -o json | python3 -c '
import json, sys
for node in json.load(sys.stdin).get("items", []):
    print("node " + node["metadata"]["name"])
    disks = node.get("spec", {}).get("disks", {}) or {}
    for name, disk in disks.items():
        tags = ",".join(disk.get("tags") or []) or "-"
        print(f"  disk {name}: path={disk.get('path')} tags={tags} allowScheduling={disk.get('allowScheduling')}")
'
} > docs/storage-benchmark-rwx/longhorn-rwx-run-001-health.md

grep -n 'diskSelector: nvme' docs/storage-benchmark-rwx/longhorn-rwx-run-001-health.md
grep -n '/srv/data' docs/storage-benchmark-rwx/longhorn-rwx-run-001-health.md || true
```

Expected: health captures the share-manager path and shows Longhorn replica placement. If `/srv/data` appears under benchmark replica `diskPath`, stop; the run is invalid.

- [ ] **Step 6: Remove Longhorn app from bootstrap and commit results**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
line = '  - ../../base/storage-benchmark-rwx-longhorn\n'
text = path.read_text()
if line not in text:
    raise SystemExit('storage-benchmark-rwx-longhorn is not active')
path.write_text(text.replace(line, ''))
PY

kubectl kustomize argocd/homelab/apps > /tmp/homelab-apps-after-longhorn-rwx.yaml
if grep -q 'storage-benchmark-rwx-longhorn' /tmp/homelab-apps-after-longhorn-rwx.yaml; then
  echo 'unexpected longhorn rwx app still rendered'
  exit 1
fi

git add \
  argocd/homelab/apps/kustomization.yaml \
  docs/storage-benchmark-rwx/longhorn-rwx-run-001.log \
  docs/storage-benchmark-rwx/longhorn-rwx-run-001-summary.md \
  docs/storage-benchmark-rwx/longhorn-rwx-run-001-health.md
git commit -m "docs(storage): add longhorn rwx benchmark results"
```

Expected: cleanup/result commit succeeds. After it reaches `main`, ArgoCD prunes the Longhorn RWX app and resources.

---

### Task 3: Activate, run, capture, and prune Piraeus RWX

**Files:**
- Modify: `argocd/homelab/apps/kustomization.yaml`
- Create: `docs/storage-benchmark-rwx/piraeus-rwx-run-001.log`
- Create: `docs/storage-benchmark-rwx/piraeus-rwx-run-001-summary.md`
- Create: `docs/storage-benchmark-rwx/piraeus-rwx-run-001-health.md`

**Interfaces:**
- Consumes: dormant Piraeus app from Task 1.
- Produces: Piraeus RWX artifacts used by Task 5.

- [ ] **Step 1: Activate Piraeus operator and Piraeus RWX benchmark app**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
text = path.read_text()
anchor = '  - ../../base/local-path-provisioner\n'
insert = '  - ../../base/piraeus-operator\n  - ../../base/storage-benchmark-rwx-piraeus\n'
if '  - ../../base/storage-benchmark-rwx-piraeus\n' not in text:
    if anchor not in text:
        raise SystemExit('missing local-path-provisioner anchor')
    text = text.replace(anchor, anchor + insert)
path.write_text(text)
PY

kubectl kustomize argocd/homelab/apps > /tmp/homelab-apps-piraeus-rwx.yaml
grep -n 'name: piraeus-operator' /tmp/homelab-apps-piraeus-rwx.yaml
grep -n 'name: storage-benchmark-rwx-piraeus' /tmp/homelab-apps-piraeus-rwx.yaml
```

Expected: rendered root app includes `piraeus-operator` and `storage-benchmark-rwx-piraeus`.

- [ ] **Step 2: Commit and publish the Piraeus activation**

Run:

```bash
git add argocd/homelab/apps/kustomization.yaml
git commit -m "feat(storage): activate piraeus rwx benchmark"
```

Expected: commit succeeds. Then get the activation commit onto GitOps `main` using the normal signed/hooked path.

- [ ] **Step 3: Wait for proof pods and fio jobs**

After the activation commit reaches `main`, run:

```bash
kubectl -n argocd get applications piraeus-operator storage-benchmark-rwx-piraeus -o wide
kubectl -n piraeus-datastore get linstorcluster,linstorsatellite -o wide
kubectl -n storage-benchmark-rwx get pvc,pod,job -l storage.compaan.io/backend=piraeus-rwx -o wide
kubectl -n storage-benchmark-rwx wait --for=condition=Ready pod/piraeus-rwx-proof-a --timeout=20m
kubectl -n storage-benchmark-rwx wait --for=condition=Ready pod/piraeus-rwx-proof-b --timeout=20m
kubectl -n storage-benchmark-rwx logs pod/piraeus-rwx-proof-a --tail=20
kubectl -n storage-benchmark-rwx logs pod/piraeus-rwx-proof-b --tail=20
kubectl -n storage-benchmark-rwx wait --for=condition=complete job/piraeus-rwx-single --timeout=5h
kubectl -n storage-benchmark-rwx wait --for=condition=complete job/piraeus-rwx-concurrent-a --timeout=5h
kubectl -n storage-benchmark-rwx wait --for=condition=complete job/piraeus-rwx-concurrent-b --timeout=5h
```

Expected: proof logs show both markers and all fio jobs complete. If the RWX PVC does not bind or does not create NFS/Reactor-related resources, stop and debug before changing manifests.

- [ ] **Step 4: Capture Piraeus logs and summary**

Run:

```bash
mkdir -p docs/storage-benchmark-rwx
{
  echo '# piraeus-rwx proof logs'
  kubectl -n storage-benchmark-rwx logs pod/piraeus-rwx-proof-a --tail=80
  kubectl -n storage-benchmark-rwx logs pod/piraeus-rwx-proof-b --tail=80
  echo '# piraeus-rwx single fio'
  kubectl -n storage-benchmark-rwx logs job/piraeus-rwx-single
  echo '# piraeus-rwx concurrent fio client-a'
  kubectl -n storage-benchmark-rwx logs job/piraeus-rwx-concurrent-a
  echo '# piraeus-rwx concurrent fio client-b'
  kubectl -n storage-benchmark-rwx logs job/piraeus-rwx-concurrent-b
} > docs/storage-benchmark-rwx/piraeus-rwx-run-001.log

grep -c '^RESULT,' docs/storage-benchmark-rwx/piraeus-rwx-run-001.log
python3 scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-rwx/piraeus-rwx-run-001.log \
  > docs/storage-benchmark-rwx/piraeus-rwx-run-001-summary.md
```

Expected: `grep -c '^RESULT,'` prints `42` and summary has 12 Piraeus rows.

- [ ] **Step 5: Capture Piraeus health and RWX implementation details**

Run:

```bash
{
  echo '# Piraeus RWX run 001 health'
  echo
  echo "Captured: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo '## ArgoCD applications'
  kubectl -n argocd get applications piraeus-operator storage-benchmark-rwx-piraeus -o wide
  echo
  echo '## Benchmark resources'
  kubectl -n storage-benchmark-rwx get pvc,pv,pod,job -l storage.compaan.io/backend=piraeus-rwx -o wide
  echo
  echo '## Piraeus Kubernetes resources'
  kubectl -n piraeus-datastore get pods,svc,linstorcluster,linstorsatellite -o wide
  echo
  echo '## LINSTOR nodes'
  kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor node list
  echo
  echo '## LINSTOR storage pools'
  kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor storage-pool list
  echo
  echo '## LINSTOR resources and volumes'
  kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor resource list-volumes
  echo
  echo '## Piraeus NFS/Reactor resources visible in Kubernetes'
  kubectl -n piraeus-datastore get pod,svc -o wide | grep -Ei 'nfs|reactor|rwx|linstor-csi' || true
  echo
  echo '## PVC YAML'
  kubectl -n storage-benchmark-rwx get pvc piraeus-rwx-pvc-run-001 -o yaml
} > docs/storage-benchmark-rwx/piraeus-rwx-run-001-health.md

grep -Ei 'nfs|reactor|ReadWriteMany|piraeus-rwx' docs/storage-benchmark-rwx/piraeus-rwx-run-001-health.md
```

Expected: health captures the LINSTOR/Piraeus state and visible RWX/NFS/Reactor resources.

- [ ] **Step 6: Remove Piraeus apps from bootstrap and commit results**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
remove = [
    '  - ../../base/piraeus-operator\n',
    '  - ../../base/storage-benchmark-rwx-piraeus\n',
]
text = path.read_text()
for line in remove:
    if line not in text:
        raise SystemExit(f'{line.strip()} is not active')
    text = text.replace(line, '')
path.write_text(text)
PY

kubectl kustomize argocd/homelab/apps > /tmp/homelab-apps-after-piraeus-rwx.yaml
if grep -qE 'piraeus-operator|storage-benchmark-rwx-piraeus' /tmp/homelab-apps-after-piraeus-rwx.yaml; then
  echo 'unexpected piraeus rwx app still rendered'
  exit 1
fi

git add \
  argocd/homelab/apps/kustomization.yaml \
  docs/storage-benchmark-rwx/piraeus-rwx-run-001.log \
  docs/storage-benchmark-rwx/piraeus-rwx-run-001-summary.md \
  docs/storage-benchmark-rwx/piraeus-rwx-run-001-health.md
git commit -m "docs(storage): add piraeus rwx benchmark results"
```

Expected: cleanup/result commit succeeds. After it reaches `main`, ArgoCD prunes Piraeus benchmark resources.

---

### Task 4: Activate, run, capture, and prune Mayastor-backed RWX

**Files:**
- Modify: `argocd/homelab/apps/kustomization.yaml`
- Create: `docs/storage-benchmark-rwx/mayastor-rwx-run-001.log`
- Create: `docs/storage-benchmark-rwx/mayastor-rwx-run-001-summary.md`
- Create: `docs/storage-benchmark-rwx/mayastor-rwx-run-001-health.md`

**Interfaces:**
- Consumes: dormant Mayastor app and NFS CSI app from Task 1.
- Produces: Mayastor-backed RWX artifacts used by Task 5.

- [ ] **Step 1: Activate OpenEBS Mayastor, NFS CSI, and Mayastor RWX benchmark apps**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
text = path.read_text()
anchor = '  - ../../base/local-path-provisioner\n'
insert = (
    '  - ../../base/openebs-mayastor\n'
    '  - ../../base/csi-driver-nfs-rwx-benchmark\n'
    '  - ../../base/storage-benchmark-rwx-mayastor\n'
)
if '  - ../../base/storage-benchmark-rwx-mayastor\n' not in text:
    if anchor not in text:
        raise SystemExit('missing local-path-provisioner anchor')
    text = text.replace(anchor, anchor + insert)
path.write_text(text)
PY

kubectl kustomize argocd/homelab/apps > /tmp/homelab-apps-mayastor-rwx.yaml
grep -n 'name: openebs-mayastor' /tmp/homelab-apps-mayastor-rwx.yaml
grep -n 'name: csi-driver-nfs-rwx-benchmark' /tmp/homelab-apps-mayastor-rwx.yaml
grep -n 'name: storage-benchmark-rwx-mayastor' /tmp/homelab-apps-mayastor-rwx.yaml
```

Expected: rendered root app includes all three required apps.

- [ ] **Step 2: Commit and publish the Mayastor activation**

Run:

```bash
git add argocd/homelab/apps/kustomization.yaml
git commit -m "feat(storage): activate mayastor rwx benchmark"
```

Expected: commit succeeds. Then get the activation commit onto GitOps `main` using the normal signed/hooked path.

- [ ] **Step 3: Wait for Mayastor, NFS server, proof pods, and fio jobs**

After the activation commit reaches `main`, run:

```bash
kubectl -n argocd get applications openebs-mayastor csi-driver-nfs-rwx-benchmark storage-benchmark-rwx-mayastor -o wide
kubectl -n openebs get diskpools.openebs.io -o wide
kubectl -n csi-nfs get pod,svc -o wide
kubectl -n storage-benchmark-rwx get pvc,svc,deploy,pod,job -l storage.compaan.io/backend=mayastor-rwx -o wide
kubectl -n storage-benchmark-rwx rollout status deploy/mayastor-rwx-nfs-server --timeout=20m
kubectl -n storage-benchmark-rwx wait --for=condition=Ready pod/mayastor-rwx-proof-a --timeout=20m
kubectl -n storage-benchmark-rwx wait --for=condition=Ready pod/mayastor-rwx-proof-b --timeout=20m
kubectl -n storage-benchmark-rwx logs pod/mayastor-rwx-proof-a --tail=20
kubectl -n storage-benchmark-rwx logs pod/mayastor-rwx-proof-b --tail=20
kubectl -n storage-benchmark-rwx wait --for=condition=complete job/mayastor-rwx-single --timeout=5h
kubectl -n storage-benchmark-rwx wait --for=condition=complete job/mayastor-rwx-concurrent-a --timeout=5h
kubectl -n storage-benchmark-rwx wait --for=condition=complete job/mayastor-rwx-concurrent-b --timeout=5h
```

Expected: DiskPools are Online/Healthy, NFS server rollout succeeds, proof logs show both markers, and all fio jobs complete.

- [ ] **Step 4: Capture Mayastor logs and summary**

Run:

```bash
mkdir -p docs/storage-benchmark-rwx
{
  echo '# mayastor-rwx proof logs'
  kubectl -n storage-benchmark-rwx logs pod/mayastor-rwx-proof-a --tail=80
  kubectl -n storage-benchmark-rwx logs pod/mayastor-rwx-proof-b --tail=80
  echo '# mayastor-rwx single fio'
  kubectl -n storage-benchmark-rwx logs job/mayastor-rwx-single
  echo '# mayastor-rwx concurrent fio client-a'
  kubectl -n storage-benchmark-rwx logs job/mayastor-rwx-concurrent-a
  echo '# mayastor-rwx concurrent fio client-b'
  kubectl -n storage-benchmark-rwx logs job/mayastor-rwx-concurrent-b
} > docs/storage-benchmark-rwx/mayastor-rwx-run-001.log

grep -c '^RESULT,' docs/storage-benchmark-rwx/mayastor-rwx-run-001.log
python3 scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-rwx/mayastor-rwx-run-001.log \
  > docs/storage-benchmark-rwx/mayastor-rwx-run-001-summary.md
```

Expected: `grep -c '^RESULT,'` prints `42` and summary has 12 Mayastor rows.

- [ ] **Step 5: Capture Mayastor/NFS health**

Run:

```bash
{
  echo '# Mayastor-backed RWX run 001 health'
  echo
  echo "Captured: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo '## ArgoCD applications'
  kubectl -n argocd get applications openebs-mayastor csi-driver-nfs-rwx-benchmark storage-benchmark-rwx-mayastor -o wide
  echo
  echo '## DiskPools'
  kubectl -n openebs get diskpools.openebs.io -o wide
  echo
  echo '## NFS CSI driver'
  kubectl -n csi-nfs get pod,svc -o wide
  kubectl get storageclass mayastor-rwx-nfs-csi -o yaml
  echo
  echo '## Benchmark and NFS resources'
  kubectl -n storage-benchmark-rwx get pvc,pv,svc,deploy,pod,job -l storage.compaan.io/backend=mayastor-rwx -o wide
  echo
  echo '## NFS backend PVC YAML'
  kubectl -n storage-benchmark-rwx get pvc mayastor-rwx-nfs-backend-pvc-run-001 -o yaml
  echo
  echo '## RWX PVC YAML'
  kubectl -n storage-benchmark-rwx get pvc mayastor-rwx-pvc-run-001 -o yaml
  echo
  echo '## Mayastor VolumeAttachments'
  kubectl get volumeattachments.storage.k8s.io -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.attacher}{"\t"}{.spec.nodeName}{"\t"}{.spec.source.persistentVolumeName}{"\t"}{.status.attached}{"\n"}{end}' \
    | awk '$2 ~ /mayastor|nfs/ {print}'
  echo
  echo '## Problem pods'
  kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers || true
} > docs/storage-benchmark-rwx/mayastor-rwx-run-001-health.md

grep -Ei 'mayastor-rwx-nfs|nfs.csi.k8s.io|io.openebs.csi-mayastor|ReadWriteMany' docs/storage-benchmark-rwx/mayastor-rwx-run-001-health.md
```

Expected: health clearly shows Mayastor-backed RWO PVC, NFS server, NFS CSI StorageClass, and benchmark RWX PVC.

- [ ] **Step 6: Remove Mayastor/NFS apps from bootstrap and commit results**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
remove = [
    '  - ../../base/openebs-mayastor\n',
    '  - ../../base/csi-driver-nfs-rwx-benchmark\n',
    '  - ../../base/storage-benchmark-rwx-mayastor\n',
]
text = path.read_text()
for line in remove:
    if line not in text:
        raise SystemExit(f'{line.strip()} is not active')
    text = text.replace(line, '')
path.write_text(text)
PY

kubectl kustomize argocd/homelab/apps > /tmp/homelab-apps-after-mayastor-rwx.yaml
if grep -qE 'openebs-mayastor|csi-driver-nfs-rwx-benchmark|storage-benchmark-rwx-mayastor' /tmp/homelab-apps-after-mayastor-rwx.yaml; then
  echo 'unexpected mayastor rwx app still rendered'
  exit 1
fi

git add \
  argocd/homelab/apps/kustomization.yaml \
  docs/storage-benchmark-rwx/mayastor-rwx-run-001.log \
  docs/storage-benchmark-rwx/mayastor-rwx-run-001-summary.md \
  docs/storage-benchmark-rwx/mayastor-rwx-run-001-health.md
git commit -m "docs(storage): add mayastor rwx benchmark results"
```

Expected: cleanup/result commit succeeds. After it reaches `main`, ArgoCD prunes Mayastor benchmark, NFS server, and NFS CSI benchmark resources.

---

### Task 5: Publish combined RWX comparison

**Files:**
- Create: `docs/storage-benchmark-rwx/combined-summary.md`
- Create: `docs/storage-benchmark-rwx/final-comparison.md`
- Modify: `TODO-a708536c` status through the todo tool after verification

**Interfaces:**
- Consumes: per-backend logs/summaries/health artifacts from Tasks 2-4.
- Produces: final comparison and completed handoff.

- [ ] **Step 1: Generate combined summary**

Run:

```bash
python3 scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-rwx/longhorn-rwx-run-001.log \
  docs/storage-benchmark-rwx/piraeus-rwx-run-001.log \
  docs/storage-benchmark-rwx/mayastor-rwx-run-001.log \
  > docs/storage-benchmark-rwx/combined-summary.md

grep -c '^| longhorn-rwx-' docs/storage-benchmark-rwx/combined-summary.md
grep -c '^| piraeus-rwx-' docs/storage-benchmark-rwx/combined-summary.md
grep -c '^| mayastor-rwx-' docs/storage-benchmark-rwx/combined-summary.md
```

Expected: each `grep -c` prints `12`.

- [ ] **Step 2: Generate final comparison markdown**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

combined_path = Path('docs/storage-benchmark-rwx/combined-summary.md')
final_path = Path('docs/storage-benchmark-rwx/final-comparison.md')
lines = combined_path.read_text().splitlines()
rows = []
header = []
for line in lines:
    if not line.startswith('|') or line.startswith('| ---'):
        continue
    cells = [cell.strip() for cell in line.strip('|').split('|')]
    if cells[0] == 'backend':
        header = cells
    else:
        rows.append(dict(zip(header, cells, strict=True)))

profiles = [
    ('seq-read-1m', 'read_mib_s_avg', 'higher'),
    ('seq-write-1m', 'write_mib_s_avg', 'higher'),
    ('rand-read-4k', 'read_iops_avg', 'higher'),
    ('rand-write-4k', 'write_iops_avg', 'higher'),
    ('randrw-4k-70r30w', 'write_iops_avg', 'higher'),
    ('sync-write-4k', 'write_iops_avg', 'higher'),
]
latency_profiles = [
    ('seq-read-1m', 'read_p99_ms_avg'),
    ('seq-write-1m', 'write_p99_ms_avg'),
    ('rand-read-4k', 'read_p99_ms_avg'),
    ('rand-write-4k', 'write_p99_ms_avg'),
    ('randrw-4k-70r30w', 'write_p99_ms_avg'),
    ('sync-write-4k', 'write_p99_ms_avg'),
]

def f(row, key):
    return float(row[key])

def mode_rows(mode, profile):
    suffix = f'-{mode}'
    return [r for r in rows if r['backend'].endswith(suffix) and r['profile'] == profile]

def best_line(mode, profile, metric, lower=False):
    group = mode_rows(mode, profile)
    group = [r for r in group if f(r, metric) > 0 or lower]
    if not group:
        return f'- `{profile}` {metric}: no comparable rows.'
    best = sorted(group, key=lambda r: f(r, metric), reverse=not lower)[0]
    direction = 'lowest' if lower else 'highest'
    return f"- `{profile}` {direction} `{metric}`: `{best['backend']}` at {best[metric]}."

summary = []
summary.append('# RWX Storage Benchmark Final Comparison')
summary.append('')
summary.append('## Scope')
summary.append('')
summary.append('- Provider-native RWX paths: Longhorn share-manager NFS, Piraeus LINSTOR CSI RWX, and Mayastor-backed NFS via NFS CSI.')
summary.append('- Single-client rows use 5 passes per profile.')
summary.append('- Concurrent rows use two client pods on different nodes and report per-client averages under concurrent load, not aggregate cluster throughput.')
summary.append('- Results are RWX-path behavior and include NFS-like layers; they are not raw block-device results.')
summary.append('')
summary.append('## Combined Summary')
summary.append('')
summary.extend(lines)
summary.append('')
summary.append('## Single-client throughput winners')
summary.append('')
for profile, metric, _ in profiles:
    summary.append(best_line('single', profile, metric))
summary.append('')
summary.append('## Single-client p99 latency winners')
summary.append('')
for profile, metric in latency_profiles:
    summary.append(best_line('single', profile, metric, lower=True))
summary.append('')
summary.append('## Concurrent per-client throughput winners')
summary.append('')
for profile, metric, _ in profiles:
    summary.append(best_line('concurrent', profile, metric))
summary.append('')
summary.append('## Concurrent per-client p99 latency winners')
summary.append('')
for profile, metric in latency_profiles:
    summary.append(best_line('concurrent', profile, metric, lower=True))
summary.append('')
summary.append('## Interpretation notes')
summary.append('')
summary.append('- Longhorn RWX uses Longhorn share-manager NFS. Check `longhorn-rwx-run-001-health.md` for share-manager and replica placement evidence.')
summary.append('- Piraeus RWX uses the LINSTOR CSI RWX path, which LINBIT documents as NFS plus DRBD Reactor under the hood. Check `piraeus-rwx-run-001-health.md` for visible NFS/Reactor resources.')
summary.append('- Mayastor RWX is Mayastor-backed NFS using an NFS server pod and NFS CSI. Check `mayastor-rwx-run-001-health.md` for the backend PVC, NFS server, and NFS CSI StorageClass evidence.')
summary.append('')
summary.append('## Recommendation')
summary.append('')
summary.append('Use the single-client winners for normal one-writer app behavior, and use the concurrent rows only when the target app truly has multiple RWX clients writing at once. Prefer the backend with acceptable p99 write latency over peak throughput if the app is latency-sensitive.')
summary.append('')
final_path.write_text('\n'.join(summary))
PY
```

Expected: `docs/storage-benchmark-rwx/final-comparison.md` is created and contains throughput and p99 latency sections for both single-client and concurrent modes.

- [ ] **Step 3: Final verification**

Run:

```bash
python3 scripts/test_summarize_storage_benchmark.py
python3 scripts/test-just-targets.py

for file in \
  docs/storage-benchmark-rwx/longhorn-rwx-run-001-summary.md \
  docs/storage-benchmark-rwx/piraeus-rwx-run-001-summary.md \
  docs/storage-benchmark-rwx/mayastor-rwx-run-001-summary.md \
  docs/storage-benchmark-rwx/combined-summary.md \
  docs/storage-benchmark-rwx/final-comparison.md; do
  test -s "$file"
done

grep -n 'Provider-native RWX paths' docs/storage-benchmark-rwx/final-comparison.md
grep -n 'Single-client p99 latency winners' docs/storage-benchmark-rwx/final-comparison.md
grep -n 'Concurrent per-client p99 latency winners' docs/storage-benchmark-rwx/final-comparison.md
kubectl kustomize argocd/homelab/apps > /tmp/homelab-apps-after-rwx-benchmark.yaml
if grep -qE 'storage-benchmark-rwx-|csi-driver-nfs-rwx-benchmark|piraeus-operator|openebs-mayastor' /tmp/homelab-apps-after-rwx-benchmark.yaml; then
  echo 'unexpected temporary rwx benchmark app still rendered'
  exit 1
fi
```

Expected: tests pass, all result docs exist, final comparison has required sections, and no temporary RWX benchmark app renders in the bootstrap bundle.

- [ ] **Step 4: Commit final comparison**

Run:

```bash
git add \
  docs/storage-benchmark-rwx/combined-summary.md \
  docs/storage-benchmark-rwx/final-comparison.md
git commit -m "docs(storage): compare rwx benchmark results"
```

Expected: commit succeeds.

- [ ] **Step 5: Close the todo**

Run through the todo tool, not SQLite or manual file edits:

```text
todo(action="update", id="TODO-a708536c", status="closed", body="RWX benchmark complete. Artifacts: docs/storage-benchmark-rwx/. Final comparison: docs/storage-benchmark-rwx/final-comparison.md.")
```

Expected: `TODO-a708536c` is closed only after manifests are pruned through GitOps and final artifacts are committed.

---

## Plan Self-Review

- Spec coverage: provider-native RWX backends, multi-attach proof, single-client fio, two-client concurrent fio, health placement captures, GitOps-only activation, pruning, and result docs are each covered by tasks above.
- Placeholder scan: no placeholder values are required; exact app names, StorageClass names, paths, nodes, chart version, and artifact names are specified.
- Type/name consistency: backend labels and artifact prefixes use `longhorn-rwx`, `piraeus-rwx`, and `mayastor-rwx` consistently; summary backend names add `-single` or `-concurrent` through the fio script.
