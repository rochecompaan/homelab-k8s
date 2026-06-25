# Storage Benchmark v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run a performance-only benchmark v2 comparing existing `local-path`, 3-replica Mayastor, and 3-replica LINSTOR/Piraeus on the fixed fio consumer node `fordyce`.

**Architecture:** Add v2-specific dormant ArgoCD benchmark apps and resource paths, one per backend, while reusing the existing operator app wrappers for Mayastor and Piraeus. Each run uses a fresh 20 GiB PVC, a 16 GiB fio test file, five measured passes per profile, and the same fio command shape. Activate and disable one backend at a time through GitOps only.

**Tech Stack:** Kubernetes manifests, Kustomize, ArgoCD Applications, local-path-provisioner, OpenEBS Replicated PV Mayastor, LINSTOR/Piraeus, fio, jq, existing `scripts/summarize-storage-benchmark.py`, read-only `kubectl`, SSH read-only host inspection, optional approved host-side `lvremove` cleanup.

---

## File structure

Create these v2-specific files and leave the v1 benchmark worktree untouched:

- `docs/storage-benchmark-v2/.gitkeep` — placeholder for v2 artifacts.
- `argocd/base/storage-benchmark-v2-local-path/kustomization.yaml` — base wrapper for local-path benchmark app.
- `argocd/base/storage-benchmark-v2-local-path/app.yaml` — dormant ArgoCD Application for the local-path v2 benchmark.
- `argocd/homelab/storage-benchmark-v2-local-path/kustomization.yaml` — local-path v2 resources.
- `argocd/homelab/storage-benchmark-v2-local-path/namespace.yaml` — `storage-benchmark-v2` namespace.
- `argocd/homelab/storage-benchmark-v2-local-path/pvc.yaml` — local-path v2 PVC.
- `argocd/homelab/storage-benchmark-v2-local-path/fio-job.yaml` — local-path v2 fio Job pinned to `fordyce`.
- `argocd/base/storage-benchmark-v2-mayastor/kustomization.yaml` — base wrapper for Mayastor v2 benchmark app.
- `argocd/base/storage-benchmark-v2-mayastor/app.yaml` — dormant ArgoCD Application for Mayastor v2 benchmark resources.
- `argocd/homelab/storage-benchmark-v2-mayastor/kustomization.yaml` — Mayastor v2 resources.
- `argocd/homelab/storage-benchmark-v2-mayastor/namespace.yaml` — `storage-benchmark-v2` namespace.
- `argocd/homelab/storage-benchmark-v2-mayastor/diskpools.yaml` — Mayastor DiskPools using the existing raw benchmark LVs.
- `argocd/homelab/storage-benchmark-v2-mayastor/storageclass.yaml` — `mayastor-bench-v2-3r` StorageClass.
- `argocd/homelab/storage-benchmark-v2-mayastor/pvc.yaml` — Mayastor v2 PVC.
- `argocd/homelab/storage-benchmark-v2-mayastor/fio-job.yaml` — Mayastor v2 fio Job pinned to `fordyce`.
- `argocd/base/storage-benchmark-v2-piraeus/kustomization.yaml` — base wrapper for Piraeus v2 benchmark app.
- `argocd/base/storage-benchmark-v2-piraeus/app.yaml` — dormant ArgoCD Application for Piraeus v2 benchmark resources.
- `argocd/homelab/storage-benchmark-v2-piraeus/kustomization.yaml` — Piraeus v2 resources.
- `argocd/homelab/storage-benchmark-v2-piraeus/namespace.yaml` — `storage-benchmark-v2` namespace.
- `argocd/homelab/storage-benchmark-v2-piraeus/linstor-cluster.yaml` — LINSTOR cluster and satellite configuration using existing thin pools.
- `argocd/homelab/storage-benchmark-v2-piraeus/storageclass.yaml` — `piraeus-bench-v2-3r` StorageClass.
- `argocd/homelab/storage-benchmark-v2-piraeus/pvc.yaml` — Piraeus v2 PVC.
- `argocd/homelab/storage-benchmark-v2-piraeus/fio-job.yaml` — Piraeus v2 fio Job pinned to `fordyce`.
- `argocd/homelab/apps/kustomization.yaml` — modified only during activation/disablement commits.

No new automated tests are required for static benchmark YAML. Existing summarizer tests remain valuable and should still be run.

---

## Shared fio command block

Use this exact shell command body in each v2 `fio-job.yaml`; only `BACKEND` differs by backend:

```sh
echo "RESULT_HEADER,backend,profile,pass,read_iops,write_iops,read_mib_s,write_mib_s,read_mean_ms,write_mean_ms,read_p95_ms,write_p95_ms,read_p99_ms,write_p99_ms,read_p999_ms,write_p999_ms,errors"

PASSES="${PASSES:-5}"
FIO_SIZE="${FIO_SIZE:-16G}"
FIO_RUNTIME="${FIO_RUNTIME:-60}"
FIO_RAMP="${FIO_RAMP:-10}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
result_dir="/volume/results/${BACKEND}/${timestamp}"
mkdir -p "${result_dir}"

fio \
  --name=warmup \
  --filename=/volume/fio-test-file \
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
    --filename=/volume/fio-test-file \
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
  run_profile seq-write-1m "${pass}" write 1m
  run_profile seq-read-1m "${pass}" read 1m
  run_profile rand-write-4k "${pass}" randwrite 4k
  run_profile rand-read-4k "${pass}" randread 4k
  run_profile randrw-4k-70r30w "${pass}" randrw 4k 70
  run_profile sync-write-4k "${pass}" write 4k "" 1
done
```

---

### Task 1: Preflight the v2 workspace and live cluster

**Files:**
- Read only: repository and cluster state

- [ ] **Step 1: Confirm the v2 worktree and branch**

Run:

```bash
cd /home/roche/homelab-k8s/.worktrees/storage-benchmark-v2
git status -sb
git branch --show-current
git rev-parse --short HEAD
```

Expected:

```text
## feature/storage-benchmark-v2
feature/storage-benchmark-v2
```

The third command prints the current short commit SHA for the worktree; record it in the task notes.

- [ ] **Step 2: Confirm the old benchmark worktree remains for reference**

Run:

```bash
git -C /home/roche/homelab-k8s worktree list | grep storage-benchmark
```

Expected: both `.worktrees/storage-benchmark` and `.worktrees/storage-benchmark-v2` are listed.

- [ ] **Step 3: Check live cluster benchmark leftovers, read-only**

Run:

```bash
export KUBECONFIG=/home/roche/homelab-k8s/.kubeconfig
kubectl -n argocd get applications.argoproj.io \
  openebs-mayastor mayastor-benchmark piraeus-operator piraeus-benchmark \
  --ignore-not-found
kubectl get ns storage-benchmark storage-benchmark-v2 piraeus-datastore --ignore-not-found
kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.storageClassName}{"\t"}{.status.phase}{"\t"}{.spec.claimRef.namespace}{"/"}{.spec.claimRef.name}{"\n"}{end}' \
  | awk '$2 ~ /(mayastor|linstor|piraeus|bench)/ {print}'
kubectl get volumeattachments.storage.k8s.io -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.attacher}{"\t"}{.spec.nodeName}{"\t"}{.spec.source.persistentVolumeName}{"\t"}{.status.attached}{"\n"}{end}' \
  | awk '$2 ~ /(mayastor|linbit|linstor|piraeus)/ {print}'
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers || true
```

Expected:

- old Mayastor/Piraeus benchmark Applications are absent
- `storage-benchmark-v2` does not exist yet
- no Mayastor/Piraeus benchmark PVs or VolumeAttachments are listed
- no unrelated cluster problem pods are present

- [ ] **Step 4: Check host capacity and stale benchmark LVs, read-only**

Run:

```bash
for host in dauwalter:192.168.1.100 fordyce:192.168.1.102 selassie:192.168.1.104; do
  name=${host%%:*}
  ip=${host##*:}
  echo "## ${name}"
  ssh -o BatchMode=yes -o ConnectTimeout=5 "roche@${ip}" \
    "sudo lvs --noheadings -o vg_name,lv_name,lv_size,lv_attr 2>/dev/null | grep -E 'vg-nvme|mayastor-bench|linstor-bench|pvc-' || true"
done
ssh roche@192.168.1.102 'df -h /var/local-path-provisioner /opt/local-path-provisioner 2>/dev/null || df -h /'
```

Expected:

- all three selected nodes have `vg-nvme/mayastor-bench` and `vg-nvme/linstor-bench-thin`
- `fordyce` has enough free local-path space for a 20 GiB PVC
- stale `pvc-fac962ee-369f-46d4-a67a-645feed28492_00000` thin volumes may appear on `fordyce` and `selassie`; record them and do not delete yet

---

### Task 2: Add the dormant local-path v2 benchmark app

**Files:**
- Create: `docs/storage-benchmark-v2/.gitkeep`
- Create: `argocd/base/storage-benchmark-v2-local-path/kustomization.yaml`
- Create: `argocd/base/storage-benchmark-v2-local-path/app.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-local-path/kustomization.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-local-path/namespace.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-local-path/pvc.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-local-path/fio-job.yaml`

- [ ] **Step 1: Create directories**

Run:

```bash
cd /home/roche/homelab-k8s/.worktrees/storage-benchmark-v2
mkdir -p docs/storage-benchmark-v2 \
  argocd/base/storage-benchmark-v2-local-path \
  argocd/homelab/storage-benchmark-v2-local-path
touch docs/storage-benchmark-v2/.gitkeep
```

Expected: command exits `0`.

- [ ] **Step 2: Create the base kustomization**

Write `argocd/base/storage-benchmark-v2-local-path/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
  - app.yaml
```

- [ ] **Step 3: Create the dormant local-path ArgoCD Application**

Write `argocd/base/storage-benchmark-v2-local-path/app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: storage-benchmark-v2-local-path
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: git@github.com:rochecompaan/homelab-k8s.git
    targetRevision: main
    path: argocd/homelab/storage-benchmark-v2-local-path
  destination:
    server: https://kubernetes.default.svc
    namespace: storage-benchmark-v2
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 4: Create the local-path homelab kustomization**

Write `argocd/homelab/storage-benchmark-v2-local-path/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - pvc.yaml
  - fio-job.yaml
```

- [ ] **Step 5: Create the namespace manifest**

Write `argocd/homelab/storage-benchmark-v2-local-path/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: storage-benchmark-v2
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
```

- [ ] **Step 6: Create the local-path PVC**

Write `argocd/homelab/storage-benchmark-v2-local-path/pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-path-fio-pvc-v2-run-001
  namespace: storage-benchmark-v2
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    app.kubernetes.io/name: storage-benchmark-v2
    storage.compaan.io/backend: local-path
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 20Gi
```

- [ ] **Step 7: Create the local-path fio Job**

Write `argocd/homelab/storage-benchmark-v2-local-path/fio-job.yaml` with:

- Job name `storage-bench-local-path-v2-run-001`
- namespace `storage-benchmark-v2`
- sync wave `1`
- label `storage.compaan.io/backend: local-path`
- `activeDeadlineSeconds: 14400`
- `backoffLimit: 0`
- pod `nodeSelector.kubernetes.io/hostname: fordyce`
- image `nixery.dev/shell/fio/jq/coreutils`
- env `BACKEND=local-path`, `PASSES=5`, `FIO_SIZE=16G`, `FIO_RUNTIME=60`, `FIO_RAMP=10`
- command body exactly from the shared fio command block
- PVC mount `local-path-fio-pvc-v2-run-001` at `/volume`

- [ ] **Step 8: Verify dormant local-path render**

Run:

```bash
kubectl kustomize argocd/base/storage-benchmark-v2-local-path >/tmp/storage-benchmark-v2-local-path-app.yaml
kubectl kustomize argocd/homelab/storage-benchmark-v2-local-path >/tmp/storage-benchmark-v2-local-path.yaml
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-root-before-local-path.yaml
python3 - <<'PY'
from pathlib import Path
app = Path('/tmp/storage-benchmark-v2-local-path-app.yaml').read_text()
body = Path('/tmp/storage-benchmark-v2-local-path.yaml').read_text()
root = Path('/tmp/storage-benchmark-v2-root-before-local-path.yaml').read_text()
assert 'name: storage-benchmark-v2-local-path' in app
assert 'resources-finalizer.argocd.argoproj.io' in app
assert 'name: local-path-fio-pvc-v2-run-001' in body
assert 'storageClassName: local-path' in body
assert 'kubernetes.io/hostname: fordyce' in body
assert 'FIO_SIZE' in body and '16G' in body
assert 'name: storage-benchmark-v2-local-path' not in root
print('local-path v2 benchmark app is dormant and renders')
PY
```

Expected: `local-path v2 benchmark app is dormant and renders`.

- [ ] **Step 9: Commit local-path dormant app**

Run:

```bash
git add docs/storage-benchmark-v2/.gitkeep \
  argocd/base/storage-benchmark-v2-local-path \
  argocd/homelab/storage-benchmark-v2-local-path
git commit -m "feat(storage): add local-path benchmark v2 manifests"
```

Expected: commit succeeds.

---

### Task 3: Add the dormant Mayastor v2 benchmark app

**Files:**
- Create: `argocd/base/storage-benchmark-v2-mayastor/kustomization.yaml`
- Create: `argocd/base/storage-benchmark-v2-mayastor/app.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-mayastor/kustomization.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-mayastor/namespace.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-mayastor/diskpools.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-mayastor/storageclass.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-mayastor/pvc.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-mayastor/fio-job.yaml`

- [ ] **Step 1: Create directories**

Run:

```bash
mkdir -p argocd/base/storage-benchmark-v2-mayastor \
  argocd/homelab/storage-benchmark-v2-mayastor
```

Expected: command exits `0`.

- [ ] **Step 2: Create the base kustomization**

Write `argocd/base/storage-benchmark-v2-mayastor/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
  - app.yaml
```

- [ ] **Step 3: Create the dormant Mayastor ArgoCD Application**

Write `argocd/base/storage-benchmark-v2-mayastor/app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: storage-benchmark-v2-mayastor
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: git@github.com:rochecompaan/homelab-k8s.git
    targetRevision: main
    path: argocd/homelab/storage-benchmark-v2-mayastor
  destination:
    server: https://kubernetes.default.svc
    namespace: storage-benchmark-v2
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 4: Create the Mayastor homelab kustomization**

Write `argocd/homelab/storage-benchmark-v2-mayastor/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - diskpools.yaml
  - storageclass.yaml
  - pvc.yaml
  - fio-job.yaml
```

- [ ] **Step 5: Create Mayastor namespace, DiskPools, StorageClass, and PVC**

Use the v1 Mayastor manifests as the source pattern, but with these exact v2 names and values:

- namespace: `storage-benchmark-v2`
- DiskPools:
  - `mayastor-bench-v2-dauwalter`, node `dauwalter`, disk `aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench`
  - `mayastor-bench-v2-fordyce`, node `fordyce`, disk `aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench`
  - `mayastor-bench-v2-selassie`, node `selassie`, disk `aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench`
- StorageClass: `mayastor-bench-v2-3r`
  - `provisioner: io.openebs.csi-mayastor`
  - `volumeBindingMode: WaitForFirstConsumer`
  - `reclaimPolicy: Delete`
  - `parameters.repl: "3"`
  - `parameters.protocol: nvmf`
- PVC: `mayastor-fio-pvc-v2-run-001`
  - namespace `storage-benchmark-v2`
  - storageClassName `mayastor-bench-v2-3r`
  - request `20Gi`

- [ ] **Step 6: Create the Mayastor fio Job**

Write `argocd/homelab/storage-benchmark-v2-mayastor/fio-job.yaml` with:

- Job name `storage-bench-mayastor-v2-run-001`
- namespace `storage-benchmark-v2`
- label `storage.compaan.io/backend: mayastor`
- `activeDeadlineSeconds: 14400`
- `backoffLimit: 0`
- pod `nodeSelector.kubernetes.io/hostname: fordyce`
- image `nixery.dev/shell/fio/jq/coreutils`
- env `BACKEND=mayastor`, `PASSES=5`, `FIO_SIZE=16G`, `FIO_RUNTIME=60`, `FIO_RAMP=10`
- command body exactly from the shared fio command block
- PVC mount `mayastor-fio-pvc-v2-run-001` at `/volume`

- [ ] **Step 7: Verify dormant Mayastor render**

Run:

```bash
kubectl kustomize argocd/base/storage-benchmark-v2-mayastor >/tmp/storage-benchmark-v2-mayastor-app.yaml
kubectl kustomize argocd/homelab/storage-benchmark-v2-mayastor >/tmp/storage-benchmark-v2-mayastor.yaml
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-root-before-mayastor.yaml
python3 - <<'PY'
from pathlib import Path
app = Path('/tmp/storage-benchmark-v2-mayastor-app.yaml').read_text()
body = Path('/tmp/storage-benchmark-v2-mayastor.yaml').read_text()
root = Path('/tmp/storage-benchmark-v2-root-before-mayastor.yaml').read_text()
assert 'name: storage-benchmark-v2-mayastor' in app
assert 'resources-finalizer.argocd.argoproj.io' in app
assert 'name: mayastor-bench-v2-3r' in body
assert 'name: mayastor-fio-pvc-v2-run-001' in body
assert 'name: storage-bench-mayastor-v2-run-001' in body
assert 'kubernetes.io/hostname: fordyce' in body
assert 'FIO_SIZE' in body and '16G' in body
assert 'name: storage-benchmark-v2-mayastor' not in root
print('Mayastor v2 benchmark app is dormant and renders')
PY
```

Expected: `Mayastor v2 benchmark app is dormant and renders`.

- [ ] **Step 8: Commit Mayastor dormant app**

Run:

```bash
git add argocd/base/storage-benchmark-v2-mayastor \
  argocd/homelab/storage-benchmark-v2-mayastor
git commit -m "feat(storage): add Mayastor benchmark v2 manifests"
```

Expected: commit succeeds.

---

### Task 4: Add the dormant Piraeus v2 benchmark app

**Files:**
- Create: `argocd/base/storage-benchmark-v2-piraeus/kustomization.yaml`
- Create: `argocd/base/storage-benchmark-v2-piraeus/app.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-piraeus/kustomization.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-piraeus/namespace.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-piraeus/linstor-cluster.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-piraeus/storageclass.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-piraeus/pvc.yaml`
- Create: `argocd/homelab/storage-benchmark-v2-piraeus/fio-job.yaml`

- [ ] **Step 1: Create directories**

Run:

```bash
mkdir -p argocd/base/storage-benchmark-v2-piraeus \
  argocd/homelab/storage-benchmark-v2-piraeus
```

Expected: command exits `0`.

- [ ] **Step 2: Create the base kustomization**

Write `argocd/base/storage-benchmark-v2-piraeus/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
  - app.yaml
```

- [ ] **Step 3: Create the dormant Piraeus ArgoCD Application**

Write `argocd/base/storage-benchmark-v2-piraeus/app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: storage-benchmark-v2-piraeus
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: git@github.com:rochecompaan/homelab-k8s.git
    targetRevision: main
    path: argocd/homelab/storage-benchmark-v2-piraeus
  destination:
    server: https://kubernetes.default.svc
    namespace: storage-benchmark-v2
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 4: Create the Piraeus homelab kustomization**

Write `argocd/homelab/storage-benchmark-v2-piraeus/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - linstor-cluster.yaml
  - storageclass.yaml
  - pvc.yaml
  - fio-job.yaml
```

- [ ] **Step 5: Create Piraeus namespace, LINSTOR config, StorageClass, and PVC**

Use the v1 Piraeus manifests as the source pattern, but with these exact v2 names and values:

- namespace: `storage-benchmark-v2`
- `LinstorCluster`: keep the v1 working chart-compatible spec, including the `/usr/src` `DirectoryOrCreate` pod template override
- `LinstorSatelliteConfiguration`: select nodes with `storage.compaan.io/linstor-benchmark: "true"`
- storage pool:
  - name `linstor-bench`
  - provider `lvmThinPool`
  - volume group `vg-nvme`
  - thin pool `linstor-bench-thin`
- StorageClass: `piraeus-bench-v2-3r`
  - `provisioner: linstor.csi.linbit.com`
  - `volumeBindingMode: WaitForFirstConsumer`
  - `reclaimPolicy: Delete`
  - `parameters.linstor.csi.linbit.com/storagePool: linstor-bench`
  - `parameters.linstor.csi.linbit.com/placementCount: "3"`
- PVC: `piraeus-fio-pvc-v2-run-001`
  - namespace `storage-benchmark-v2`
  - storageClassName `piraeus-bench-v2-3r`
  - request `20Gi`

- [ ] **Step 6: Create the Piraeus fio Job**

Write `argocd/homelab/storage-benchmark-v2-piraeus/fio-job.yaml` with:

- Job name `storage-bench-piraeus-v2-run-001`
- namespace `storage-benchmark-v2`
- label `storage.compaan.io/backend: piraeus`
- `activeDeadlineSeconds: 14400`
- `backoffLimit: 0`
- pod `nodeSelector.kubernetes.io/hostname: fordyce`
- image `nixery.dev/shell/fio/jq/coreutils`
- env `BACKEND=piraeus`, `PASSES=5`, `FIO_SIZE=16G`, `FIO_RUNTIME=60`, `FIO_RAMP=10`
- command body exactly from the shared fio command block
- PVC mount `piraeus-fio-pvc-v2-run-001` at `/volume`

- [ ] **Step 7: Verify dormant Piraeus render**

Run:

```bash
kubectl kustomize argocd/base/storage-benchmark-v2-piraeus >/tmp/storage-benchmark-v2-piraeus-app.yaml
kubectl kustomize argocd/homelab/storage-benchmark-v2-piraeus >/tmp/storage-benchmark-v2-piraeus.yaml
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-root-before-piraeus.yaml
python3 - <<'PY'
from pathlib import Path
app = Path('/tmp/storage-benchmark-v2-piraeus-app.yaml').read_text()
body = Path('/tmp/storage-benchmark-v2-piraeus.yaml').read_text()
root = Path('/tmp/storage-benchmark-v2-root-before-piraeus.yaml').read_text()
assert 'name: storage-benchmark-v2-piraeus' in app
assert 'resources-finalizer.argocd.argoproj.io' in app
assert 'DirectoryOrCreate' in body and '/usr/src' in body
assert 'linstor-bench-thin' in body
assert 'name: piraeus-bench-v2-3r' in body
assert 'name: piraeus-fio-pvc-v2-run-001' in body
assert 'name: storage-bench-piraeus-v2-run-001' in body
assert 'kubernetes.io/hostname: fordyce' in body
assert 'name: storage-benchmark-v2-piraeus' not in root
print('Piraeus v2 benchmark app is dormant and renders')
PY
```

Expected: `Piraeus v2 benchmark app is dormant and renders`.

- [ ] **Step 8: Commit Piraeus dormant app**

Run:

```bash
git add argocd/base/storage-benchmark-v2-piraeus \
  argocd/homelab/storage-benchmark-v2-piraeus
git commit -m "feat(storage): add Piraeus benchmark v2 manifests"
```

Expected: commit succeeds.

---

### Task 5: Run and record the local-path reference benchmark

**Files:**
- Modify during activation: `argocd/homelab/apps/kustomization.yaml`
- Create: `docs/storage-benchmark-v2/local-path-run-001.log`
- Create: `docs/storage-benchmark-v2/local-path-run-001-summary.md`
- Create: `docs/storage-benchmark-v2/local-path-run-001-health.md`

- [ ] **Step 1: Activate only the local-path v2 app in GitOps**

Edit `argocd/homelab/apps/kustomization.yaml` and add:

```yaml
  - ../../base/storage-benchmark-v2-local-path
```

Do not add Mayastor or Piraeus v2 apps in this commit.

- [ ] **Step 2: Verify activation render**

Run:

```bash
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-local-path-root.yaml
python3 - <<'PY'
from pathlib import Path
root = Path('/tmp/storage-benchmark-v2-local-path-root.yaml').read_text()
assert 'name: storage-benchmark-v2-local-path' in root
assert 'name: storage-benchmark-v2-mayastor' not in root
assert 'name: storage-benchmark-v2-piraeus' not in root
assert 'name: openebs-mayastor' not in root
assert 'name: piraeus-operator' not in root
print('only local-path v2 app is active')
PY
```

Expected: `only local-path v2 app is active`.

- [ ] **Step 3: Commit local-path activation**

Run:

```bash
git add argocd/homelab/apps/kustomization.yaml
git commit -m "feat(storage): enable local-path benchmark v2"
```

Expected: commit succeeds.

- [ ] **Step 4: Stop for explicit push approval**

Ask the operator for this exact approval phrase before pushing to the watched GitOps branch:

```text
push local-path benchmark v2 activation
```

Do not push without approval.

- [ ] **Step 5: After approval, push/merge the activation to watched `main`**

Use the repository's normal GitOps flow. One acceptable flow is:

```bash
cd /home/roche/homelab-k8s
git fetch origin main
git status -sb
git merge --ff-only feature/storage-benchmark-v2
git push origin main
```

Expected: push succeeds and ArgoCD reconciles `storage-benchmark-v2-local-path`.

- [ ] **Step 6: Monitor local-path job read-only**

Run:

```bash
export KUBECONFIG=/home/roche/homelab-k8s/.kubeconfig
kubectl -n argocd get application storage-benchmark-v2-local-path -o wide
kubectl -n storage-benchmark-v2 get pvc,pod,job -o wide
kubectl -n storage-benchmark-v2 logs job/storage-bench-local-path-v2-run-001 --tail=-1 | tee docs/storage-benchmark-v2/local-path-run-001.log
```

Expected:

- PVC `local-path-fio-pvc-v2-run-001` is Bound
- Job `storage-bench-local-path-v2-run-001` completes successfully
- pod ran on `fordyce`
- log contains 30 `RESULT,` rows: 6 profiles x 5 passes

- [ ] **Step 7: Summarize local-path results**

Run:

```bash
scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-v2/local-path-run-001.log \
  | tee docs/storage-benchmark-v2/local-path-run-001-summary.md
```

Expected: summary includes 6 rows for backend `local-path` and `errors_total=0` for each profile.

- [ ] **Step 8: Record local-path health**

Run:

```bash
{
  echo '# local-path benchmark v2 health'
  echo
  echo '## ArgoCD application'
  kubectl -n argocd get application storage-benchmark-v2-local-path -o wide
  echo
  echo '## Benchmark resources'
  kubectl -n storage-benchmark-v2 get pvc,pod,job -o wide
  echo
  echo '## Selected PV'
  kubectl get pv -o wide | grep local-path-fio-pvc-v2-run-001 || true
  echo
  echo '## Problem pods'
  kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers || true
} | tee docs/storage-benchmark-v2/local-path-run-001-health.md
```

Expected: health file records completed job and no problem pods.

- [ ] **Step 9: Commit local-path results**

Run:

```bash
git add docs/storage-benchmark-v2/local-path-run-001.log \
  docs/storage-benchmark-v2/local-path-run-001-summary.md \
  docs/storage-benchmark-v2/local-path-run-001-health.md
git commit -m "perf(storage): record local-path benchmark v2 results"
```

Expected: commit succeeds.

- [ ] **Step 10: Disable local-path v2 app through GitOps**

Remove `../../base/storage-benchmark-v2-local-path` from `argocd/homelab/apps/kustomization.yaml`, render to confirm it is absent, commit:

```bash
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-local-path-disabled.yaml
python3 - <<'PY'
from pathlib import Path
root = Path('/tmp/storage-benchmark-v2-local-path-disabled.yaml').read_text()
assert 'name: storage-benchmark-v2-local-path' not in root
print('local-path v2 app disabled in desired state')
PY
git add argocd/homelab/apps/kustomization.yaml
git commit -m "chore(storage): disable local-path benchmark v2"
```

Expected: commit succeeds. Push only after explicit approval phrase `push local-path benchmark v2 disablement`, then verify the app and namespace are gone.

---

### Task 6: Run and record the Mayastor v2 benchmark

**Files:**
- Modify during activation/disablement: `argocd/homelab/apps/kustomization.yaml`
- Create: `docs/storage-benchmark-v2/mayastor-v2-run-001.log`
- Create: `docs/storage-benchmark-v2/mayastor-v2-run-001-summary.md`
- Create: `docs/storage-benchmark-v2/mayastor-v2-run-001-health.md`

- [ ] **Step 1: Activate Mayastor operator and Mayastor v2 benchmark apps**

Edit `argocd/homelab/apps/kustomization.yaml` and add:

```yaml
  - ../../base/openebs-mayastor
  - ../../base/storage-benchmark-v2-mayastor
```

Do not add local-path or Piraeus v2 apps in this activation commit.

- [ ] **Step 2: Verify Mayastor activation render**

Run:

```bash
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-mayastor-root.yaml
python3 - <<'PY'
from pathlib import Path
root = Path('/tmp/storage-benchmark-v2-mayastor-root.yaml').read_text()
assert 'name: openebs-mayastor' in root
assert 'name: storage-benchmark-v2-mayastor' in root
assert 'name: storage-benchmark-v2-local-path' not in root
assert 'name: storage-benchmark-v2-piraeus' not in root
assert 'name: piraeus-operator' not in root
print('only Mayastor v2 benchmark path is active')
PY
```

Expected: `only Mayastor v2 benchmark path is active`.

- [ ] **Step 3: Commit Mayastor activation**

Run:

```bash
git add argocd/homelab/apps/kustomization.yaml
git commit -m "feat(storage): enable Mayastor benchmark v2"
```

Expected: commit succeeds.

- [ ] **Step 4: Stop for explicit push approval**

Ask for approval phrase:

```text
push Mayastor benchmark v2 activation
```

Do not push without approval.

- [ ] **Step 5: Monitor Mayastor job read-only after push**

Run:

```bash
export KUBECONFIG=/home/roche/homelab-k8s/.kubeconfig
kubectl -n argocd get applications openebs-mayastor storage-benchmark-v2-mayastor -o wide
kubectl -n openebs get diskpools.openebs.io -o wide
kubectl -n storage-benchmark-v2 get pvc,pod,job -o wide
kubectl -n storage-benchmark-v2 logs job/storage-bench-mayastor-v2-run-001 --tail=-1 | tee docs/storage-benchmark-v2/mayastor-v2-run-001.log
```

Expected:

- DiskPools are Online/Healthy
- PVC `mayastor-fio-pvc-v2-run-001` is Bound
- Job completes successfully on `fordyce`
- log contains 30 `RESULT,` rows

- [ ] **Step 6: Summarize Mayastor results**

Run:

```bash
scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-v2/mayastor-v2-run-001.log \
  | tee docs/storage-benchmark-v2/mayastor-v2-run-001-summary.md
```

Expected: summary includes 6 Mayastor rows and `errors_total=0` for each profile.

- [ ] **Step 7: Record Mayastor health**

Run:

```bash
{
  echo '# Mayastor benchmark v2 health'
  echo
  echo '## ArgoCD applications'
  kubectl -n argocd get applications openebs-mayastor storage-benchmark-v2-mayastor -o wide
  echo
  echo '## DiskPools'
  kubectl -n openebs get diskpools.openebs.io -o wide
  echo
  echo '## Benchmark resources'
  kubectl -n storage-benchmark-v2 get pvc,pod,job -o wide
  echo
  echo '## Mayastor VolumeAttachments'
  kubectl get volumeattachments.storage.k8s.io -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.attacher}{"\t"}{.spec.nodeName}{"\t"}{.spec.source.persistentVolumeName}{"\t"}{.status.attached}{"\n"}{end}' \
    | awk '$2 ~ /mayastor/ {print}'
  echo
  echo '## Problem pods'
  kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers || true
} | tee docs/storage-benchmark-v2/mayastor-v2-run-001-health.md
```

Expected: health file records completed job, attached Mayastor volume, healthy pools, and no problem pods.

- [ ] **Step 8: Commit Mayastor results**

Run:

```bash
git add docs/storage-benchmark-v2/mayastor-v2-run-001.log \
  docs/storage-benchmark-v2/mayastor-v2-run-001-summary.md \
  docs/storage-benchmark-v2/mayastor-v2-run-001-health.md
git commit -m "perf(storage): record Mayastor benchmark v2 results"
```

Expected: commit succeeds.

- [ ] **Step 9: Disable Mayastor v2 through GitOps**

Remove both Mayastor activation entries:

```yaml
  - ../../base/openebs-mayastor
  - ../../base/storage-benchmark-v2-mayastor
```

Render to confirm absence, commit:

```bash
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-mayastor-disabled.yaml
python3 - <<'PY'
from pathlib import Path
root = Path('/tmp/storage-benchmark-v2-mayastor-disabled.yaml').read_text()
assert 'name: openebs-mayastor' not in root
assert 'name: storage-benchmark-v2-mayastor' not in root
print('Mayastor v2 apps disabled in desired state')
PY
git add argocd/homelab/apps/kustomization.yaml
git commit -m "chore(storage): disable Mayastor benchmark v2"
```

Expected: commit succeeds. Push only after explicit approval phrase `push Mayastor benchmark v2 disablement`, then verify Mayastor v2 apps/resources are gone before Piraeus work.

---

### Task 7: Gate stale LINSTOR host-volume cleanup before Piraeus v2

**Files:**
- No repository changes unless recording a cleanup note is useful

- [ ] **Step 1: Confirm no Kubernetes references to the old Piraeus v1 PVC remain**

Run:

```bash
export KUBECONFIG=/home/roche/homelab-k8s/.kubeconfig
old=pvc-fac962ee-369f-46d4-a67a-645feed28492
kubectl get pv,pvc -A -o wide | grep "${old}" || true
kubectl get volumeattachments.storage.k8s.io -o wide | grep "${old}" || true
kubectl get pods -A -o wide | grep "${old}" || true
```

Expected: no output.

- [ ] **Step 2: Confirm stale host LVs exactly**

Run:

```bash
for host in fordyce:192.168.1.102 selassie:192.168.1.104; do
  name=${host%%:*}
  ip=${host##*:}
  echo "## ${name}"
  ssh "roche@${ip}" \
    "sudo lvs vg-nvme -o lv_name,lv_size,pool_lv,origin,lv_attr | grep pvc-fac962ee-369f-46d4-a67a-645feed28492_00000 || true"
done
```

Expected: stale `10.00g` thin volumes may be present on `fordyce` and `selassie`.

- [ ] **Step 3: Stop for explicit destructive host-cleanup approval if stale LVs remain**

If the stale LVs remain, ask for this exact approval phrase before deleting them:

```text
remove stale Piraeus v1 benchmark LVs
```

Do not run `lvremove` without approval.

- [ ] **Step 4: If approved, remove only the stale v1 benchmark LVs**

Run only after approval:

```bash
ssh roche@192.168.1.102 \
  'sudo lvremove -y /dev/vg-nvme/pvc-fac962ee-369f-46d4-a67a-645feed28492_00000'
ssh roche@192.168.1.104 \
  'sudo lvremove -y /dev/vg-nvme/pvc-fac962ee-369f-46d4-a67a-645feed28492_00000'
```

Expected: each command reports successful logical volume removal. If either LV is already absent, record that and continue.

- [ ] **Step 5: Re-check thin pool capacity**

Run:

```bash
for host in dauwalter:192.168.1.100 fordyce:192.168.1.102 selassie:192.168.1.104; do
  name=${host%%:*}
  ip=${host##*:}
  echo "## ${name}"
  ssh "roche@${ip}" \
    "sudo lvs vg-nvme -o lv_name,lv_size,data_percent,metadata_percent,lv_attr | grep linstor-bench-thin"
done
```

Expected: all three `linstor-bench-thin` pools have enough free capacity for a 20 GiB replicated volume.

---

### Task 8: Run and record the Piraeus v2 benchmark

**Files:**
- Modify during activation/disablement: `argocd/homelab/apps/kustomization.yaml`
- Create: `docs/storage-benchmark-v2/piraeus-v2-run-001.log`
- Create: `docs/storage-benchmark-v2/piraeus-v2-run-001-summary.md`
- Create: `docs/storage-benchmark-v2/piraeus-v2-run-001-health.md`

- [ ] **Step 1: Activate Piraeus operator and Piraeus v2 benchmark apps**

Edit `argocd/homelab/apps/kustomization.yaml` and add:

```yaml
  - ../../base/piraeus-operator
  - ../../base/storage-benchmark-v2-piraeus
```

Do not add local-path or Mayastor v2 apps in this activation commit.

- [ ] **Step 2: Verify Piraeus activation render**

Run:

```bash
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-piraeus-root.yaml
python3 - <<'PY'
from pathlib import Path
root = Path('/tmp/storage-benchmark-v2-piraeus-root.yaml').read_text()
assert 'name: piraeus-operator' in root
assert 'name: storage-benchmark-v2-piraeus' in root
assert 'name: storage-benchmark-v2-local-path' not in root
assert 'name: storage-benchmark-v2-mayastor' not in root
assert 'name: openebs-mayastor' not in root
print('only Piraeus v2 benchmark path is active')
PY
```

Expected: `only Piraeus v2 benchmark path is active`.

- [ ] **Step 3: Commit Piraeus activation**

Run:

```bash
git add argocd/homelab/apps/kustomization.yaml
git commit -m "feat(storage): enable Piraeus benchmark v2"
```

Expected: commit succeeds.

- [ ] **Step 4: Stop for explicit push approval**

Ask for approval phrase:

```text
push Piraeus benchmark v2 activation
```

Do not push without approval.

- [ ] **Step 5: Monitor Piraeus job read-only after push**

Run:

```bash
export KUBECONFIG=/home/roche/homelab-k8s/.kubeconfig
kubectl -n argocd get applications piraeus-operator storage-benchmark-v2-piraeus -o wide
kubectl -n piraeus-datastore get linstorcluster,linstorsatellite -o wide
kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor node list
kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor storage-pool list
kubectl -n storage-benchmark-v2 get pvc,pod,job -o wide
kubectl -n storage-benchmark-v2 logs job/storage-bench-piraeus-v2-run-001 --tail=-1 | tee docs/storage-benchmark-v2/piraeus-v2-run-001.log
```

Expected:

- LINSTOR satellites `dauwalter`, `fordyce`, and `selassie` are Online
- storage pools `linstor-bench` are Ok
- PVC `piraeus-fio-pvc-v2-run-001` is Bound
- Job completes successfully on `fordyce`
- log contains 30 `RESULT,` rows

- [ ] **Step 6: Summarize Piraeus results**

Run:

```bash
scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-v2/piraeus-v2-run-001.log \
  | tee docs/storage-benchmark-v2/piraeus-v2-run-001-summary.md
```

Expected: summary includes 6 Piraeus rows and `errors_total=0` for each profile.

- [ ] **Step 7: Record Piraeus health**

Run:

```bash
{
  echo '# Piraeus benchmark v2 health'
  echo
  echo '## ArgoCD applications'
  kubectl -n argocd get applications piraeus-operator storage-benchmark-v2-piraeus -o wide
  echo
  echo '## LINSTOR cluster CRs'
  kubectl -n piraeus-datastore get linstorcluster,linstorsatellite -o wide
  echo
  echo '## LINSTOR nodes'
  kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor node list
  echo
  echo '## LINSTOR storage pools'
  kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor storage-pool list
  echo
  echo '## LINSTOR resource volumes'
  kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor resource list-volumes
  echo
  echo '## Benchmark resources'
  kubectl -n storage-benchmark-v2 get pvc,pod,job -o wide
  echo
  echo '## Problem pods'
  kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers || true
} | tee docs/storage-benchmark-v2/piraeus-v2-run-001-health.md
```

Expected: health file records completed job, online satellites, UpToDate replicas, and no problem pods.

- [ ] **Step 8: Commit Piraeus results**

Run:

```bash
git add docs/storage-benchmark-v2/piraeus-v2-run-001.log \
  docs/storage-benchmark-v2/piraeus-v2-run-001-summary.md \
  docs/storage-benchmark-v2/piraeus-v2-run-001-health.md
git commit -m "perf(storage): record Piraeus benchmark v2 results"
```

Expected: commit succeeds.

- [ ] **Step 9: Disable Piraeus v2 through GitOps**

Remove both Piraeus activation entries:

```yaml
  - ../../base/piraeus-operator
  - ../../base/storage-benchmark-v2-piraeus
```

Render to confirm absence, commit:

```bash
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-piraeus-disabled.yaml
python3 - <<'PY'
from pathlib import Path
root = Path('/tmp/storage-benchmark-v2-piraeus-disabled.yaml').read_text()
assert 'name: piraeus-operator' not in root
assert 'name: storage-benchmark-v2-piraeus' not in root
print('Piraeus v2 apps disabled in desired state')
PY
git add argocd/homelab/apps/kustomization.yaml
git commit -m "chore(storage): disable Piraeus benchmark v2"
```

Expected: commit succeeds. Push only after explicit approval phrase `push Piraeus benchmark v2 disablement`, then verify Piraeus v2 apps/resources are gone.

---

### Task 9: Produce the benchmark v2 comparison

**Files:**
- Create: `docs/storage-benchmark-v2/combined-summary.md`
- Create: `docs/storage-benchmark-v2/final-comparison.md`

- [ ] **Step 1: Generate combined summary**

Run:

```bash
scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-v2/local-path-run-001.log \
  docs/storage-benchmark-v2/mayastor-v2-run-001.log \
  docs/storage-benchmark-v2/piraeus-v2-run-001.log \
  | tee docs/storage-benchmark-v2/combined-summary.md
```

Expected: combined summary has 18 rows total: 6 profiles x 3 backends.

- [ ] **Step 2: Write final comparison**

Create `docs/storage-benchmark-v2/final-comparison.md` with this structure:

```markdown
# Storage Benchmark v2 Final Comparison

## Scope

- Performance-only trial
- Fixed fio consumer node: `fordyce`
- Backends: existing `local-path`, 3-replica Mayastor, 3-replica LINSTOR/Piraeus
- PVC size: 20 GiB
- fio file size: 16 GiB
- passes: 5 per profile

## Performance Summary

Paste `docs/storage-benchmark-v2/combined-summary.md` here.

## Plain-English Findings

Summarize read, write, sequential, random, and mixed-workload behavior.

## Validation Against v1

Compare the v2 Mayastor and Piraeus results against v1:

- `docs/storage-benchmark/mayastor-run-001-summary.md`
- `docs/storage-benchmark/piraeus-run-002-summary.md`

State whether the surprising Mayastor write advantage repeated, narrowed, reversed, or appears inconclusive.

## local-path Reference

Explain local-path as a non-replicated local-node baseline, not as an HA candidate.

## Recommendation

Choose one of:

- keep deferring replicated-storage migration
- proceed with one non-critical app trial on Mayastor
- proceed with one non-critical app trial on LINSTOR/Piraeus

Only recommend a backend if v2 confirms the performance pattern and operational risk is acceptable.

## Remaining Gates Before Production App-State Migration

- monitoring and alerting
- documented restore path
- non-critical app migration trial
- rollback instructions
- cleanup rehearsal
```

- [ ] **Step 3: Verify comparison completeness**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('docs/storage-benchmark-v2/final-comparison.md').read_text()
for forbidden in ['UNFILLED_MARKER', 'PLACEHOLDER_MARKER', '|  |']:
    assert forbidden not in text, forbidden
assert 'local-path' in text
assert 'mayastor' in text.lower()
assert 'piraeus' in text.lower()
print('benchmark v2 comparison has no placeholders')
PY
```

Expected: `benchmark v2 comparison has no placeholders`.

- [ ] **Step 4: Commit comparison artifacts**

Run:

```bash
git add docs/storage-benchmark-v2/combined-summary.md \
  docs/storage-benchmark-v2/final-comparison.md
git commit -m "docs(storage): compare benchmark v2 results"
```

Expected: commit succeeds.

---

### Task 10: Final cleanup verification and handoff

**Files:**
- Optional create: `docs/storage-benchmark-v2/cleanup-verification.md`

- [ ] **Step 1: Verify desired GitOps state excludes all v2 benchmark apps**

Run:

```bash
kubectl kustomize argocd/homelab/apps >/tmp/storage-benchmark-v2-final-root.yaml
python3 - <<'PY'
from pathlib import Path
root = Path('/tmp/storage-benchmark-v2-final-root.yaml').read_text()
for name in [
    'storage-benchmark-v2-local-path',
    'storage-benchmark-v2-mayastor',
    'storage-benchmark-v2-piraeus',
    'openebs-mayastor',
    'piraeus-operator',
]:
    assert f'name: {name}' not in root, name
print('all benchmark v2 apps disabled in desired state')
PY
```

Expected: `all benchmark v2 apps disabled in desired state`.

- [ ] **Step 2: Verify live cluster cleanup read-only**

Run:

```bash
export KUBECONFIG=/home/roche/homelab-k8s/.kubeconfig
kubectl -n argocd get applications.argoproj.io \
  storage-benchmark-v2-local-path storage-benchmark-v2-mayastor storage-benchmark-v2-piraeus \
  openebs-mayastor piraeus-operator \
  --ignore-not-found
kubectl get ns storage-benchmark-v2 --ignore-not-found
kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.storageClassName}{"\t"}{.status.phase}{"\t"}{.spec.claimRef.namespace}{"/"}{.spec.claimRef.name}{"\n"}{end}' \
  | awk '$2 ~ /(mayastor|linstor|piraeus|bench-v2|local-path)/ && $4 ~ /storage-benchmark-v2/ {print}'
kubectl get volumeattachments.storage.k8s.io -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.attacher}{"\t"}{.spec.nodeName}{"\t"}{.spec.source.persistentVolumeName}{"\t"}{.status.attached}{"\n"}{end}' \
  | awk '$2 ~ /(mayastor|linbit|linstor|piraeus)/ {print}'
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers || true
```

Expected:

- v2 benchmark apps are absent
- `storage-benchmark-v2` namespace is absent or empty
- no v2 PVs or VolumeAttachments remain
- no problem pods

- [ ] **Step 3: Record cleanup verification if there are residuals**

If any residuals remain, create `docs/storage-benchmark-v2/cleanup-verification.md` with:

```markdown
# Storage Benchmark v2 Cleanup Verification

## Date

Run timestamp: paste the output of `date -u +%Y-%m-%dT%H:%M:%SZ` from the verification shell.

## Desired State

Paste root render and app absence evidence.

## Live State

Paste namespace, PV, PVC, VolumeAttachment, and problem-pod evidence.

## Residuals

List each residual object and whether it is harmless, expected, or requires explicit cleanup approval.
```

After writing the file with the actual timestamp and evidence, commit:

```bash
git add docs/storage-benchmark-v2/cleanup-verification.md
git commit -m "docs(storage): record benchmark v2 cleanup state"
```

Expected: commit succeeds if the file is needed. If there are no residuals, skip this commit and note the clean verification in the final response.

---

## Testing and verification policy

Do not add new automated tests for static ArgoCD YAML. Use direct verification instead:

- `kubectl kustomize` for every new app wrapper and homelab v2 path
- semantic assertions with Python for finalizers, dormant app state, fixed node selector, PVC sizes, and backend names
- existing summarizer tests:
  - `python3 -m unittest scripts/test_summarize_storage_benchmark.py`
  - `python3 -m py_compile scripts/summarize-storage-benchmark.py scripts/test_summarize_storage_benchmark.py`
- read-only Kubernetes/backend inspection during live runs
- SSH read-only host inspection for LVM capacity and stale volumes

Host-side destructive cleanup requires explicit approval. Kubernetes writes must remain GitOps-only.

## Rollback plan

- To stop a v2 benchmark app, remove only that app's base entry from `argocd/homelab/apps/kustomization.yaml`, commit, push, and allow ArgoCD to prune it.
- For Mayastor, remove `storage-benchmark-v2-mayastor` before removing `openebs-mayastor` if cleanup appears stuck.
- For Piraeus, remove `storage-benchmark-v2-piraeus` before removing `piraeus-operator` if cleanup appears stuck.
- Do not manually delete Kubernetes PVs, PVCs, DiskPools, Linstor resources, or Helm releases unless the operator explicitly approves a direct cleanup exception.
- If host-side LVs are left by a failed Piraeus cleanup, stop, document the exact LV names and Kubernetes references, and request explicit approval before any `lvremove`.
