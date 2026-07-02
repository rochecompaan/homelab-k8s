# Longhorn RWX run 001 health

Captured: 2026-07-02T16:07:45Z

## ArgoCD application
NAME                             SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
storage-benchmark-rwx-longhorn   Synced        Healthy         300ab1a7ccadce9a86006b078f9d3733257cf09a   default

## Benchmark resources
NAME                                             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                 VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/longhorn-rwx-pvc-run-002   Bound    pvc-4d80a091-3336-45a2-88f1-2aad621c5c45   20Gi       RWX            longhorn-rwx-nvme-bench-3r   <unset>                 57m   Filesystem

NAME                                   READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
pod/longhorn-rwx-fio-run-002-0-n24gz   0/1     Completed   0          56m   10.42.0.60    dauwalter   <none>           <none>
pod/longhorn-rwx-fio-run-002-1-jk7kl   0/1     Completed   0          56m   10.42.3.132   fordyce     <none>           <none>
pod/longhorn-rwx-fio-run-002-2-v52bf   0/1     Completed   0          56m   10.42.2.33    selassie    <none>           <none>
pod/longhorn-rwx-proof-a-run-002       1/1     Running     0          56m   10.42.3.131   fordyce     <none>           <none>
pod/longhorn-rwx-proof-b-run-002       1/1     Running     0          56m   10.42.2.32    selassie    <none>           <none>

NAME                                 STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/longhorn-rwx-fio-run-002   Complete   3/3           54m        56m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=c83cce76-f433-4801-a02f-14eb6b00689e

## PVC YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/tracking-id: storage-benchmark-rwx-longhorn:/PersistentVolumeClaim:storage-benchmark-rwx/longhorn-rwx-pvc-run-002
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"1","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-longhorn:/PersistentVolumeClaim:storage-benchmark-rwx/longhorn-rwx-pvc-run-002"},"labels":{"app.kubernetes.io/name":"storage-benchmark-rwx","storage.compaan.io/backend":"longhorn-rwx"},"name":"longhorn-rwx-pvc-run-002","namespace":"storage-benchmark-rwx"},"spec":{"accessModes":["ReadWriteMany"],"resources":{"requests":{"storage":"20Gi"}},"storageClassName":"longhorn-rwx-nvme-bench-3r"}}
    pv.kubernetes.io/bind-completed: "yes"
    pv.kubernetes.io/bound-by-controller: "yes"
    volume.beta.kubernetes.io/storage-provisioner: driver.longhorn.io
    volume.kubernetes.io/storage-provisioner: driver.longhorn.io
  creationTimestamp: "2026-07-02T15:10:14Z"
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: longhorn-rwx
  name: longhorn-rwx-pvc-run-002
  namespace: storage-benchmark-rwx
  resourceVersion: "148193626"
  uid: 4d80a091-3336-45a2-88f1-2aad621c5c45
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
  storageClassName: longhorn-rwx-nvme-bench-3r
  volumeMode: Filesystem
  volumeName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
status:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 20Gi
  phase: Bound

## PV pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    longhorn.io/volume-scheduling-error: ""
    pv.kubernetes.io/provisioned-by: driver.longhorn.io
    volume.kubernetes.io/provisioner-deletion-secret-name: ""
    volume.kubernetes.io/provisioner-deletion-secret-namespace: ""
  creationTimestamp: "2026-07-02T15:10:16Z"
  finalizers:
  - external-provisioner.volume.kubernetes.io/finalizer
  - kubernetes.io/pv-protection
  - external-attacher/driver-longhorn-io
  name: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
  resourceVersion: "148193966"
  uid: 099423c2-f383-4fb8-a5e4-0bceb16071fd
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 20Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: longhorn-rwx-pvc-run-002
    namespace: storage-benchmark-rwx
    resourceVersion: "148193562"
    uid: 4d80a091-3336-45a2-88f1-2aad621c5c45
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
      share: "true"
      staleReplicaTimeout: "30"
      storage.kubernetes.io/csiProvisionerIdentity: 1781688819188-535-driver.longhorn.io
      unmapMarkSnapChainRemoved: ignored
    volumeHandle: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
  persistentVolumeReclaimPolicy: Delete
  storageClassName: longhorn-rwx-nvme-bench-3r
  volumeMode: Filesystem
status:
  lastPhaseTransitionTime: "2026-07-02T15:10:16Z"
  phase: Bound

## Longhorn volume pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  creationTimestamp: "2026-07-02T15:10:14Z"
  finalizers:
  - longhorn.io
  generation: 2
  labels:
    backup-target: default
    longhornvolume: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
    recurring-job-group.longhorn.io/default: enabled
    setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
    setting.longhorn.io/replica-auto-balance: ignored
    setting.longhorn.io/snapshot-data-integrity: ignored
  name: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
  namespace: longhorn-system
  resourceVersion: "148224417"
  uid: ac0e818a-3bce-4260-9523-ad230a0eb680
spec:
  Standby: false
  accessMode: rwx
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
  nodeID: dauwalter
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
  actualSize: 20466663424
  cloneStatus:
    attemptCount: 0
    nextAllowedAttemptAt: ""
    snapshot: ""
    sourceVolume: ""
    state: ""
  conditions:
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-02T15:10:15Z"
    message: ""
    reason: ""
    status: "False"
    type: WaitForBackingImage
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-02T15:10:15Z"
    message: ""
    reason: ""
    status: "False"
    type: TooManySnapshots
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-02T15:10:15Z"
    message: ""
    reason: ""
    status: "True"
    type: Scheduled
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-02T15:10:15Z"
    message: ""
    reason: ""
    status: "False"
    type: Restore
  currentImage: longhornio/longhorn-engine:v1.10.1
  currentMigrationNodeID: ""
  currentNodeID: dauwalter
  expansionRequired: false
  frontendDisabled: false
  isStandby: false
  kubernetesStatus:
    lastPVCRefAt: ""
    lastPodRefAt: ""
    namespace: storage-benchmark-rwx
    pvName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
    pvStatus: Bound
    pvcName: longhorn-rwx-pvc-run-002
    workloadsStatus:
    - podName: longhorn-rwx-fio-run-002-0-n24gz
      podStatus: Succeeded
      workloadName: longhorn-rwx-fio-run-002
      workloadType: Job
    - podName: longhorn-rwx-fio-run-002-1-jk7kl
      podStatus: Succeeded
      workloadName: longhorn-rwx-fio-run-002
      workloadType: Job
    - podName: longhorn-rwx-fio-run-002-2-v52bf
      podStatus: Succeeded
      workloadName: longhorn-rwx-fio-run-002
      workloadType: Job
    - podName: longhorn-rwx-proof-a-run-002
      podStatus: Running
      workloadName: ""
      workloadType: ""
    - podName: longhorn-rwx-proof-b-run-002
      podStatus: Running
      workloadName: ""
      workloadType: ""
  lastBackup: ""
  lastBackupAt: ""
  lastDegradedAt: ""
  ownerID: dauwalter
  remountRequestedAt: ""
  restoreInitiated: false
  restoreRequired: false
  robustness: healthy
  shareEndpoint: nfs://10.43.100.223/pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
  shareState: running
  state: attached

## Longhorn replicas for pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
NAME                                                  DATA ENGINE   STATE     NODE        DISK                                   INSTANCEMANAGER                                     IMAGE                                AGE
pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-r-ae59f396   v1            running   walmsley    79622d60-33c2-4a3a-b03d-4c5d410580f3   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   57m
pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-r-c360cdfd   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   57m
pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-r-d9eda84b   v1            running   kipsang     413befa8-2e7e-45cc-8dd8-3bd8cb4dca49   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   57m
apiVersion: v1
items:
- apiVersion: longhorn.io/v1beta2
  kind: Replica
  metadata:
    creationTimestamp: "2026-07-02T15:10:14Z"
    finalizers:
    - longhorn.io
    generation: 4
    labels:
      longhorn.io/backing-image: ""
      longhorndiskuuid: 79622d60-33c2-4a3a-b03d-4c5d410580f3
      longhornnode: walmsley
      longhornvolume: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
    name: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-r-ae59f396
    namespace: longhorn-system
    ownerReferences:
    - apiVersion: longhorn.io/v1beta2
      kind: Volume
      name: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
      uid: ac0e818a-3bce-4260-9523-ad230a0eb680
    resourceVersion: "148194132"
    uid: 9e0fb920-d73c-4cb3-8e3c-0c53425d22b0
  spec:
    active: true
    backingImage: ""
    dataDirectoryName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-ec1bd96d
    dataEngine: v1
    desireState: running
    diskID: 79622d60-33c2-4a3a-b03d-4c5d410580f3
    diskPath: /var/lib/longhorn/
    engineName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-e-0
    evictionRequested: false
    failedAt: ""
    hardNodeAffinity: ""
    healthyAt: "2026-07-02T15:10:58Z"
    image: longhornio/longhorn-engine:v1.10.1
    lastFailedAt: ""
    lastHealthyAt: "2026-07-02T15:10:58Z"
    logRequested: false
    migrationEngineName: ""
    nodeID: walmsley
    rebuildRetryCount: 0
    revisionCounterDisabled: true
    salvageRequested: false
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    unmapMarkDiskChainRemovedEnabled: false
    volumeName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
    volumeSize: "21474836480"
  status:
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-02T15:10:15Z"
      message: ""
      reason: ""
      status: "True"
      type: InstanceCreation
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-02T15:10:15Z"
      message: ""
      reason: ""
      status: "False"
      type: FilesystemReadOnly
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-02T15:10:49Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentState: running
    instanceManagerName: instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2
    ip: 10.42.4.98
    logFetched: false
    ownerID: walmsley
    port: 10279
    salvageExecuted: false
    started: true
    starting: false
    storageIP: 10.42.4.98
    uuid: 7d2112ac-40f5-4be1-a361-1cd7e7c11611
- apiVersion: longhorn.io/v1beta2
  kind: Replica
  metadata:
    creationTimestamp: "2026-07-02T15:10:14Z"
    finalizers:
    - longhorn.io
    generation: 4
    labels:
      longhorn.io/backing-image: ""
      longhorndiskuuid: 0742a187-2434-4fb2-964d-05ea99ae8690
      longhornnode: dauwalter
      longhornvolume: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
    name: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-r-c360cdfd
    namespace: longhorn-system
    ownerReferences:
    - apiVersion: longhorn.io/v1beta2
      kind: Volume
      name: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
      uid: ac0e818a-3bce-4260-9523-ad230a0eb680
    resourceVersion: "148194136"
    uid: 6373a0ad-e505-454f-9b5b-b851c6fae04b
  spec:
    active: true
    backingImage: ""
    dataDirectoryName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-579ffad4
    dataEngine: v1
    desireState: running
    diskID: 0742a187-2434-4fb2-964d-05ea99ae8690
    diskPath: /var/lib/longhorn/
    engineName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-e-0
    evictionRequested: false
    failedAt: ""
    hardNodeAffinity: ""
    healthyAt: "2026-07-02T15:10:58Z"
    image: longhornio/longhorn-engine:v1.10.1
    lastFailedAt: ""
    lastHealthyAt: "2026-07-02T15:10:58Z"
    logRequested: false
    migrationEngineName: ""
    nodeID: dauwalter
    rebuildRetryCount: 0
    revisionCounterDisabled: true
    salvageRequested: false
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    unmapMarkDiskChainRemovedEnabled: false
    volumeName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
    volumeSize: "21474836480"
  status:
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-02T15:10:14Z"
      message: ""
      reason: ""
      status: "True"
      type: InstanceCreation
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-02T15:10:14Z"
      message: ""
      reason: ""
      status: "False"
      type: FilesystemReadOnly
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-02T15:10:49Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentState: running
    instanceManagerName: instance-manager-7e677607497a70d7a9560e5c1a955448
    ip: 10.42.0.125
    logFetched: false
    ownerID: dauwalter
    port: 10141
    salvageExecuted: false
    started: true
    starting: false
    storageIP: 10.42.0.125
    uuid: ef55d4e5-f1fc-4f15-869d-d8dee63b23ac
- apiVersion: longhorn.io/v1beta2
  kind: Replica
  metadata:
    creationTimestamp: "2026-07-02T15:10:14Z"
    finalizers:
    - longhorn.io
    generation: 4
    labels:
      longhorn.io/backing-image: ""
      longhorndiskuuid: 413befa8-2e7e-45cc-8dd8-3bd8cb4dca49
      longhornnode: kipsang
      longhornvolume: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
    name: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-r-d9eda84b
    namespace: longhorn-system
    ownerReferences:
    - apiVersion: longhorn.io/v1beta2
      kind: Volume
      name: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
      uid: ac0e818a-3bce-4260-9523-ad230a0eb680
    resourceVersion: "148194137"
    uid: 55078769-911c-42da-8dd2-fd44f81e5b05
  spec:
    active: true
    backingImage: ""
    dataDirectoryName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-1d1d36e9
    dataEngine: v1
    desireState: running
    diskID: 413befa8-2e7e-45cc-8dd8-3bd8cb4dca49
    diskPath: /var/lib/longhorn/
    engineName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45-e-0
    evictionRequested: false
    failedAt: ""
    hardNodeAffinity: ""
    healthyAt: "2026-07-02T15:10:58Z"
    image: longhornio/longhorn-engine:v1.10.1
    lastFailedAt: ""
    lastHealthyAt: "2026-07-02T15:10:58Z"
    logRequested: false
    migrationEngineName: ""
    nodeID: kipsang
    rebuildRetryCount: 0
    revisionCounterDisabled: true
    salvageRequested: false
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    unmapMarkDiskChainRemovedEnabled: false
    volumeName: pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
    volumeSize: "21474836480"
  status:
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-02T15:10:14Z"
      message: ""
      reason: ""
      status: "True"
      type: InstanceCreation
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-02T15:10:14Z"
      message: ""
      reason: ""
      status: "False"
      type: FilesystemReadOnly
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-02T15:10:49Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentState: running
    instanceManagerName: instance-manager-7b720f693d6d43523767705e8e1d363d
    ip: 10.42.1.10
    logFetched: false
    ownerID: kipsang
    port: 10966
    salvageExecuted: false
    started: true
    starting: false
    storageIP: 10.42.1.10
    uuid: 1476f3e5-38fb-4452-965d-a60b1038aaa5
kind: List
metadata:
  resourceVersion: ""

## Longhorn share managers
NAME                                       STATE     NODE        AGE
pvc-417d4dc3-8d09-4bad-adee-2e984e394706   running   walmsley    82d
pvc-4d80a091-3336-45a2-88f1-2aad621c5c45   running   dauwalter   57m
pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec   running   fordyce     102d
pvc-830baa59-fa1c-4370-bd54-1ba55596e32a   running   walmsley    102d
pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0   running   fordyce     82d
pod/share-manager-pvc-417d4dc3-8d09-4bad-adee-2e984e394706   1/1     Running   0             10d   10.42.4.136   walmsley    <none>           <none>
pod/share-manager-pvc-4d80a091-3336-45a2-88f1-2aad621c5c45   1/1     Running   0             56m   10.42.0.59    dauwalter   <none>           <none>
pod/share-manager-pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec   1/1     Running   0             10d   10.42.3.62    fordyce     <none>           <none>
pod/share-manager-pvc-830baa59-fa1c-4370-bd54-1ba55596e32a   1/1     Running   0             10d   10.42.4.132   walmsley    <none>           <none>
pod/share-manager-pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0   1/1     Running   0             10d   10.42.3.61    fordyce     <none>           <none>
service/pvc-417d4dc3-8d09-4bad-adee-2e984e394706   ClusterIP   10.43.76.193    <none>        2049/TCP   82d    longhorn.io/managed-by=longhorn-manager,longhorn.io/share-manager=pvc-417d4dc3-8d09-4bad-adee-2e984e394706
service/pvc-4d80a091-3336-45a2-88f1-2aad621c5c45   ClusterIP   10.43.100.223   <none>        2049/TCP   56m    longhorn.io/managed-by=longhorn-manager,longhorn.io/share-manager=pvc-4d80a091-3336-45a2-88f1-2aad621c5c45
service/pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec   ClusterIP   10.43.148.178   <none>        2049/TCP   102d   longhorn.io/managed-by=longhorn-manager,longhorn.io/share-manager=pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec
service/pvc-830baa59-fa1c-4370-bd54-1ba55596e32a   ClusterIP   10.43.141.178   <none>        2049/TCP   102d   longhorn.io/managed-by=longhorn-manager,longhorn.io/share-manager=pvc-830baa59-fa1c-4370-bd54-1ba55596e32a
service/pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0   ClusterIP   10.43.153.61    <none>        2049/TCP   82d    longhorn.io/managed-by=longhorn-manager,longhorn.io/share-manager=pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0

## Longhorn node disks
node dauwalter
  disk longhorn-root: path=/var/lib/longhorn/ tags=nvme allowScheduling=True
node fordyce
  disk longhorn-root: path=/var/lib/longhorn/ tags=nvme allowScheduling=True
node kipsang
  disk default-disk-a312c1623e95d3ff: path=/var/lib/longhorn/ tags=nvme allowScheduling=True
  disk disk-2: path=/srv/data tags=sata allowScheduling=True
node selassie
  disk longhorn-root: path=/var/lib/longhorn/ tags=nvme allowScheduling=True
  disk longhorn-sata: path=/srv/data tags=sata allowScheduling=True
node walmsley
  disk default-disk-fe717b3b67c469ed: path=/var/lib/longhorn/ tags=nvme allowScheduling=True
  disk disk-3: path=/srv/data tags=sata allowScheduling=True
