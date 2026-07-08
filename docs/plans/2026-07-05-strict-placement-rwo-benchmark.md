# Strict-placement RWO Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and run a replicated RWO read-after-write benchmark where `fordyce` writes the fio test file and separate reader Jobs on `dauwalter` and `selassie` measure read-only performance.

**Architecture:** Add dormant ArgoCD applications for Piraeus/LINSTOR, Longhorn NVMe, and Mayastor strict RWO benchmarks. Each app owns a PVC, fio script ConfigMap, writer Job, and one reader Job file per reader node so GitOps can activate phases sequentially without RWO multi-attach races. Execute Longhorn and Mayastor before Piraeus/LINSTOR so the Piraeus/LINSTOR benchmark runs last. Capture raw logs, placement evidence, summaries, and a final comparison under `docs/storage-benchmark-rwo-strict/`.

**Tech Stack:** Kubernetes batch Jobs, ArgoCD Applications, Kustomize, fio, jq, shell scripts, existing `scripts/summarize-storage-benchmark.py`, Markdown documentation.

## Global Constraints

- Use only replicated/migratable RWO backends: `piraeus`, `longhorn-nvme`, and `mayastor`.
- Do not rerun `local-path`; original local-path v2 results remain the local baseline.
- Writer node is always `fordyce`.
- Reader nodes are `dauwalter` and `selassie`.
- Writer must fully write `/volume/fio-test-file` with `--direct=1`, `--rw=write`, `--bs=1m`, and `--size=16G`.
- Reader Jobs must run read-only profiles only: `seq-read-1m` and `rand-read-4k`.
- Reader results are different-consumer-node reads with locality allowed, not cold remote/no-replica reads.
- Run benchmark execution in this backend order: Longhorn NVMe, Mayastor, then Piraeus/LINSTOR last.
- ArgoCD sync/prune polling must stop after at most 5 minutes to inspect Application status. If sync is stuck, stop polling, make Git fixes, and only then terminate the stuck ArgoCD operation through approved ArgoCD controls.
- Benchmark Job polling must stop after at most 10 minutes to inspect Job, pod, and log progress before starting another polling interval.
- Do not run direct-write cluster commands such as `kubectl apply`, `kubectl patch`, `kubectl delete`, or `helm upgrade`.
- Cluster state changes must be made in this repo and delivered through Git so ArgoCD reconciles them.
- New ArgoCD Applications stay dormant by default; do not add them to `argocd/homelab/apps/kustomization.yaml` in the manifest implementation commits.
- All dormant manifest, validation, and runbook work happens first in the `strict-placement-rwo-benchmark` worktree branch and then pauses for review.
- Do not point ArgoCD at the worktree branch. Keep every generated `Application.spec.source.targetRevision` set to `main`.
- After review approval, merge the reviewed dormant app/runbook commits to `main` while the apps remain dormant.
- Only after the dormant apps are on `main`, run activation, reader-enable, artifact, and cleanup commits directly on `main` so ArgoCD reconciles the branch it already tracks.
- Use direct validation instead of new automated tests for static Kubernetes manifest content.

---

## Branch integration and ArgoCD target

Implementation has two phases:

1. **Review phase in the worktree:** create dormant benchmark apps, validation changes, and docs in the `strict-placement-rwo-benchmark` worktree branch. Stop after Task 3 for review. Do not activate ArgoCD apps from the worktree branch.
2. **GitOps execution phase on `main`:** after review approval, merge the dormant-app work into `main` while the new apps remain absent from `argocd/homelab/apps/kustomization.yaml`. Perform Task 4 and later as signed commits on `main`, because every generated ArgoCD `Application` keeps `targetRevision: main`.

Do not change `targetRevision` to the worktree branch. Branch-targeted ArgoCD testing would require a separate explicit plan and cleanup step.

---

## File Structure

Create these dormant app definitions:

- `argocd/base/storage-benchmark-rwo-strict-piraeus/app.yaml`: ArgoCD Application pointing to the Piraeus strict RWO homelab path.
- `argocd/base/storage-benchmark-rwo-strict-piraeus/kustomization.yaml`: Kustomize wrapper for the Piraeus Application.
- `argocd/base/storage-benchmark-rwo-strict-longhorn/app.yaml`: ArgoCD Application pointing to the Longhorn strict RWO homelab path.
- `argocd/base/storage-benchmark-rwo-strict-longhorn/kustomization.yaml`: Kustomize wrapper for the Longhorn Application.
- `argocd/base/storage-benchmark-rwo-strict-mayastor/app.yaml`: ArgoCD Application pointing to the Mayastor strict RWO homelab path.
- `argocd/base/storage-benchmark-rwo-strict-mayastor/kustomization.yaml`: Kustomize wrapper for the Mayastor Application.

Create these backend manifest directories:

- `argocd/homelab/storage-benchmark-rwo-strict-piraeus/`: namespace, Piraeus/LINSTOR setup, StorageClass, PVC, fio script, writer Job, per-node reader Jobs, writer-phase kustomization.
- `argocd/homelab/storage-benchmark-rwo-strict-longhorn/`: namespace, Longhorn NVMe disk tagger resources, StorageClass, PVC, fio script, writer Job, per-node reader Jobs, writer-phase kustomization.
- `argocd/homelab/storage-benchmark-rwo-strict-mayastor/`: namespace, Mayastor DiskPools, StorageClass, PVC, fio script, writer Job, per-node reader Jobs, writer-phase kustomization.

Create documentation and artifact paths:

- `docs/storage-benchmark-rwo-strict/README.md`: benchmark purpose, methodology, and artifact index.
- `docs/storage-benchmark-rwo-strict/runbook.md`: GitOps activation, read-only evidence capture commands, summarization commands, and cleanup steps.
- `docs/storage-benchmark-rwo-strict/.gitkeep`: keeps the artifact directory present before run logs are captured.
- Later run artifacts: `docs/storage-benchmark-rwo-strict/*-run-001.log`, `*-health.md`, `*-summary.md`, `placement-audit.md`, and `final-comparison.md`.

The implementation deliberately uses `reader-dauwalter-job.yaml` and `reader-selassie-job.yaml` instead of one aggregate reader manifest. This preserves the approved semantics while allowing one reader node to be enabled per GitOps commit for RWO safety.

---

### Task 1: Generate dormant strict RWO backend manifests

**Files:**
- Create: `argocd/base/storage-benchmark-rwo-strict-piraeus/app.yaml`
- Create: `argocd/base/storage-benchmark-rwo-strict-piraeus/kustomization.yaml`
- Create: `argocd/base/storage-benchmark-rwo-strict-longhorn/app.yaml`
- Create: `argocd/base/storage-benchmark-rwo-strict-longhorn/kustomization.yaml`
- Create: `argocd/base/storage-benchmark-rwo-strict-mayastor/app.yaml`
- Create: `argocd/base/storage-benchmark-rwo-strict-mayastor/kustomization.yaml`
- Create: `argocd/homelab/storage-benchmark-rwo-strict-piraeus/*`
- Create: `argocd/homelab/storage-benchmark-rwo-strict-longhorn/*`
- Create: `argocd/homelab/storage-benchmark-rwo-strict-mayastor/*`

**Interfaces:**
- Consumes: existing v2 backend settings from `argocd/homelab/storage-benchmark-v2-piraeus`, `argocd/homelab/storage-benchmark-v2-longhorn`, and `argocd/homelab/storage-benchmark-v2-mayastor`.
- Produces: dormant strict RWO ArgoCD Applications and writer-phase Kustomize builds for all three replicated RWO backends. Later tasks rely on the Job names and labels created here.

- [ ] **Step 1: Generate the manifest files**

Run this from the repository root in the task worktree:

```bash
python3 - <<'PY'
from pathlib import Path
from textwrap import dedent

ROOT = Path('.')
NAMESPACE = 'storage-benchmark-rwo-strict'
WRITER_NODE = 'fordyce'
READER_NODES = ['dauwalter', 'selassie']
IMAGE = 'nixery.dev/shell/fio/jq/coreutils'

COMMON_SCRIPT = r'''#!/bin/sh
set -eu

ROLE="${ROLE:?ROLE is required}"
BACKEND="${BACKEND:?BACKEND is required}"
PASSES="${PASSES:-5}"
FIO_SIZE="${FIO_SIZE:-16G}"
FIO_RUNTIME="${FIO_RUNTIME:-60}"
FIO_RAMP="${FIO_RAMP:-10}"
FIO_FILE="/volume/fio-test-file"

mkdir -p /volume/results

echo "RESULT_HEADER,backend,profile,pass,read_iops,write_iops,read_mib_s,write_mib_s,read_mean_ms,write_mean_ms,read_p95_ms,write_p95_ms,read_p99_ms,write_p99_ms,read_p999_ms,write_p999_ms,errors"

run_writer() {
  writer_node="${WRITER_NODE:?WRITER_NODE is required}"
  result_dir="/volume/results/${BACKEND}-writer/${writer_node}/$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "${result_dir}"

  echo "WRITER,backend=${BACKEND},writer_node=${writer_node},fio_file=${FIO_FILE},fio_size=${FIO_SIZE},result_dir=${result_dir}"

  fio \
    --name=precondition-write \
    --filename="${FIO_FILE}" \
    --rw=write \
    --bs=1m \
    --size="${FIO_SIZE}" \
    --ioengine=libaio \
    --iodepth=16 \
    --numjobs=1 \
    --direct=1 \
    --group_reporting \
    --output-format=json \
    --output="${result_dir}/precondition-write.json"

  sync
  ls -lh "${FIO_FILE}"
  echo "WRITER_COMPLETE,backend=${BACKEND},writer_node=${writer_node},fio_file=${FIO_FILE}"
}

run_profile() {
  profile="$1"
  profile_pass="$2"
  rw="$3"
  bs="$4"
  reader_node="${READER_NODE:?READER_NODE is required}"
  result_backend="${BACKEND}-rwo-strict-${reader_node}"
  result_dir="/volume/results/${result_backend}/$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "${result_dir}"
  output="${result_dir}/${profile}-pass-${profile_pass}.json"

  fio \
    --name="${profile}" \
    --filename="${FIO_FILE}" \
    --rw="${rw}" \
    --bs="${bs}" \
    --size="${FIO_SIZE}" \
    --ioengine=libaio \
    --iodepth=16 \
    --numjobs=1 \
    --direct=1 \
    --time_based \
    --runtime="${FIO_RUNTIME}" \
    --ramp_time="${FIO_RAMP}" \
    --group_reporting \
    --output-format=json \
    --output="${output}"

  jq -r --arg backend "${result_backend}" --arg profile "${profile}" --arg pass "${profile_pass}" '
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

run_reader() {
  reader_node="${READER_NODE:?READER_NODE is required}"

  if [ ! -f "${FIO_FILE}" ]; then
    echo "missing preconditioned fio file: ${FIO_FILE}" >&2
    exit 1
  fi

  ls -lh "${FIO_FILE}"
  echo "READER_START,backend=${BACKEND},reader_node=${reader_node},fio_file=${FIO_FILE}"

  for run_pass in $(seq 1 "${PASSES}"); do
    run_profile seq-read-1m "${reader_node}-${run_pass}" read 1m
    run_profile rand-read-4k "${reader_node}-${run_pass}" randread 4k
  done

  echo "READER_COMPLETE,backend=${BACKEND},reader_node=${reader_node},fio_file=${FIO_FILE}"
}

case "${ROLE}" in
  writer)
    run_writer
    ;;
  reader)
    run_reader
    ;;
  *)
    echo "ROLE must be writer or reader; got ${ROLE}" >&2
    exit 1
    ;;
esac
'''

BACKENDS = {
    'piraeus': {
        'display': 'Piraeus/LINSTOR',
        'base_name': 'storage-benchmark-rwo-strict-piraeus',
        'destination_namespace': 'piraeus-datastore',
        'pvc': 'piraeus-rwo-strict-pvc-run-001',
        'storageclass_name': 'piraeus-rwo-strict-3r',
        'storageclass': '''apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: piraeus-rwo-strict-3r
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    storage.compaan.io/benchmark: rwo-strict
    storage.compaan.io/backend: piraeus
provisioner: linstor.csi.linbit.com
allowVolumeExpansion: false
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  linstor.csi.linbit.com/storagePool: linstor-bench
  linstor.csi.linbit.com/placementCount: "3"
''',
        'support_files': ['linstor-cluster.yaml'],
    },
    'longhorn-nvme': {
        'display': 'Longhorn NVMe',
        'base_name': 'storage-benchmark-rwo-strict-longhorn',
        'destination_namespace': NAMESPACE,
        'pvc': 'longhorn-nvme-rwo-strict-pvc-run-001',
        'storageclass_name': 'longhorn-nvme-rwo-strict-3r',
        'storageclass': '''apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-nvme-rwo-strict-3r
  annotations:
    argocd.argoproj.io/sync-wave: "2"
  labels:
    storage.compaan.io/benchmark: rwo-strict
    storage.compaan.io/backend: longhorn-nvme
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
''',
        'support_files': [
            'nvme-disk-tagger-serviceaccount.yaml',
            'nvme-disk-tagger-rbac.yaml',
            'nvme-disk-tagger-configmap.yaml',
            'nvme-disk-tagger-job.yaml',
        ],
    },
    'mayastor': {
        'display': 'Mayastor',
        'base_name': 'storage-benchmark-rwo-strict-mayastor',
        'destination_namespace': NAMESPACE,
        'pvc': 'mayastor-rwo-strict-pvc-run-001',
        'storageclass_name': 'mayastor-rwo-strict-3r',
        'storageclass': '''apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mayastor-rwo-strict-3r
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    storage.compaan.io/benchmark: rwo-strict
    storage.compaan.io/backend: mayastor
provisioner: io.openebs.csi-mayastor
allowVolumeExpansion: false
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  protocol: nvmf
  repl: "3"
''',
        'support_files': ['diskpools.yaml'],
    },
}


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(dedent(text).lstrip(), encoding='utf-8')


def indent_block(text, spaces):
    prefix = ' ' * spaces
    return '\n'.join(prefix + line if line else prefix for line in text.splitlines())


def app_yaml(name, path, destination_namespace):
    return f'''apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {name}
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: '5'
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: git@github.com:rochecompaan/homelab-k8s.git
    targetRevision: main
    path: {path}
  destination:
    server: https://kubernetes.default.svc
    namespace: {destination_namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
'''


def namespace_yaml():
    return f'''apiVersion: v1
kind: Namespace
metadata:
  name: {NAMESPACE}
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwo-strict
    storage.compaan.io/benchmark: rwo-strict
'''


def pvc_yaml(backend, cfg):
    return f'''apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {cfg['pvc']}
  namespace: {NAMESPACE}
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwo-strict
    storage.compaan.io/benchmark: rwo-strict
    storage.compaan.io/backend: {backend}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: {cfg['storageclass_name']}
  resources:
    requests:
      storage: 20Gi
'''


def fio_configmap_yaml(backend):
    cm_name = f"{backend}-rwo-strict-fio-script".replace('_', '-')
    return f'''apiVersion: v1
kind: ConfigMap
metadata:
  name: {cm_name}
  namespace: {NAMESPACE}
  annotations:
    argocd.argoproj.io/sync-wave: "3"
  labels:
    app.kubernetes.io/name: storage-benchmark-rwo-strict
    storage.compaan.io/benchmark: rwo-strict
    storage.compaan.io/backend: {backend}
data:
  fio-rwo-strict.sh: |
{indent_block(COMMON_SCRIPT, 4)}
'''


def affinity_yaml(node, spaces=6):
    return indent_block(f'''affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - {node}''', spaces)


def tolerations_yaml(spaces=6):
    return indent_block('''tolerations:
  - key: drbd.linbit.com/lost-quorum
    operator: Exists
    effect: NoSchedule''', spaces)


def job_yaml(backend, cfg, phase, node):
    if phase == 'writer':
        job_name = f"{backend}-rwo-strict-writer-{node}-run-001"
        phase_env = f'''            - name: ROLE
              value: writer
            - name: WRITER_NODE
              value: {node}'''
        reader_label = ''
        wave = '4'
    else:
        job_name = f"{backend}-rwo-strict-reader-{node}-run-001"
        phase_env = f'''            - name: ROLE
              value: reader
            - name: READER_NODE
              value: {node}'''
        reader_label = f'''    storage.compaan.io/reader-node: {node}'''
        wave = '5'

    cm_name = f"{backend}-rwo-strict-fio-script".replace('_', '-')
    writer_label = f"    storage.compaan.io/writer-node: {WRITER_NODE}"
    labels = f'''    app.kubernetes.io/name: storage-benchmark-rwo-strict
    storage.compaan.io/benchmark: rwo-strict
    storage.compaan.io/backend: {backend}
    storage.compaan.io/phase: {phase}
{writer_label}
{reader_label}'''.rstrip()

    return f'''apiVersion: batch/v1
kind: Job
metadata:
  name: {job_name}
  namespace: {NAMESPACE}
  annotations:
    argocd.argoproj.io/sync-wave: "{wave}"
  labels:
{labels}
spec:
  activeDeadlineSeconds: 21600
  backoffLimit: 0
  template:
    metadata:
      labels:
{indent_block(labels, 8)}
    spec:
      restartPolicy: Never
{tolerations_yaml(6)}
{affinity_yaml(node, 6)}
      containers:
        - name: fio
          image: {IMAGE}
          env:
            - name: BACKEND
              value: {backend}
            - name: PASSES
              value: "5"
            - name: FIO_SIZE
              value: 16G
            - name: FIO_RUNTIME
              value: "60"
            - name: FIO_RAMP
              value: "10"
{phase_env}
          command: ["/bin/sh", "/scripts/fio-rwo-strict.sh"]
          volumeMounts:
            - name: data
              mountPath: /volume
            - name: script
              mountPath: /scripts
              readOnly: true
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: {cfg['pvc']}
        - name: script
          configMap:
            name: {cm_name}
            defaultMode: 0555
'''


def writer_kustomization(resources):
    lines = ['apiVersion: kustomize.config.k8s.io/v1beta1', 'kind: Kustomization', 'resources:']
    lines.extend(f'  - {name}' for name in resources)
    return '\n'.join(lines) + '\n'


def copy_support_files(backend, dst, support_files):
    if backend == 'piraeus':
        src = Path('argocd/homelab/storage-benchmark-v2-piraeus/linstor-cluster.yaml')
        write(dst / 'linstor-cluster.yaml', src.read_text(encoding='utf-8'))
    elif backend == 'mayastor':
        src = Path('argocd/homelab/storage-benchmark-v2-mayastor/diskpools.yaml')
        write(dst / 'diskpools.yaml', src.read_text(encoding='utf-8'))
    elif backend == 'longhorn-nvme':
        src_dir = Path('argocd/homelab/storage-benchmark-v2-longhorn')
        replacements = {
            'storage-benchmark-v2': 'storage-benchmark-rwo-strict',
            'longhorn-nvme-disk-tagger-20260630': 'longhorn-nvme-rwo-strict-disk-tagger-run-001',
            'longhorn-nvme-disk-tagger-script': 'longhorn-nvme-rwo-strict-disk-tagger-script',
            'longhorn-nvme-disk-tagger': 'longhorn-nvme-rwo-strict-disk-tagger',
        }
        for filename in support_files:
            text = (src_dir / filename).read_text(encoding='utf-8')
            for old, new in replacements.items():
                text = text.replace(old, new)
            write(dst / filename, text)


for backend, cfg in BACKENDS.items():
    base_dir = ROOT / 'argocd/base' / cfg['base_name']
    homelab_dir = ROOT / 'argocd/homelab' / cfg['base_name']
    rel_homelab_path = f"argocd/homelab/{cfg['base_name']}"

    write(base_dir / 'app.yaml', app_yaml(cfg['base_name'], rel_homelab_path, cfg['destination_namespace']))
    write(base_dir / 'kustomization.yaml', '''apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - app.yaml
''')

    write(homelab_dir / 'namespace.yaml', namespace_yaml())
    copy_support_files(backend, homelab_dir, cfg['support_files'])
    write(homelab_dir / 'storageclass.yaml', cfg['storageclass'])
    write(homelab_dir / 'pvc.yaml', pvc_yaml(backend, cfg))
    write(homelab_dir / 'fio-script-configmap.yaml', fio_configmap_yaml(backend))
    write(homelab_dir / 'writer-job.yaml', job_yaml(backend, cfg, 'writer', WRITER_NODE))
    for node in READER_NODES:
        write(homelab_dir / f'reader-{node}-job.yaml', job_yaml(backend, cfg, 'reader', node))

    resources = ['namespace.yaml'] + cfg['support_files'] + [
        'storageclass.yaml',
        'pvc.yaml',
        'fio-script-configmap.yaml',
        'writer-job.yaml',
    ]
    write(homelab_dir / 'kustomization.yaml', writer_kustomization(resources))
PY
```

Expected: command exits 0 and creates six new directories under `argocd/base` and `argocd/homelab`.

- [ ] **Step 2: Verify default Kustomize builds include writer Jobs only**

Run:

```bash
set -e
for app in \
  storage-benchmark-rwo-strict-piraeus \
  storage-benchmark-rwo-strict-longhorn \
  storage-benchmark-rwo-strict-mayastor
do
  kubectl kustomize "argocd/homelab/${app}" > "/tmp/${app}.yaml"
  grep -q 'storage.compaan.io/phase: writer' "/tmp/${app}.yaml"
  if grep -q 'storage.compaan.io/phase: reader' "/tmp/${app}.yaml"; then
    echo "reader job is active by default in ${app}" >&2
    exit 1
  fi
  echo "${app}: writer phase build ok"
done
```

Expected output:

```text
storage-benchmark-rwo-strict-piraeus: writer phase build ok
storage-benchmark-rwo-strict-longhorn: writer phase build ok
storage-benchmark-rwo-strict-mayastor: writer phase build ok
```

- [ ] **Step 3: Verify reader Job files exist but are dormant**

Run:

```bash
set -e
for app in \
  storage-benchmark-rwo-strict-piraeus \
  storage-benchmark-rwo-strict-longhorn \
  storage-benchmark-rwo-strict-mayastor
do
  for node in dauwalter selassie; do
    test -f "argocd/homelab/${app}/reader-${node}-job.yaml"
    grep -q "storage.compaan.io/reader-node: ${node}" "argocd/homelab/${app}/reader-${node}-job.yaml"
    echo "${app}: reader ${node} manifest present"
  done
done
```

Expected output has six lines ending in `manifest present`.

- [ ] **Step 4: Verify the bootstrap bundle does not activate new apps**

Run:

```bash
if grep -R 'storage-benchmark-rwo-strict' argocd/homelab/apps/kustomization.yaml; then
  echo 'strict RWO app is active by default' >&2
  exit 1
fi
echo 'strict RWO apps are dormant by default'
```

Expected output:

```text
strict RWO apps are dormant by default
```

- [ ] **Step 5: Commit the dormant manifests**

Run:

```bash
git add \
  argocd/base/storage-benchmark-rwo-strict-piraeus \
  argocd/base/storage-benchmark-rwo-strict-longhorn \
  argocd/base/storage-benchmark-rwo-strict-mayastor \
  argocd/homelab/storage-benchmark-rwo-strict-piraeus \
  argocd/homelab/storage-benchmark-rwo-strict-longhorn \
  argocd/homelab/storage-benchmark-rwo-strict-mayastor
git commit -m "feat(storage): add strict-placement RWO benchmark apps"
```

Expected: commit succeeds with only the new strict RWO app directories staged.

---

### Task 2: Add benchmark runbook and artifact directory

**Files:**
- Create: `docs/storage-benchmark-rwo-strict/README.md`
- Create: `docs/storage-benchmark-rwo-strict/runbook.md`
- Create: `docs/storage-benchmark-rwo-strict/.gitkeep`

**Interfaces:**
- Consumes: Job names, app names, labels, and dormant activation model from Task 1.
- Produces: operator-facing GitOps run instructions and artifact directory used by benchmark execution and reporting tasks.

- [ ] **Step 1: Create artifact directory and README**

Run:

```bash
mkdir -p docs/storage-benchmark-rwo-strict
cat > docs/storage-benchmark-rwo-strict/README.md <<'EOF'
# Strict-placement RWO Storage Benchmark

This directory contains artifacts for the replicated RWO read-after-write benchmark.

## Methodology

- Backends: Piraeus/LINSTOR RWO, Longhorn NVMe RWO, and Mayastor RWO.
- Writer node: `fordyce`.
- Reader nodes: `dauwalter` and `selassie`.
- Writer phase: a dedicated writer Job fully writes `/volume/fio-test-file` with `fio --direct=1`, `--rw=write`, `--bs=1m`, and `--size=16G`.
- Reader phase: dedicated reader Jobs run only `seq-read-1m` and `rand-read-4k`.
- Locality is allowed. A reader node with a local or up-to-date replica/resource remains valid and must be documented.
- These results are not cold remote/no-replica reads.

## Artifact naming

- Raw logs: `piraeus-writer-fordyce-run-001.log`, `longhorn-nvme-reader-dauwalter-run-001.log`, and `mayastor-reader-selassie-run-001.log` show the naming pattern.
- Health and placement evidence: `piraeus-run-001-health.md`, `longhorn-nvme-run-001-health.md`, and `mayastor-run-001-health.md`.
- Per-backend summaries: `piraeus-run-001-summary.md`, `longhorn-nvme-run-001-summary.md`, and `mayastor-run-001-summary.md`.
- Cross-backend placement audit: `placement-audit.md`.
- Final comparison: `final-comparison.md`.

Use `runbook.md` for the GitOps activation, evidence capture, summary, and cleanup procedure.
EOF
touch docs/storage-benchmark-rwo-strict/.gitkeep
```

Expected: README and `.gitkeep` exist under `docs/storage-benchmark-rwo-strict/`.

- [ ] **Step 2: Create the GitOps runbook**

Run:

```bash
cat > docs/storage-benchmark-rwo-strict/runbook.md <<'EOF'
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
EOF
```

Expected: `docs/storage-benchmark-rwo-strict/runbook.md` contains the backend map, phase activation instructions, evidence commands, summarization commands, and cleanup instructions.

- [ ] **Step 3: Verify docs mention locality and do not claim cold remote reads**

Run:

```bash
grep -q 'Locality is allowed' docs/storage-benchmark-rwo-strict/README.md
grep -q 'not cold remote/no-replica reads' docs/storage-benchmark-rwo-strict/README.md
grep -q 'Run one reader node at a time' docs/storage-benchmark-rwo-strict/runbook.md
echo 'strict RWO docs wording ok'
```

Expected output:

```text
strict RWO docs wording ok
```

- [ ] **Step 4: Commit the runbook and artifact directory**

Run:

```bash
git add docs/storage-benchmark-rwo-strict
git commit -m "docs(storage): add strict RWO benchmark runbook"
```

Expected: commit succeeds with only `docs/storage-benchmark-rwo-strict/` staged.

---

### Task 3: Validate manifests and scripts before review handoff

Stop after this task and request human review. Do not activate ArgoCD apps from the worktree branch. After review approval, merge the dormant manifest and runbook commits to `main`; only then continue with benchmark activation tasks on `main`.

**Files:**
- Read: `argocd/homelab/storage-benchmark-rwo-strict-piraeus/kustomization.yaml`
- Read: `argocd/homelab/storage-benchmark-rwo-strict-longhorn/kustomization.yaml`
- Read: `argocd/homelab/storage-benchmark-rwo-strict-mayastor/kustomization.yaml`
- Read: `argocd/homelab/storage-benchmark-rwo-strict-*/fio-script-configmap.yaml`
- Read: `scripts/summarize-storage-benchmark.py`

**Interfaces:**
- Consumes: manifests from Task 1 and docs from Task 2.
- Produces: fresh static validation evidence before any GitOps activation commit.

- [ ] **Step 1: Validate all writer-phase Kustomize builds**

Run:

```bash
set -e
for app in \
  storage-benchmark-rwo-strict-piraeus \
  storage-benchmark-rwo-strict-longhorn \
  storage-benchmark-rwo-strict-mayastor
do
  kubectl kustomize "argocd/homelab/${app}" > "/tmp/${app}.yaml"
  grep -q 'kind: Job' "/tmp/${app}.yaml"
  grep -q 'storage.compaan.io/phase: writer' "/tmp/${app}.yaml"
  grep -q 'kubernetes.io/hostname' "/tmp/${app}.yaml"
  echo "${app}: kustomize validation ok"
done
```

Expected output:

```text
storage-benchmark-rwo-strict-piraeus: kustomize validation ok
storage-benchmark-rwo-strict-longhorn: kustomize validation ok
storage-benchmark-rwo-strict-mayastor: kustomize validation ok
```

- [ ] **Step 2: Validate each reader manifest independently by temporary Kustomize files**

Run:

```bash
set -e
for app in \
  storage-benchmark-rwo-strict-piraeus \
  storage-benchmark-rwo-strict-longhorn \
  storage-benchmark-rwo-strict-mayastor
do
  for node in dauwalter selassie; do
    workdir="argocd/homelab/${app}"
    tmp="${workdir}/kustomization.reader-${node}.tmp.yaml"
    awk -v reader="reader-${node}-job.yaml" '
      { print }
      $0 == "  - writer-job.yaml" { print "  - " reader }
    ' "${workdir}/kustomization.yaml" > "${tmp}"
    cp "${workdir}/kustomization.yaml" "${workdir}/kustomization.yaml.saved"
    mv "${tmp}" "${workdir}/kustomization.yaml"
    kubectl kustomize "${workdir}" > "/tmp/${app}-${node}.yaml"
    mv "${workdir}/kustomization.yaml.saved" "${workdir}/kustomization.yaml"
    grep -q "storage.compaan.io/reader-node: ${node}" "/tmp/${app}-${node}.yaml"
    echo "${app}: reader ${node} kustomize validation ok"
  done
done
```

Expected output has six lines ending in `kustomize validation ok`.

- [ ] **Step 3: Validate fio script shell syntax from each ConfigMap**

Run:

```bash
set -e
for app in \
  storage-benchmark-rwo-strict-piraeus \
  storage-benchmark-rwo-strict-longhorn \
  storage-benchmark-rwo-strict-mayastor
do
  python3 - "$app" <<'PY'
import sys
from pathlib import Path
app = sys.argv[1]
text = Path(f'argocd/homelab/{app}/fio-script-configmap.yaml').read_text()
marker = '  fio-rwo-strict.sh: |\n'
start = text.index(marker) + len(marker)
script_lines = []
for line in text[start:].splitlines():
    if line.startswith('    '):
        script_lines.append(line[4:])
    elif not line.strip():
        script_lines.append('')
    else:
        break
Path(f'/tmp/{app}-fio-rwo-strict.sh').write_text('\n'.join(script_lines) + '\n')
PY
  sh -n "/tmp/${app}-fio-rwo-strict.sh"
  echo "${app}: fio script syntax ok"
done
```

Expected output:

```text
storage-benchmark-rwo-strict-piraeus: fio script syntax ok
storage-benchmark-rwo-strict-longhorn: fio script syntax ok
storage-benchmark-rwo-strict-mayastor: fio script syntax ok
```

- [ ] **Step 4: Verify existing summarizer still passes its tests**

Run:

```bash
python3 scripts/test_summarize_storage_benchmark.py
```

Expected: command exits 0. If the script prints test names, all printed tests must indicate success.

- [ ] **Step 5: Commit validation-only fixes if Step 1, 2, 3, or 4 found defects**

If no defects were found, skip this step. If a defect was fixed, run:

```bash
git add argocd/base argocd/homelab docs/storage-benchmark-rwo-strict scripts
git commit -m "fix(storage): validate strict RWO benchmark manifests"
```

Expected when fixes were needed: commit succeeds and contains only validation-driven corrections.

- [ ] **Step 6: Pause for review and merge dormant work to `main` after approval**

Run before handing off for review:

```bash
git status --short
git log --oneline --decorate main..HEAD
```

Expected: `git status --short` is empty, and the commit list contains the dormant manifest, runbook, and validation-fix commits. Request review at this point. After review approval, merge those commits to `main` with normal signed Git workflow while the strict RWO apps remain dormant. Do not change any generated `targetRevision: main` fields, and do not add strict RWO apps to `argocd/homelab/apps/kustomization.yaml` during the merge.

---

### Task 4: Run Longhorn and Mayastor strict RWO benchmarks and capture artifacts

Start this task only after review approval and merge of dormant apps to `main`. Perform activation and reader-enable commits on `main`, not on the worktree branch, because ArgoCD Applications use `targetRevision: main`.

**Files:**
- Modify during activation: `argocd/homelab/apps/kustomization.yaml`
- Modify during reader phases: `argocd/homelab/storage-benchmark-rwo-strict-longhorn/kustomization.yaml`
- Modify during reader phases: `argocd/homelab/storage-benchmark-rwo-strict-mayastor/kustomization.yaml`
- Create after Longhorn run: `docs/storage-benchmark-rwo-strict/longhorn-nvme-writer-fordyce-run-001.log`
- Create after Longhorn run: `docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-dauwalter-run-001.log`
- Create after Longhorn run: `docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-selassie-run-001.log`
- Create after Longhorn run: `docs/storage-benchmark-rwo-strict/longhorn-nvme-run-001-health.md`
- Create after Longhorn run: `docs/storage-benchmark-rwo-strict/longhorn-nvme-run-001-summary.md`
- Create after Mayastor run: `docs/storage-benchmark-rwo-strict/mayastor-writer-fordyce-run-001.log`
- Create after Mayastor run: `docs/storage-benchmark-rwo-strict/mayastor-reader-dauwalter-run-001.log`
- Create after Mayastor run: `docs/storage-benchmark-rwo-strict/mayastor-reader-selassie-run-001.log`
- Create after Mayastor run: `docs/storage-benchmark-rwo-strict/mayastor-run-001-health.md`
- Create after Mayastor run: `docs/storage-benchmark-rwo-strict/mayastor-run-001-summary.md`

**Interfaces:**
- Consumes: dormant Longhorn and Mayastor manifests from Task 1.
- Produces: Longhorn and Mayastor strict RWO results and placement evidence used by the final comparison.

- [ ] **Step 1: Activate the Longhorn writer through GitOps**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
text = path.read_text()
line = '  - ../../base/storage-benchmark-rwo-strict-longhorn\n'
if line not in text:
    marker = '  - ../../base/longhorn-admission-hooks\n'
    text = text.replace(marker, marker + line)
path.write_text(text)
PY
git add argocd/homelab/apps/kustomization.yaml
git commit -m "chore(storage): activate longhorn strict RWO writer"
```

Expected: commit succeeds on `main` after dormant app review/merge. Deliver this commit through the normal signed Git flow to `main`, the branch ArgoCD tracks.

- [ ] **Step 2: Wait for Longhorn writer completion and capture evidence**

After the activation commit, poll ArgoCD for at most 5 minutes before checking the Job. Then run:

```bash
kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=longhorn-nvme
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete job/longhorn-nvme-rwo-strict-writer-fordyce-run-001 --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=longhorn-nvme
  kubectl -n storage-benchmark-rwo-strict logs job/longhorn-nvme-rwo-strict-writer-fordyce-run-001 --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for longhorn-nvme-rwo-strict-writer-fordyce-run-001; inspect progress before continuing." >&2
  exit 1
}
kubectl -n storage-benchmark-rwo-strict logs job/longhorn-nvme-rwo-strict-writer-fordyce-run-001 > docs/storage-benchmark-rwo-strict/longhorn-nvme-writer-fordyce-run-001.log
{
  echo '# Longhorn NVMe strict RWO run 001 health'
  echo
  echo '## Pod placement'
  kubectl -n storage-benchmark-rwo-strict get pod -o wide -l storage.compaan.io/backend=longhorn-nvme
  echo
  echo '## PVC and PV identity'
  kubectl -n storage-benchmark-rwo-strict get pvc longhorn-nvme-rwo-strict-pvc-run-001 -o wide
  kubectl get pv -o wide | grep longhorn-nvme-rwo-strict-pvc-run-001 || true
  echo
  echo '## Longhorn volumes'
  kubectl -n longhorn-system get volumes.longhorn.io -o wide
  echo
  echo '## Longhorn replicas'
  kubectl -n longhorn-system get replicas.longhorn.io -o wide
  echo
  echo '## Longhorn engines'
  kubectl -n longhorn-system get engines.longhorn.io -o wide
} > docs/storage-benchmark-rwo-strict/longhorn-nvme-run-001-health.md
grep 'WRITER_COMPLETE' docs/storage-benchmark-rwo-strict/longhorn-nvme-writer-fordyce-run-001.log
```

Expected: wait exits 0, writer log contains `WRITER_COMPLETE`, and the writer pod `NODE` column is `fordyce`.

- [ ] **Step 3: Enable and run the Longhorn `dauwalter` reader**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/storage-benchmark-rwo-strict-longhorn/kustomization.yaml')
text = path.read_text()
line = '  - reader-dauwalter-job.yaml\n'
if line not in text:
    text = text.replace('  - writer-job.yaml\n', '  - writer-job.yaml\n' + line)
path.write_text(text)
PY
git add argocd/homelab/storage-benchmark-rwo-strict-longhorn/kustomization.yaml
git commit -m "chore(storage): activate longhorn strict RWO dauwalter reader"
```

Deliver the commit through Git. Poll ArgoCD for at most 5 minutes before checking the Job. Then run:

```bash
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete job/longhorn-nvme-rwo-strict-reader-dauwalter-run-001 --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=longhorn-nvme
  kubectl -n storage-benchmark-rwo-strict logs job/longhorn-nvme-rwo-strict-reader-dauwalter-run-001 --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for longhorn-nvme-rwo-strict-reader-dauwalter-run-001; inspect progress before continuing." >&2
  exit 1
}
kubectl -n storage-benchmark-rwo-strict logs job/longhorn-nvme-rwo-strict-reader-dauwalter-run-001 > docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-dauwalter-run-001.log
grep '^RESULT,' docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-dauwalter-run-001.log
```

Expected: wait exits 0 and the log has `RESULT` rows for `seq-read-1m` and `rand-read-4k`.

- [ ] **Step 4: Enable and run the Longhorn `selassie` reader, summarize, and commit**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/storage-benchmark-rwo-strict-longhorn/kustomization.yaml')
text = path.read_text()
line = '  - reader-selassie-job.yaml\n'
if line not in text:
    text = text.replace('  - reader-dauwalter-job.yaml\n', '  - reader-dauwalter-job.yaml\n' + line)
path.write_text(text)
PY
git add argocd/homelab/storage-benchmark-rwo-strict-longhorn/kustomization.yaml
git commit -m "chore(storage): activate longhorn strict RWO selassie reader"
```

Deliver the commit through Git. Poll ArgoCD for at most 5 minutes before checking the Job. Then run:

```bash
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete job/longhorn-nvme-rwo-strict-reader-selassie-run-001 --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=longhorn-nvme
  kubectl -n storage-benchmark-rwo-strict logs job/longhorn-nvme-rwo-strict-reader-selassie-run-001 --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for longhorn-nvme-rwo-strict-reader-selassie-run-001; inspect progress before continuing." >&2
  exit 1
}
kubectl -n storage-benchmark-rwo-strict logs job/longhorn-nvme-rwo-strict-reader-selassie-run-001 > docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-selassie-run-001.log
grep '^RESULT,' docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-selassie-run-001.log
python3 scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-dauwalter-run-001.log \
  docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-selassie-run-001.log \
  > docs/storage-benchmark-rwo-strict/longhorn-nvme-run-001-summary.md
git add \
  docs/storage-benchmark-rwo-strict/longhorn-nvme-writer-fordyce-run-001.log \
  docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-dauwalter-run-001.log \
  docs/storage-benchmark-rwo-strict/longhorn-nvme-reader-selassie-run-001.log \
  docs/storage-benchmark-rwo-strict/longhorn-nvme-run-001-health.md \
  docs/storage-benchmark-rwo-strict/longhorn-nvme-run-001-summary.md
git commit -m "docs(storage): add longhorn strict RWO benchmark results"
```

Expected: summary contains only `longhorn-nvme-rwo-strict-dauwalter` and `longhorn-nvme-rwo-strict-selassie` read rows.

- [ ] **Step 5: Activate the Mayastor writer through GitOps**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
text = path.read_text()
line = '  - ../../base/storage-benchmark-rwo-strict-mayastor\n'
if line not in text:
    marker = '  - ../../base/longhorn-admission-hooks\n'
    text = text.replace(marker, marker + line)
path.write_text(text)
PY
git add argocd/homelab/apps/kustomization.yaml
git commit -m "chore(storage): activate mayastor strict RWO writer"
```

Expected: commit succeeds on `main` after dormant app review/merge. Deliver this commit through the normal signed Git flow to `main`, the branch ArgoCD tracks.

- [ ] **Step 6: Wait for Mayastor writer completion and capture evidence**

After the activation commit, poll ArgoCD for at most 5 minutes before checking the Job. Then run:

```bash
kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=mayastor
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete job/mayastor-rwo-strict-writer-fordyce-run-001 --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=mayastor
  kubectl -n storage-benchmark-rwo-strict logs job/mayastor-rwo-strict-writer-fordyce-run-001 --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for mayastor-rwo-strict-writer-fordyce-run-001; inspect progress before continuing." >&2
  exit 1
}
kubectl -n storage-benchmark-rwo-strict logs job/mayastor-rwo-strict-writer-fordyce-run-001 > docs/storage-benchmark-rwo-strict/mayastor-writer-fordyce-run-001.log
{
  echo '# Mayastor strict RWO run 001 health'
  echo
  echo '## Pod placement'
  kubectl -n storage-benchmark-rwo-strict get pod -o wide -l storage.compaan.io/backend=mayastor
  echo
  echo '## PVC and PV identity'
  kubectl -n storage-benchmark-rwo-strict get pvc mayastor-rwo-strict-pvc-run-001 -o wide
  kubectl get pv -o wide | grep mayastor-rwo-strict-pvc-run-001 || true
  echo
  echo '## Mayastor disk pools'
  kubectl -n openebs get diskpools.openebs.io -o wide
  echo
  echo '## Mayastor volumes'
  kubectl get volumes.openebs.io -A -o wide || true
  echo
  echo '## Mayastor replicas'
  kubectl get replicas.openebs.io -A -o wide || true
} > docs/storage-benchmark-rwo-strict/mayastor-run-001-health.md
grep 'WRITER_COMPLETE' docs/storage-benchmark-rwo-strict/mayastor-writer-fordyce-run-001.log
```

Expected: wait exits 0, writer log contains `WRITER_COMPLETE`, and the writer pod `NODE` column is `fordyce`.

- [ ] **Step 7: Enable and run the Mayastor `dauwalter` reader**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/storage-benchmark-rwo-strict-mayastor/kustomization.yaml')
text = path.read_text()
line = '  - reader-dauwalter-job.yaml\n'
if line not in text:
    text = text.replace('  - writer-job.yaml\n', '  - writer-job.yaml\n' + line)
path.write_text(text)
PY
git add argocd/homelab/storage-benchmark-rwo-strict-mayastor/kustomization.yaml
git commit -m "chore(storage): activate mayastor strict RWO dauwalter reader"
```

Deliver the commit through Git. Poll ArgoCD for at most 5 minutes before checking the Job. Then run:

```bash
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete job/mayastor-rwo-strict-reader-dauwalter-run-001 --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=mayastor
  kubectl -n storage-benchmark-rwo-strict logs job/mayastor-rwo-strict-reader-dauwalter-run-001 --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for mayastor-rwo-strict-reader-dauwalter-run-001; inspect progress before continuing." >&2
  exit 1
}
kubectl -n storage-benchmark-rwo-strict logs job/mayastor-rwo-strict-reader-dauwalter-run-001 > docs/storage-benchmark-rwo-strict/mayastor-reader-dauwalter-run-001.log
grep '^RESULT,' docs/storage-benchmark-rwo-strict/mayastor-reader-dauwalter-run-001.log
```

Expected: wait exits 0 and the log has `RESULT` rows for `seq-read-1m` and `rand-read-4k`.

- [ ] **Step 8: Enable and run the Mayastor `selassie` reader, summarize, and commit**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/storage-benchmark-rwo-strict-mayastor/kustomization.yaml')
text = path.read_text()
line = '  - reader-selassie-job.yaml\n'
if line not in text:
    text = text.replace('  - reader-dauwalter-job.yaml\n', '  - reader-dauwalter-job.yaml\n' + line)
path.write_text(text)
PY
git add argocd/homelab/storage-benchmark-rwo-strict-mayastor/kustomization.yaml
git commit -m "chore(storage): activate mayastor strict RWO selassie reader"
```

Deliver the commit through Git. Poll ArgoCD for at most 5 minutes before checking the Job. Then run:

```bash
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete job/mayastor-rwo-strict-reader-selassie-run-001 --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=mayastor
  kubectl -n storage-benchmark-rwo-strict logs job/mayastor-rwo-strict-reader-selassie-run-001 --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for mayastor-rwo-strict-reader-selassie-run-001; inspect progress before continuing." >&2
  exit 1
}
kubectl -n storage-benchmark-rwo-strict logs job/mayastor-rwo-strict-reader-selassie-run-001 > docs/storage-benchmark-rwo-strict/mayastor-reader-selassie-run-001.log
grep '^RESULT,' docs/storage-benchmark-rwo-strict/mayastor-reader-selassie-run-001.log
python3 scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-rwo-strict/mayastor-reader-dauwalter-run-001.log \
  docs/storage-benchmark-rwo-strict/mayastor-reader-selassie-run-001.log \
  > docs/storage-benchmark-rwo-strict/mayastor-run-001-summary.md
git add \
  docs/storage-benchmark-rwo-strict/mayastor-writer-fordyce-run-001.log \
  docs/storage-benchmark-rwo-strict/mayastor-reader-dauwalter-run-001.log \
  docs/storage-benchmark-rwo-strict/mayastor-reader-selassie-run-001.log \
  docs/storage-benchmark-rwo-strict/mayastor-run-001-health.md \
  docs/storage-benchmark-rwo-strict/mayastor-run-001-summary.md
git commit -m "docs(storage): add mayastor strict RWO benchmark results"
```

Expected: summary contains only `mayastor-rwo-strict-dauwalter` and `mayastor-rwo-strict-selassie` read rows.

---

### Task 5: Run Piraeus strict RWO benchmark and capture artifacts

Run Piraeus/LINSTOR last. Start this task only after Longhorn and Mayastor artifacts are captured and committed on `main`. Perform activation and reader-enable commits on `main`, not on the worktree branch.

**Files:**
- Modify during activation: `argocd/homelab/apps/kustomization.yaml`
- Modify during reader phase: `argocd/homelab/storage-benchmark-rwo-strict-piraeus/kustomization.yaml`
- Create after run: `docs/storage-benchmark-rwo-strict/piraeus-writer-fordyce-run-001.log`
- Create after run: `docs/storage-benchmark-rwo-strict/piraeus-reader-dauwalter-run-001.log`
- Create after run: `docs/storage-benchmark-rwo-strict/piraeus-reader-selassie-run-001.log`
- Create after run: `docs/storage-benchmark-rwo-strict/piraeus-run-001-health.md`
- Create after run: `docs/storage-benchmark-rwo-strict/piraeus-run-001-summary.md`

**Interfaces:**
- Consumes: dormant Piraeus manifests from Task 1 and runbook from Task 2.
- Produces: Piraeus strict RWO read results and placement evidence used by the final comparison.

- [ ] **Step 1: Activate the Piraeus writer through GitOps**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
text = path.read_text()
line = '  - ../../base/storage-benchmark-rwo-strict-piraeus\n'
if line not in text:
    marker = '  - ../../base/longhorn-admission-hooks\n'
    text = text.replace(marker, marker + line)
path.write_text(text)
PY
git add argocd/homelab/apps/kustomization.yaml
git commit -m "chore(storage): activate piraeus strict RWO writer"
```

Expected: commit succeeds on `main` after dormant app review/merge. Deliver this commit through the normal signed Git flow to `main`, the branch ArgoCD tracks.

- [ ] **Step 2: Wait for Piraeus writer completion with read-only commands**

After the activation commit, poll ArgoCD for at most 5 minutes before checking the Job. Then run:

```bash
kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=piraeus
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete job/piraeus-rwo-strict-writer-fordyce-run-001 --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=piraeus
  kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-writer-fordyce-run-001 --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for piraeus-rwo-strict-writer-fordyce-run-001; inspect progress before continuing." >&2
  exit 1
}
kubectl -n storage-benchmark-rwo-strict get pod -o wide -l storage.compaan.io/phase=writer,storage.compaan.io/backend=piraeus
```

Expected: wait exits 0, and the writer pod `NODE` column is `fordyce`.

- [ ] **Step 3: Capture Piraeus writer logs and placement evidence**

Run:

```bash
mkdir -p docs/storage-benchmark-rwo-strict
kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-writer-fordyce-run-001 > docs/storage-benchmark-rwo-strict/piraeus-writer-fordyce-run-001.log
{
  echo '# Piraeus strict RWO run 001 health'
  echo
  echo '## Writer pod placement'
  kubectl -n storage-benchmark-rwo-strict get pod -o wide -l storage.compaan.io/phase=writer,storage.compaan.io/backend=piraeus
  echo
  echo '## PVC and PV identity'
  kubectl -n storage-benchmark-rwo-strict get pvc piraeus-rwo-strict-pvc-run-001 -o wide
  kubectl get pv -o wide | grep piraeus-rwo-strict-pvc-run-001 || true
  echo
  echo '## LINSTOR resources after writer'
  kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor resource list
  echo
  echo '## LINSTOR volumes after writer'
  kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor volume list
} > docs/storage-benchmark-rwo-strict/piraeus-run-001-health.md
```

Expected: log file contains `WRITER_COMPLETE`; health file records writer pod placement and LINSTOR state.

- [ ] **Step 4: Enable and run the Piraeus `dauwalter` reader**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/storage-benchmark-rwo-strict-piraeus/kustomization.yaml')
text = path.read_text()
line = '  - reader-dauwalter-job.yaml\n'
if line not in text:
    text = text.replace('  - writer-job.yaml\n', '  - writer-job.yaml\n' + line)
path.write_text(text)
PY
git add argocd/homelab/storage-benchmark-rwo-strict-piraeus/kustomization.yaml
git commit -m "chore(storage): activate piraeus strict RWO dauwalter reader"
```

Deliver the commit through Git. Poll ArgoCD for at most 5 minutes before checking the Job. Then run read-only checks:

```bash
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete job/piraeus-rwo-strict-reader-dauwalter-run-001 --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=piraeus
  kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-reader-dauwalter-run-001 --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for piraeus-rwo-strict-reader-dauwalter-run-001; inspect progress before continuing." >&2
  exit 1
}
kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-reader-dauwalter-run-001 > docs/storage-benchmark-rwo-strict/piraeus-reader-dauwalter-run-001.log
grep '^RESULT,' docs/storage-benchmark-rwo-strict/piraeus-reader-dauwalter-run-001.log
```

Expected: wait exits 0 and the log has `RESULT` rows for `seq-read-1m` and `rand-read-4k`.

- [ ] **Step 5: Enable and run the Piraeus `selassie` reader**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/storage-benchmark-rwo-strict-piraeus/kustomization.yaml')
text = path.read_text()
line = '  - reader-selassie-job.yaml\n'
if line not in text:
    text = text.replace('  - reader-dauwalter-job.yaml\n', '  - reader-dauwalter-job.yaml\n' + line)
path.write_text(text)
PY
git add argocd/homelab/storage-benchmark-rwo-strict-piraeus/kustomization.yaml
git commit -m "chore(storage): activate piraeus strict RWO selassie reader"
```

Deliver the commit through Git. Poll ArgoCD for at most 5 minutes before checking the Job. Then run read-only checks:

```bash
kubectl -n storage-benchmark-rwo-strict wait --for=condition=complete job/piraeus-rwo-strict-reader-selassie-run-001 --timeout=10m || {
  kubectl -n storage-benchmark-rwo-strict get jobs,pods -o wide -l storage.compaan.io/backend=piraeus
  kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-reader-selassie-run-001 --tail=80 || true
  echo "Reached 10-minute benchmark polling checkpoint for piraeus-rwo-strict-reader-selassie-run-001; inspect progress before continuing." >&2
  exit 1
}
kubectl -n storage-benchmark-rwo-strict logs job/piraeus-rwo-strict-reader-selassie-run-001 > docs/storage-benchmark-rwo-strict/piraeus-reader-selassie-run-001.log
grep '^RESULT,' docs/storage-benchmark-rwo-strict/piraeus-reader-selassie-run-001.log
```

Expected: wait exits 0 and the log has `RESULT` rows for `seq-read-1m` and `rand-read-4k`.

- [ ] **Step 6: Summarize Piraeus reader results and commit artifacts**

Run:

```bash
python3 scripts/summarize-storage-benchmark.py \
  docs/storage-benchmark-rwo-strict/piraeus-reader-dauwalter-run-001.log \
  docs/storage-benchmark-rwo-strict/piraeus-reader-selassie-run-001.log \
  > docs/storage-benchmark-rwo-strict/piraeus-run-001-summary.md
git add \
  docs/storage-benchmark-rwo-strict/piraeus-writer-fordyce-run-001.log \
  docs/storage-benchmark-rwo-strict/piraeus-reader-dauwalter-run-001.log \
  docs/storage-benchmark-rwo-strict/piraeus-reader-selassie-run-001.log \
  docs/storage-benchmark-rwo-strict/piraeus-run-001-health.md \
  docs/storage-benchmark-rwo-strict/piraeus-run-001-summary.md
git commit -m "docs(storage): add piraeus strict RWO benchmark results"
```

Expected: summary contains only `piraeus-rwo-strict-dauwalter` and `piraeus-rwo-strict-selassie` read rows.

---

### Task 6: Write final comparison and placement audit

**Files:**
- Create: `docs/storage-benchmark-rwo-strict/placement-audit.md`
- Create: `docs/storage-benchmark-rwo-strict/final-comparison.md`
- Read: `docs/storage-benchmark-rwo-strict/*-run-001-summary.md`
- Read: `docs/storage-benchmark-rwo-strict/*-run-001-health.md`
- Read: `docs/storage-benchmark-v2/final-comparison.md`

**Interfaces:**
- Consumes: summaries and health artifacts from Tasks 4 and 5.
- Produces: the accepted benchmark comparison and placement audit for the task acceptance criteria.

- [ ] **Step 1: Generate an aggregate read-only summary table**

Run:

```bash
python3 - <<'PY' > /tmp/rwo-strict-results-table.md
from pathlib import Path
import csv
from collections import defaultdict

logs = sorted(Path('docs/storage-benchmark-rwo-strict').glob('*reader-*-run-001.log'))
rows = []
for log in logs:
    for line in log.read_text().splitlines():
        if line.startswith('RESULT,'):
            parsed = next(csv.reader([line]))
            rows.append(parsed)

headers = [
    'Backend', 'Profile', 'Passes', 'Read MiB/s', 'Read IOPS', 'Read p99 ms', 'Errors'
]
print('| ' + ' | '.join(headers) + ' |')
print('| ' + ' | '.join(['---'] * len(headers)) + ' |')

groups = defaultdict(list)
for parsed in rows:
    _, backend, profile, pass_id, read_iops, write_iops, read_mib_s, write_mib_s, read_mean_ms, write_mean_ms, read_p95_ms, write_p95_ms, read_p99_ms, write_p99_ms, read_p999_ms, write_p999_ms, errors = parsed
    groups[(backend, profile)].append({
        'read_iops': float(read_iops),
        'read_mib_s': float(read_mib_s),
        'read_p99_ms': float(read_p99_ms),
        'errors': int(float(errors)),
    })

for (backend, profile), values in sorted(groups.items()):
    passes = len(values)
    avg_mib = sum(v['read_mib_s'] for v in values) / passes
    avg_iops = sum(v['read_iops'] for v in values) / passes
    avg_p99 = sum(v['read_p99_ms'] for v in values) / passes
    errors = sum(v['errors'] for v in values)
    print(f'| {backend} | {profile} | {passes} | {avg_mib:.2f} | {avg_iops:.2f} | {avg_p99:.2f} | {errors} |')
PY
cat /tmp/rwo-strict-results-table.md
```

Expected: table contains six backend-node groups times two read profiles, with no write or mixed profiles.

- [ ] **Step 2: Write placement audit**

Run:

```bash
cat > docs/storage-benchmark-rwo-strict/placement-audit.md <<'EOF'
# Strict-placement RWO Storage Benchmark Placement Audit

## Placement contract

- Writer node: `fordyce`.
- Reader nodes: `dauwalter`, `selassie`.
- Reader Jobs are separate pods and separate Kubernetes Jobs from the writer Job.
- Reader nodes may have local or up-to-date replicas/resources. That condition is recorded and does not invalidate the result.
- These are not cold remote/no-replica read results.

## Backend placement evidence

| Backend | Writer evidence | Reader evidence | Storage placement evidence | Validity |
| --- | --- | --- | --- | --- |
| Piraeus/LINSTOR RWO | See `piraeus-run-001-health.md` writer pod placement. | See `piraeus-run-001-health.md` reader pod placement. | See LINSTOR resource and volume sections in `piraeus-run-001-health.md`. | Valid if writer pod is on `fordyce` and reader pods are on `dauwalter` and `selassie`. |
| Longhorn NVMe RWO | See `longhorn-nvme-run-001-health.md` writer pod placement. | See `longhorn-nvme-run-001-health.md` reader pod placement. | See Longhorn volume, replica, and engine sections in `longhorn-nvme-run-001-health.md`. | Valid if writer pod is on `fordyce` and reader pods are on `dauwalter` and `selassie`. |
| Mayastor RWO | See `mayastor-run-001-health.md` writer pod placement. | See `mayastor-run-001-health.md` reader pod placement. | See Mayastor disk pool, volume, and replica sections in `mayastor-run-001-health.md`. | Valid if writer pod is on `fordyce` and reader pods are on `dauwalter` and `selassie`. |

## Read/cache note

The benchmark controls writer and reader consumer placement. It does not claim cache-cold remote reads. Local or up-to-date reader-side replicas/resources are allowed and should be interpreted as normal replicated RWO backend behavior.
EOF
```

Expected: placement audit labels the benchmark as locality-allowed and references all three backend health files.

- [ ] **Step 3: Write final comparison**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
results_table = Path('/tmp/rwo-strict-results-table.md').read_text()
content = f'''# Strict-placement RWO Storage Benchmark Final Comparison

## Goal and placement contract

This benchmark measures replicated RWO read performance after a different consumer node wrote the fio test file. For each backend, a writer Job on `fordyce` fully wrote `/volume/fio-test-file`, exited, and separate reader Jobs on `dauwalter` and `selassie` ran read-only fio profiles.

Locality is allowed. These results do not claim cold remote/no-replica reads.

## Included backends

- Piraeus/LINSTOR RWO
- Longhorn NVMe RWO
- Mayastor RWO

`local-path` was not rerun. The original v2 local-path result remains the local baseline.

## Read-only results

{results_table}

## Methodology notes

- Writer phase used `fio --direct=1`, `--rw=write`, `--bs=1m`, and `--size=16G`.
- Reader phase used only `seq-read-1m` and `rand-read-4k`.
- Reader result backend labels include the reader node name.
- Write, mixed read/write, and sync-write profiles are excluded from this comparison.
- Existing `docs/storage-benchmark-v2` replicated backend results remain useful context, but they used a different methodology because a single fio Job wrote and read on the same consumer node.

## Placement audit

See `placement-audit.md` and the per-backend health files:

- `piraeus-run-001-health.md`
- `longhorn-nvme-run-001-health.md`
- `mayastor-run-001-health.md`

## Source artifacts

- Piraeus raw logs: `piraeus-writer-fordyce-run-001.log`, `piraeus-reader-dauwalter-run-001.log`, `piraeus-reader-selassie-run-001.log`
- Longhorn raw logs: `longhorn-nvme-writer-fordyce-run-001.log`, `longhorn-nvme-reader-dauwalter-run-001.log`, `longhorn-nvme-reader-selassie-run-001.log`
- Mayastor raw logs: `mayastor-writer-fordyce-run-001.log`, `mayastor-reader-dauwalter-run-001.log`, `mayastor-reader-selassie-run-001.log`
'''
Path('docs/storage-benchmark-rwo-strict/final-comparison.md').write_text(content)
PY
```

Expected: final comparison contains the aggregate table and the explicit locality-allowed wording.

- [ ] **Step 4: Verify final docs do not claim cold remote reads**

Run:

```bash
grep -q 'Locality is allowed' docs/storage-benchmark-rwo-strict/final-comparison.md
grep -q 'do not claim cold remote/no-replica reads' docs/storage-benchmark-rwo-strict/final-comparison.md
grep -q 'local-path' docs/storage-benchmark-rwo-strict/final-comparison.md
grep -q 'piraeus-rwo-strict-dauwalter' docs/storage-benchmark-rwo-strict/final-comparison.md
grep -q 'longhorn-nvme-rwo-strict-selassie' docs/storage-benchmark-rwo-strict/final-comparison.md
grep -q 'mayastor-rwo-strict-selassie' docs/storage-benchmark-rwo-strict/final-comparison.md
echo 'final comparison wording ok'
```

Expected output:

```text
final comparison wording ok
```

- [ ] **Step 5: Commit final comparison and placement audit**

Run:

```bash
git add \
  docs/storage-benchmark-rwo-strict/placement-audit.md \
  docs/storage-benchmark-rwo-strict/final-comparison.md
git commit -m "docs(storage): compare strict RWO benchmark results"
```

Expected: commit succeeds with final comparison docs only.

---

### Task 7: Deactivate benchmark apps and verify cleanup

**Files:**
- Modify: `argocd/homelab/apps/kustomization.yaml`
- Modify: `docs/storage-benchmark-rwo-strict/*-run-001-health.md`

**Interfaces:**
- Consumes: activation commits from Tasks 4 and 5.
- Produces: GitOps cleanup commit and health notes proving benchmark apps were pruned.

- [ ] **Step 1: Remove strict RWO apps from bootstrap bundle**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('argocd/homelab/apps/kustomization.yaml')
text = path.read_text()
for line in [
    '  - ../../base/storage-benchmark-rwo-strict-piraeus\n',
    '  - ../../base/storage-benchmark-rwo-strict-longhorn\n',
    '  - ../../base/storage-benchmark-rwo-strict-mayastor\n',
]:
    text = text.replace(line, '')
path.write_text(text)
PY
git add argocd/homelab/apps/kustomization.yaml
git commit -m "chore(storage): deactivate strict RWO benchmarks"
```

Expected: commit succeeds. Deliver this commit through Git so ArgoCD prunes benchmark resources.

- [ ] **Step 2: Capture cleanup state with read-only commands**

Run after ArgoCD reconciles the cleanup commit:

```bash
{
  echo
  echo '## Cleanup state'
  kubectl -n argocd get applications | grep storage-benchmark-rwo-strict || true
  kubectl -n storage-benchmark-rwo-strict get all,pvc 2>&1 || true
} >> docs/storage-benchmark-rwo-strict/piraeus-run-001-health.md
{
  echo
  echo '## Cleanup state'
  kubectl -n argocd get applications | grep storage-benchmark-rwo-strict || true
  kubectl -n storage-benchmark-rwo-strict get all,pvc 2>&1 || true
} >> docs/storage-benchmark-rwo-strict/longhorn-nvme-run-001-health.md
{
  echo
  echo '## Cleanup state'
  kubectl -n argocd get applications | grep storage-benchmark-rwo-strict || true
  kubectl -n storage-benchmark-rwo-strict get all,pvc 2>&1 || true
} >> docs/storage-benchmark-rwo-strict/mayastor-run-001-health.md
```

Expected: no strict RWO Applications remain in ArgoCD output after prune; namespace resources are absent or empty.

- [ ] **Step 3: Commit cleanup evidence**

Run:

```bash
git add \
  docs/storage-benchmark-rwo-strict/piraeus-run-001-health.md \
  docs/storage-benchmark-rwo-strict/longhorn-nvme-run-001-health.md \
  docs/storage-benchmark-rwo-strict/mayastor-run-001-health.md
git commit -m "docs(storage): record strict RWO benchmark cleanup"
```

Expected: commit succeeds with cleanup evidence appended to health docs.

---

### Task 8: Final verification and main task closure

**Files:**
- Read: all files changed in this plan
- Modify: file-based task `44b4fa48` through the todo tool

**Interfaces:**
- Consumes: all implementation, run, evidence, comparison, and cleanup commits.
- Produces: final verification evidence and a closed main task.

- [ ] **Step 1: Run final static verification**

Run:

```bash
set -e
for app in \
  storage-benchmark-rwo-strict-piraeus \
  storage-benchmark-rwo-strict-longhorn \
  storage-benchmark-rwo-strict-mayastor
do
  kubectl kustomize "argocd/homelab/${app}" > "/tmp/${app}-final.yaml"
  grep -q 'storage.compaan.io/benchmark: rwo-strict' "/tmp/${app}-final.yaml"
  echo "${app}: final kustomize ok"
done
python3 scripts/test_summarize_storage_benchmark.py
grep -q 'Locality is allowed' docs/storage-benchmark-rwo-strict/final-comparison.md
grep -q 'not cold remote/no-replica reads' docs/storage-benchmark-rwo-strict/README.md
git status --short
```

Expected: three `final kustomize ok` lines, summarizer tests exit 0, grep commands exit 0, and `git status --short` is empty.

- [ ] **Step 2: Verify acceptance criteria line by line**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
root = Path('docs/storage-benchmark-rwo-strict')
required = [
    root / 'piraeus-run-001-health.md',
    root / 'longhorn-nvme-run-001-health.md',
    root / 'mayastor-run-001-health.md',
    root / 'piraeus-run-001-summary.md',
    root / 'longhorn-nvme-run-001-summary.md',
    root / 'mayastor-run-001-summary.md',
    root / 'placement-audit.md',
    root / 'final-comparison.md',
]
missing = [str(path) for path in required if not path.exists()]
if missing:
    raise SystemExit('missing required artifacts: ' + ', '.join(missing))
final = (root / 'final-comparison.md').read_text()
checks = {
    'writer node documented': 'fordyce' in final and 'writer' in final.lower(),
    'reader nodes documented': 'dauwalter' in final and 'selassie' in final,
    'locality allowed documented': 'Locality is allowed' in final,
    'cold remote claim avoided': 'do not claim cold remote/no-replica reads' in final,
    'local-path not rerun': 'local-path' in final and 'not rerun' in final,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('failed acceptance checks: ' + ', '.join(failed))
for name in checks:
    print('ok: ' + name)
PY
```

Expected output:

```text
ok: writer node documented
ok: reader nodes documented
ok: locality allowed documented
ok: cold remote claim avoided
ok: local-path not rerun
```

- [ ] **Step 3: Close the main file-based task**

Use the todo tool to update raw id `44b4fa48` with a short completion note that includes:

- branch or final commit range
- artifact directory `docs/storage-benchmark-rwo-strict/`
- verification commands from Step 1 and Step 2
- note that results are different-consumer-node reads with locality allowed

Expected: task `44b4fa48` status becomes `closed` only after Step 1 and Step 2 pass.
