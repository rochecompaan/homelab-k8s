# Longhorn NVMe v2 run 001 health

Captured: 2026-07-01T11:24:22Z

## Tagger job
NAME                                           STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES               SELECTOR
job.batch/longhorn-nvme-disk-tagger-20260630   Complete   1/1           6s         38m   tagger       python:3.13-alpine   batch.kubernetes.io/controller-uid=46571d93-684d-43b7-adee-364027862893

NAME                                           READY   STATUS      RESTARTS   AGE   IP           NODE        NOMINATED NODE   READINESS GATES
pod/longhorn-nvme-disk-tagger-20260630-d8bml   0/1     Completed   0          38m   10.42.0.56   dauwalter   <none>           <none>

## Tagger log
tagged dauwalter longhorn-root /var/lib/longhorn/ tags=['nvme']
tagged fordyce longhorn-root /var/lib/longhorn/ tags=['nvme']
tagged kipsang default-disk-a312c1623e95d3ff /var/lib/longhorn/ tags=['nvme']
tagged selassie longhorn-root /var/lib/longhorn/ tags=['nvme']
tagged walmsley default-disk-fe717b3b67c469ed /var/lib/longhorn/ tags=['nvme']

## Kubernetes objects
NAME                                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/longhorn-nvme-fio-pvc-v2-run-001   Bound    pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75   20Gi       RWO            longhorn-nvme-bench-v2-3r   <unset>                 38m   Filesystem

NAME                                               STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/storage-bench-longhorn-nvme-v2-run-001   Complete   1/1           36m        37m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=542da7b1-589a-48ce-b266-b7e0802cdf3e

NAME                                               READY   STATUS      RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES
pod/storage-bench-longhorn-nvme-v2-run-001-xgtdf   0/1     Completed   0          37m   10.42.3.128   fordyce   <none>           <none>

## PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
    argocd.argoproj.io/tracking-id: storage-benchmark-v2-longhorn:/PersistentVolumeClaim:storage-benchmark-v2/longhorn-nvme-fio-pvc-v2-run-001
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"2","argocd.argoproj.io/tracking-id":"storage-benchmark-v2-longhorn:/PersistentVolumeClaim:storage-benchmark-v2/longhorn-nvme-fio-pvc-v2-run-001"},"labels":{"app.kubernetes.io/name":"storage-benchmark-v2","storage.compaan.io/backend":"longhorn-nvme"},"name":"longhorn-nvme-fio-pvc-v2-run-001","namespace":"storage-benchmark-v2"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"20Gi"}},"storageClassName":"longhorn-nvme-bench-v2-3r"}}
    pv.kubernetes.io/bind-completed: "yes"
    pv.kubernetes.io/bound-by-controller: "yes"
    volume.beta.kubernetes.io/storage-provisioner: driver.longhorn.io
    volume.kubernetes.io/storage-provisioner: driver.longhorn.io
  creationTimestamp: "2026-07-01T10:46:22Z"
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    app.kubernetes.io/name: storage-benchmark-v2
    storage.compaan.io/backend: longhorn-nvme
  name: longhorn-nvme-fio-pvc-v2-run-001
  namespace: storage-benchmark-v2
  resourceVersion: "147272402"
  uid: 1b1760aa-d44d-4f64-aed8-53fb965dcb75
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: longhorn-nvme-bench-v2-3r
  volumeMode: Filesystem
  volumeName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
status:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 20Gi
  phase: Bound

## PV pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    longhorn.io/volume-scheduling-error: ""
    pv.kubernetes.io/provisioned-by: driver.longhorn.io
    volume.kubernetes.io/provisioner-deletion-secret-name: ""
    volume.kubernetes.io/provisioner-deletion-secret-namespace: ""
  creationTimestamp: "2026-07-01T10:46:24Z"
  finalizers:
  - external-provisioner.volume.kubernetes.io/finalizer
  - kubernetes.io/pv-protection
  - external-attacher/driver-longhorn-io
  name: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
  resourceVersion: "147272419"
  uid: 88132c99-68eb-4f7c-932e-a75bee648f45
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 20Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: longhorn-nvme-fio-pvc-v2-run-001
    namespace: storage-benchmark-v2
    resourceVersion: "147272333"
    uid: 1b1760aa-d44d-4f64-aed8-53fb965dcb75
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeAttributes:
      backupTargetName: default
      dataEngine: v1
      dataLocality: disabled
      disableRevisionCounter: "true"
      diskSelector: nvme
      fromBackup: ""
      fsType: ext4
      numberOfReplicas: "3"
      staleReplicaTimeout: "30"
      storage.kubernetes.io/csiProvisionerIdentity: 1781688819188-535-driver.longhorn.io
      unmapMarkSnapChainRemoved: ignored
    volumeHandle: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
  persistentVolumeReclaimPolicy: Delete
  storageClassName: longhorn-nvme-bench-v2-3r
  volumeMode: Filesystem
status:
  lastPhaseTransitionTime: "2026-07-01T10:46:24Z"
  phase: Bound

## Longhorn volume pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  creationTimestamp: "2026-07-01T10:46:22Z"
  finalizers:
  - longhorn.io
  generation: 3
  labels:
    backup-target: default
    longhornvolume: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
    recurring-job-group.longhorn.io/default: enabled
    setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
    setting.longhorn.io/replica-auto-balance: ignored
    setting.longhorn.io/snapshot-data-integrity: ignored
  name: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
  namespace: longhorn-system
  resourceVersion: "147292692"
  uid: ba497a47-d494-4b8e-b646-5dce58723b45
spec:
  Standby: false
  accessMode: rwo
  backingImage: ""
  backupBlockSize: "2097152"
  backupCompressionMethod: lz4
  backupTargetName: default
  dataEngine: v1
  dataLocality: disabled
  dataSource: ""
  disableFrontend: false
  diskSelector:
  - nvme
  encrypted: false
  freezeFilesystemForSnapshot: ignored
  fromBackup: ""
  frontend: blockdev
  image: longhornio/longhorn-engine:v1.10.1
  lastAttachedBy: ""
  migratable: false
  migrationNodeID: ""
  nodeID: ""
  nodeSelector: []
  numberOfReplicas: 3
  offlineRebuilding: ignored
  replicaAutoBalance: ignored
  replicaDiskSoftAntiAffinity: ignored
  replicaRebuildingBandwidthLimit: 0
  replicaSoftAntiAffinity: ignored
  replicaZoneSoftAntiAffinity: ignored
  restoreVolumeRecurringJob: ignored
  revisionCounterDisabled: true
  size: "21474836480"
  snapshotDataIntegrity: ignored
  snapshotMaxCount: 250
  snapshotMaxSize: "0"
  staleReplicaTimeout: 30
  unmapMarkSnapChainRemoved: ignored
status:
  actualSize: 6424952832
  cloneStatus:
    attemptCount: 0
    nextAllowedAttemptAt: ""
    snapshot: ""
    sourceVolume: ""
    state: ""
  conditions:
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-01T10:46:22Z"
    message: ""
    reason: ""
    status: "False"
    type: WaitForBackingImage
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-01T10:46:22Z"
    message: ""
    reason: ""
    status: "False"
    type: TooManySnapshots
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-01T10:46:22Z"
    message: ""
    reason: ""
    status: "True"
    type: Scheduled
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-01T10:46:22Z"
    message: ""
    reason: ""
    status: "False"
    type: Restore
  currentImage: longhornio/longhorn-engine:v1.10.1
  currentMigrationNodeID: ""
  currentNodeID: ""
  expansionRequired: false
  frontendDisabled: false
  isStandby: false
  kubernetesStatus:
    lastPVCRefAt: ""
    lastPodRefAt: ""
    namespace: storage-benchmark-v2
    pvName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
    pvStatus: Bound
    pvcName: longhorn-nvme-fio-pvc-v2-run-001
    workloadsStatus:
    - podName: storage-bench-longhorn-nvme-v2-run-001-xgtdf
      podStatus: Succeeded
      workloadName: storage-bench-longhorn-nvme-v2-run-001
      workloadType: Job
  lastBackup: ""
  lastBackupAt: ""
  lastDegradedAt: ""
  ownerID: fordyce
  remountRequestedAt: ""
  restoreInitiated: false
  restoreRequired: false
  robustness: unknown
  shareEndpoint: ""
  shareState: ""
  state: detached

## Longhorn replicas for pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
NAME                                                  DATA ENGINE   STATE     NODE        DISK                                   INSTANCEMANAGER   IMAGE   AGE
pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-r-1cd631f1   v1            stopped   walmsley    79622d60-33c2-4a3a-b03d-4c5d410580f3                             38m
pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-r-9a7e1047   v1            stopped   kipsang     413befa8-2e7e-45cc-8dd8-3bd8cb4dca49                             38m
pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-r-b801ffa9   v1            stopped   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690                             38m

apiVersion: v1
items:
- apiVersion: longhorn.io/v1beta2
  kind: Replica
  metadata:
    creationTimestamp: "2026-07-01T10:46:22Z"
    finalizers:
    - longhorn.io
    generation: 5
    labels:
      longhorn.io/backing-image: ""
      longhorndiskuuid: 79622d60-33c2-4a3a-b03d-4c5d410580f3
      longhornnode: walmsley
      longhornvolume: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
    name: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-r-1cd631f1
    namespace: longhorn-system
    ownerReferences:
    - apiVersion: longhorn.io/v1beta2
      kind: Volume
      name: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
      uid: ba497a47-d494-4b8e-b646-5dce58723b45
    resourceVersion: "147292690"
    uid: 50c5fcff-6fbd-40b9-944d-b9001817f186
  spec:
    active: true
    backingImage: ""
    dataDirectoryName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-3507f118
    dataEngine: v1
    desireState: stopped
    diskID: 79622d60-33c2-4a3a-b03d-4c5d410580f3
    diskPath: /var/lib/longhorn/
    engineName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-e-0
    evictionRequested: false
    failedAt: ""
    hardNodeAffinity: ""
    healthyAt: "2026-07-01T10:46:34Z"
    image: longhornio/longhorn-engine:v1.10.1
    lastFailedAt: ""
    lastHealthyAt: "2026-07-01T10:46:34Z"
    logRequested: false
    migrationEngineName: ""
    nodeID: walmsley
    rebuildRetryCount: 0
    revisionCounterDisabled: true
    salvageRequested: false
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    unmapMarkDiskChainRemovedEnabled: false
    volumeName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
    volumeSize: "21474836480"
  status:
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-01T10:46:22Z"
      message: ""
      reason: ""
      status: "True"
      type: InstanceCreation
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-01T10:46:22Z"
      message: ""
      reason: ""
      status: "False"
      type: FilesystemReadOnly
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-01T10:46:24Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    currentImage: ""
    currentState: stopped
    instanceManagerName: ""
    ip: ""
    logFetched: false
    ownerID: walmsley
    port: 0
    salvageExecuted: false
    started: false
    starting: false
    storageIP: ""
- apiVersion: longhorn.io/v1beta2
  kind: Replica
  metadata:
    creationTimestamp: "2026-07-01T10:46:22Z"
    finalizers:
    - longhorn.io
    generation: 5
    labels:
      longhorn.io/backing-image: ""
      longhorndiskuuid: 413befa8-2e7e-45cc-8dd8-3bd8cb4dca49
      longhornnode: kipsang
      longhornvolume: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
    name: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-r-9a7e1047
    namespace: longhorn-system
    ownerReferences:
    - apiVersion: longhorn.io/v1beta2
      kind: Volume
      name: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
      uid: ba497a47-d494-4b8e-b646-5dce58723b45
    resourceVersion: "147292682"
    uid: 81b20c4b-577b-47ba-88ea-00e7e18261b5
  spec:
    active: true
    backingImage: ""
    dataDirectoryName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-1181db02
    dataEngine: v1
    desireState: stopped
    diskID: 413befa8-2e7e-45cc-8dd8-3bd8cb4dca49
    diskPath: /var/lib/longhorn/
    engineName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-e-0
    evictionRequested: false
    failedAt: ""
    hardNodeAffinity: ""
    healthyAt: "2026-07-01T10:46:34Z"
    image: longhornio/longhorn-engine:v1.10.1
    lastFailedAt: ""
    lastHealthyAt: "2026-07-01T10:46:34Z"
    logRequested: false
    migrationEngineName: ""
    nodeID: kipsang
    rebuildRetryCount: 0
    revisionCounterDisabled: true
    salvageRequested: false
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    unmapMarkDiskChainRemovedEnabled: false
    volumeName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
    volumeSize: "21474836480"
  status:
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-01T10:46:22Z"
      message: ""
      reason: ""
      status: "True"
      type: InstanceCreation
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-01T10:46:22Z"
      message: ""
      reason: ""
      status: "False"
      type: FilesystemReadOnly
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-01T10:46:24Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    currentImage: ""
    currentState: stopped
    instanceManagerName: ""
    ip: ""
    logFetched: false
    ownerID: kipsang
    port: 0
    salvageExecuted: false
    started: false
    starting: false
    storageIP: ""
- apiVersion: longhorn.io/v1beta2
  kind: Replica
  metadata:
    creationTimestamp: "2026-07-01T10:46:22Z"
    finalizers:
    - longhorn.io
    generation: 5
    labels:
      longhorn.io/backing-image: ""
      longhorndiskuuid: 0742a187-2434-4fb2-964d-05ea99ae8690
      longhornnode: dauwalter
      longhornvolume: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
    name: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-r-b801ffa9
    namespace: longhorn-system
    ownerReferences:
    - apiVersion: longhorn.io/v1beta2
      kind: Volume
      name: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
      uid: ba497a47-d494-4b8e-b646-5dce58723b45
    resourceVersion: "147292678"
    uid: fb0b4ca0-3389-4ad9-9d45-b03bb8e8a163
  spec:
    active: true
    backingImage: ""
    dataDirectoryName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-36ffc873
    dataEngine: v1
    desireState: stopped
    diskID: 0742a187-2434-4fb2-964d-05ea99ae8690
    diskPath: /var/lib/longhorn/
    engineName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75-e-0
    evictionRequested: false
    failedAt: ""
    hardNodeAffinity: ""
    healthyAt: "2026-07-01T10:46:34Z"
    image: longhornio/longhorn-engine:v1.10.1
    lastFailedAt: ""
    lastHealthyAt: "2026-07-01T10:46:34Z"
    logRequested: false
    migrationEngineName: ""
    nodeID: dauwalter
    rebuildRetryCount: 0
    revisionCounterDisabled: true
    salvageRequested: false
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    unmapMarkDiskChainRemovedEnabled: false
    volumeName: pvc-1b1760aa-d44d-4f64-aed8-53fb965dcb75
    volumeSize: "21474836480"
  status:
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-01T10:46:22Z"
      message: ""
      reason: ""
      status: "True"
      type: InstanceCreation
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-01T10:46:22Z"
      message: ""
      reason: ""
      status: "False"
      type: FilesystemReadOnly
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-01T10:46:24Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    currentImage: ""
    currentState: stopped
    instanceManagerName: ""
    ip: ""
    logFetched: false
    ownerID: dauwalter
    port: 0
    salvageExecuted: false
    started: false
    starting: false
    storageIP: ""
kind: List
metadata:
  resourceVersion: ""

## Longhorn node disks
node dauwalter
  disk longhorn-root: path=/var/lib/longhorn/ tags=nvme allowScheduling=True max=942982066176
node fordyce
  disk longhorn-root: path=/var/lib/longhorn/ tags=nvme allowScheduling=True max=186906017792
node kipsang
  disk default-disk-a312c1623e95d3ff: path=/var/lib/longhorn/ tags=nvme allowScheduling=True max=250387689472
  disk disk-2: path=/srv/data tags=sata allowScheduling=True max=15873631350784
node selassie
  disk longhorn-root: path=/var/lib/longhorn/ tags=nvme allowScheduling=True max=186906017792
  disk longhorn-sata: path=/srv/data tags=sata allowScheduling=True max=0
node walmsley
  disk default-disk-fe717b3b67c469ed: path=/var/lib/longhorn/ tags=nvme allowScheduling=True max=250387689472
  disk disk-3: path=/srv/data tags=sata allowScheduling=True max=15873631350784
