# Longhorn Controlled RWX Run 001 Health

## Benchmark resources
NAME                                                                  READY   STATUS      RESTARTS   AGE    IP            NODE        NOMINATED NODE   READINESS GATES
pod/longhorn-rwx-controlled-remote-concurrent-dauwalter-run-00fwl6v   0/1     Completed   0          15m    10.42.0.136   dauwalter   <none>           <none>
pod/longhorn-rwx-controlled-remote-concurrent-selassie-run-0014lxbt   0/1     Completed   0          15m    10.42.2.174   selassie    <none>           <none>
pod/longhorn-rwx-controlled-remote-single-dauwalter-run-001-tbsl7     0/1     Completed   0          98m    10.42.0.135   dauwalter   <none>           <none>
pod/longhorn-rwx-controlled-remote-single-selassie-run-001-vmc2d      0/1     Completed   0          57m    10.42.2.173   selassie    <none>           <none>
pod/longhorn-rwx-controlled-serving-anchor-795bcc8cbd-q47w2           1/1     Running     0          98m    10.42.3.123   fordyce     <none>           <none>
pod/longhorn-rwx-proof-a-run-002                                      1/1     Running     0          131m   10.42.0.134   dauwalter   <none>           <none>
pod/longhorn-rwx-proof-b-run-002                                      1/1     Running     0          131m   10.42.2.172   selassie    <none>           <none>

NAME                                                                    STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/longhorn-rwx-controlled-remote-concurrent-dauwalter-run-001   Complete   1/1           13m        15m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=d6bc0d27-70d5-4e11-97f4-5a5fbb425c5e
job.batch/longhorn-rwx-controlled-remote-concurrent-selassie-run-001    Complete   1/1           12m        15m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=ce26344d-55ee-4bf3-b0eb-5e8d5f3beb6c
job.batch/longhorn-rwx-controlled-remote-single-dauwalter-run-001       Complete   1/1           41m        98m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=7426221e-bbe9-486f-adb9-e8a339bb9b64
job.batch/longhorn-rwx-controlled-remote-single-selassie-run-001        Complete   1/1           41m        57m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=b0bf4900-9cbd-4f5f-98f5-951fad7ed4d5

NAME                                                     READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES        SELECTOR
deployment.apps/longhorn-rwx-controlled-serving-anchor   1/1     1            1           131m   anchor       alpine:3.20   app=longhorn-rwx-controlled-serving-anchor

NAME                                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                            VOLUMEATTRIBUTESCLASS   AGE    VOLUMEMODE
persistentvolumeclaim/longhorn-rwx-controlled-pvc-run-001   Bound    pvc-ad63484e-ab39-4de4-9dc5-f80dbd8b3811   20Gi       RWX            longhorn-rwx-controlled-nvme-bench-3r   <unset>                 131m   Filesystem

## Fio pod node proof
NAME                                                              READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
longhorn-rwx-controlled-remote-concurrent-dauwalter-run-00fwl6v   0/1     Completed   0          15m   10.42.0.136   dauwalter   <none>           <none>
longhorn-rwx-controlled-remote-concurrent-selassie-run-0014lxbt   0/1     Completed   0          15m   10.42.2.174   selassie    <none>           <none>
longhorn-rwx-controlled-remote-single-dauwalter-run-001-tbsl7     0/1     Completed   0          98m   10.42.0.135   dauwalter   <none>           <none>
longhorn-rwx-controlled-remote-single-selassie-run-001-vmc2d      0/1     Completed   0          57m   10.42.2.173   selassie    <none>           <none>

## Serving anchor proof
NAME                                                      READY   STATUS    RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES
longhorn-rwx-controlled-serving-anchor-795bcc8cbd-q47w2   1/1     Running   0          98m   10.42.3.123   fordyce   <none>           <none>

## Longhorn share manager pods
NAME                                                     READY   STATUS    RESTARTS       AGE   IP            NODE        NOMINATED NODE   READINESS GATES
share-manager-pvc-417d4dc3-8d09-4bad-adee-2e984e394706   1/1     Running   0              11d   10.42.4.136   walmsley    <none>           <none>
share-manager-pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec   1/1     Running   0              11d   10.42.3.62    fordyce     <none>           <none>
share-manager-pvc-830baa59-fa1c-4370-bd54-1ba55596e32a   1/1     Running   0              11d   10.42.4.132   walmsley    <none>           <none>
share-manager-pvc-ad63484e-ab39-4de4-9dc5-f80dbd8b3811   1/1     Running   0              98m   10.42.1.61    kipsang     <none>           <none>
share-manager-pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0   1/1     Running   0              11d   10.42.3.61    fordyce     <none>           <none>

## Longhorn volumes
apiVersion: v1
items:
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2025-12-08T08:43:52Z"
    finalizers:
    - longhorn.io
    generation: 51
    labels:
      backup-target: default
      longhornvolume: pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48
    namespace: longhorn-system
    resourceVersion: "151358606"
    uid: f8d5413c-c37c-4326-ad5a-e3286941816d
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: kipsang
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
    actualSize: 41358761984
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2025-12-08T08:43:52Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:13Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2025-12-08T08:43:52Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2025-12-08T08:43:52Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: kipsang
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: monitoring
      pvName: pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48
      pvStatus: Bound
      pvcName: prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0
      workloadsStatus:
      - podName: prometheus-kube-prometheus-stack-prometheus-0
        podStatus: Running
        workloadName: prometheus-kube-prometheus-stack-prometheus
        workloadType: StatefulSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: kipsang
    remountRequestedAt: "2026-06-17T09:33:41Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-04-11T07:14:15Z"
    finalizers:
    - longhorn.io
    generation: 50
    labels:
      backup-target: default
      longhornvolume: pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083
    namespace: longhorn-system
    resourceVersion: "151350764"
    uid: 46a377c3-7e0e-4d24-87d4-e4f0132d20a8
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: kipsang
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
    size: "1073741824"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 91987968
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-11T07:14:15Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-11T07:14:15Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:13Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-11T07:14:16Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: kipsang
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: mosquitto
      pvName: pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083
      pvStatus: Bound
      pvcName: mosquitto-data
      workloadsStatus:
      - podName: mosquitto-6bdf7dccd7-csjlm
        podStatus: Running
        workloadName: mosquitto-6bdf7dccd7
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: kipsang
    remountRequestedAt: "2026-06-22T09:35:08Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-04-11T08:39:34Z"
    finalizers:
    - longhorn.io
    generation: 48
    labels:
      backup-target: default
      longhornvolume: pvc-417d4dc3-8d09-4bad-adee-2e984e394706
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-417d4dc3-8d09-4bad-adee-2e984e394706
    namespace: longhorn-system
    resourceVersion: "151351644"
    uid: 352ff557-461d-4f39-90ed-9376d8d7fece
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: walmsley
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
    size: "536870912"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 492867584
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-11T08:39:35Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-11T08:39:35Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:15Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-11T08:39:35Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: walmsley
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: home-assistant
      pvName: pvc-417d4dc3-8d09-4bad-adee-2e984e394706
      pvStatus: Bound
      pvcName: home-assistant-pvc
      workloadsStatus:
      - podName: home-assistant-595b88f764-c4447
        podStatus: Running
        workloadName: home-assistant-595b88f764
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: walmsley
    remountRequestedAt: "2026-06-22T15:16:15Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: nfs://10.43.76.193/pvc-417d4dc3-8d09-4bad-adee-2e984e394706
    shareState: running
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-03-22T11:05:56Z"
    finalizers:
    - longhorn.io
    generation: 48
    labels:
      backup-target: default
      longhornvolume: pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec
    namespace: longhorn-system
    resourceVersion: "151366869"
    uid: 4f640fc6-caab-47ac-92cf-dc7349ee7c6d
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: fordyce
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
    size: "5368709120"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 1570779136
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-22T11:05:57Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-22T11:05:57Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:22Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-22T11:05:57Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: fordyce
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: openclaw
      pvName: pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec
      pvStatus: Bound
      pvcName: openclaw-maildir
      workloadsStatus:
      - podName: openclaw-d7b8d49fb-x97gw
        podStatus: Running
        workloadName: openclaw-d7b8d49fb
        workloadType: ReplicaSet
      - podName: openclaw-mbsync-84dbb45b88-s8wt2
        podStatus: Running
        workloadName: openclaw-mbsync-84dbb45b88
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: fordyce
    remountRequestedAt: "2026-06-22T15:27:17Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: nfs://10.43.148.178/pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec
    shareState: running
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-03-24T16:00:10Z"
    finalizers:
    - longhorn.io
    generation: 36
    labels:
      backup-target: default
      longhornvolume: pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b
    namespace: longhorn-system
    resourceVersion: "151332822"
    uid: 54df2bb1-eef4-4acf-a021-4f960d5a024e
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: walmsley
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
    size: "10737418240"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 673767424
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-24T16:00:11Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-24T16:00:11Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:15Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-24T16:00:11Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: walmsley
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: matrix
      pvName: pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b
      pvStatus: Bound
      pvcName: matrix
      workloadsStatus:
      - podName: matrix-84fccc4d55-xtd6p
        podStatus: Running
        workloadName: matrix-84fccc4d55
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: walmsley
    remountRequestedAt: "2026-06-17T09:33:41Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-03-22T11:16:53Z"
    finalizers:
    - longhorn.io
    generation: 63
    labels:
      backup-target: default
      longhornvolume: pvc-830baa59-fa1c-4370-bd54-1ba55596e32a
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-830baa59-fa1c-4370-bd54-1ba55596e32a
    namespace: longhorn-system
    resourceVersion: "151366448"
    uid: ac7f3f4e-713f-4193-a5d8-d2c8b2828119
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
    - sata
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: walmsley
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
    size: "107374182400"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 2880
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 74081247232
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-22T11:16:54Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-22T11:16:54Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-22T15:27:23Z"
      message: 'precheck new replica failed: insufficient storage; tags not fulfilled'
      reason: ReplicaSchedulingFailure
      status: "False"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-22T11:16:54Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: walmsley
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: webmutt
      pvName: pvc-830baa59-fa1c-4370-bd54-1ba55596e32a
      pvStatus: Bound
      pvcName: webmutt-maildir
      workloadsStatus:
      - podName: webmutt-75c66488d9-t96vf
        podStatus: Running
        workloadName: webmutt-75c66488d9
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: "2026-06-22T15:03:08Z"
    ownerID: walmsley
    remountRequestedAt: "2026-06-22T15:01:07Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: degraded
    shareEndpoint: nfs://10.43.141.178/pvc-830baa59-fa1c-4370-bd54-1ba55596e32a
    shareState: running
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-04-03T11:14:35Z"
    finalizers:
    - longhorn.io
    generation: 24
    labels:
      backup-target: default
      longhornvolume: pvc-972b33e1-0574-4a37-b81e-9913be95e3b6
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-972b33e1-0574-4a37-b81e-9913be95e3b6
    namespace: longhorn-system
    resourceVersion: "151366707"
    uid: c2b6136f-f50e-4b55-a904-11a842200772
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: kipsang
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
    size: "8589934592"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 830332928
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-03T11:14:36Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-03T11:14:36Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:13Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-03T11:14:36Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: kipsang
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: matrix
      pvName: pvc-972b33e1-0574-4a37-b81e-9913be95e3b6
      pvStatus: Bound
      pvcName: data-matrix-postgresql-0
      workloadsStatus:
      - podName: matrix-postgresql-0
        podStatus: Running
        workloadName: matrix-postgresql
        workloadType: StatefulSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: kipsang
    remountRequestedAt: "2026-06-17T09:33:41Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-01-25T08:04:25Z"
    finalizers:
    - longhorn.io
    generation: 50
    labels:
      backup-target: default
      longhornvolume: pvc-a6835410-a25a-4f6d-ae79-b2a51738130a
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-a6835410-a25a-4f6d-ae79-b2a51738130a
    namespace: longhorn-system
    resourceVersion: "151356412"
    uid: edfbe0b2-b6a6-48f6-a822-a9247a70845b
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: walmsley
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
    size: "10737418240"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 13301448704
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-01-25T08:04:25Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-01-25T08:04:25Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:13Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-01-25T08:04:25Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: walmsley
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: victoria-logs
      pvName: pvc-a6835410-a25a-4f6d-ae79-b2a51738130a
      pvStatus: Bound
      pvcName: server-volume-victoria-logs-victoria-logs-single-server-0
      workloadsStatus:
      - podName: victoria-logs-victoria-logs-single-server-0
        podStatus: Running
        workloadName: victoria-logs-victoria-logs-single-server
        workloadType: StatefulSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: walmsley
    remountRequestedAt: "2026-06-22T09:35:07Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-07-04T09:05:05Z"
    finalizers:
    - longhorn.io
    generation: 2
    labels:
      backup-target: default
      longhornvolume: pvc-ad63484e-ab39-4de4-9dc5-f80dbd8b3811
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-ad63484e-ab39-4de4-9dc5-f80dbd8b3811
    namespace: longhorn-system
    resourceVersion: "151365657"
    uid: b37b4d11-ac9a-401a-93e4-54d074c62854
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
    nodeID: kipsang
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
    actualSize: 20475424768
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-04T09:05:06Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-04T09:05:06Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-04T09:05:06Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-07-04T09:05:06Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: kipsang
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: storage-benchmark-rwx
      pvName: pvc-ad63484e-ab39-4de4-9dc5-f80dbd8b3811
      pvStatus: Bound
      pvcName: longhorn-rwx-controlled-pvc-run-001
      workloadsStatus:
      - podName: longhorn-rwx-controlled-remote-concurrent-dauwalter-run-00fwl6v
        podStatus: Succeeded
        workloadName: longhorn-rwx-controlled-remote-concurrent-dauwalter-run-001
        workloadType: Job
      - podName: longhorn-rwx-controlled-remote-concurrent-selassie-run-0014lxbt
        podStatus: Succeeded
        workloadName: longhorn-rwx-controlled-remote-concurrent-selassie-run-001
        workloadType: Job
      - podName: longhorn-rwx-controlled-remote-single-dauwalter-run-001-tbsl7
        podStatus: Succeeded
        workloadName: longhorn-rwx-controlled-remote-single-dauwalter-run-001
        workloadType: Job
      - podName: longhorn-rwx-controlled-remote-single-selassie-run-001-vmc2d
        podStatus: Succeeded
        workloadName: longhorn-rwx-controlled-remote-single-selassie-run-001
        workloadType: Job
      - podName: longhorn-rwx-controlled-serving-anchor-795bcc8cbd-q47w2
        podStatus: Running
        workloadName: longhorn-rwx-controlled-serving-anchor-795bcc8cbd
        workloadType: ReplicaSet
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
    ownerID: kipsang
    remountRequestedAt: ""
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: nfs://10.43.212.241/pvc-ad63484e-ab39-4de4-9dc5-f80dbd8b3811
    shareState: running
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-04-05T07:24:00Z"
    finalizers:
    - longhorn.io
    generation: 56
    labels:
      backup-target: default
      longhornvolume: pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c
    namespace: longhorn-system
    resourceVersion: "151333146"
    uid: fffd502e-30f4-4cee-8f83-9294e36e30d4
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: walmsley
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
    size: "10737418240"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 459255808
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-05T07:24:00Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-05T07:24:00Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:15Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-05T07:24:00Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: walmsley
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: forgejo
      pvName: pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c
      pvStatus: Bound
      pvcName: gitea-shared-storage
      workloadsStatus:
      - podName: forgejo-578d8d959b-dt59k
        podStatus: Running
        workloadName: forgejo-578d8d959b
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: walmsley
    remountRequestedAt: "2026-06-17T09:33:41Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-04-11T13:59:08Z"
    finalizers:
    - longhorn.io
    generation: 52
    labels:
      backup-target: default
      longhornvolume: pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0
    namespace: longhorn-system
    resourceVersion: "151303952"
    uid: d23dcdd4-f470-482e-a293-d8284e75b0e2
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
    - sata
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: fordyce
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
    size: "1099511627776"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 2880
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 524989091840
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-11T13:59:09Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-11T13:59:09Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-22T15:37:32Z"
      message: 'precheck new replica failed: insufficient storage'
      reason: ReplicaSchedulingFailure
      status: "False"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-04-11T13:59:10Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: fordyce
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: jellyfin
      pvName: pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0
      pvStatus: Bound
      pvcName: media-pvc
      workloadsStatus:
      - podName: copyparty-79766bf464-pbh5b
        podStatus: Running
        workloadName: copyparty-79766bf464
        workloadType: ReplicaSet
      - podName: jellyfin-5c7449ff5d-g788f
        podStatus: Running
        workloadName: jellyfin-5c7449ff5d
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: "2026-06-22T15:27:31Z"
    ownerID: fordyce
    remountRequestedAt: "2026-06-22T15:27:17Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: degraded
    shareEndpoint: nfs://10.43.153.61/pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0
    shareState: running
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-01-24T16:37:48Z"
    finalizers:
    - longhorn.io
    generation: 46
    labels:
      backup-target: default
      longhornvolume: pvc-cccf0c12-09ed-4209-92b2-96419ec81e15
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-cccf0c12-09ed-4209-92b2-96419ec81e15
    namespace: longhorn-system
    resourceVersion: "151364661"
    uid: 94316048-96ad-4895-92e3-c6451a3ad2fe
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: kipsang
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
    size: "2147483648"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 278097920
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-01-24T16:37:49Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-01-24T16:37:49Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:13Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-01-24T16:37:49Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: kipsang
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: openziti
      pvName: pvc-cccf0c12-09ed-4209-92b2-96419ec81e15
      pvStatus: Bound
      pvcName: openziti-controller
      workloadsStatus:
      - podName: openziti-controller-64797f7c4c-hrmw4
        podStatus: Running
        workloadName: openziti-controller-64797f7c4c
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: kipsang
    remountRequestedAt: "2026-06-20T09:23:37Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-01-26T07:41:36Z"
    finalizers:
    - longhorn.io
    generation: 60
    labels:
      backup-target: default
      longhornvolume: pvc-db52bf7e-393d-4d28-81f0-4774369b7c42
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-db52bf7e-393d-4d28-81f0-4774369b7c42
    namespace: longhorn-system
    resourceVersion: "151235025"
    uid: 1687c432-81cf-452e-855c-1c72b0de1a2e
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: walmsley
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
    size: "10737418240"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 1339002880
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-01-26T07:41:36Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-01-26T07:41:36Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:22Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-01-26T07:41:37Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: walmsley
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: nextcloud
      pvName: pvc-db52bf7e-393d-4d28-81f0-4774369b7c42
      pvStatus: Bound
      pvcName: nextcloud-nextcloud
      workloadsStatus:
      - podName: nextcloud-5dcfd4bbb-6g4kz
        podStatus: Running
        workloadName: nextcloud-5dcfd4bbb
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: walmsley
    remountRequestedAt: "2026-06-21T14:08:00Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-03-04T07:41:27Z"
    finalizers:
    - longhorn.io
    generation: 53
    labels:
      backup-target: default
      longhornvolume: pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec
    namespace: longhorn-system
    resourceVersion: "151366872"
    uid: 06327270-6d86-4c26-a265-7c41b22e4e71
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: walmsley
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
    size: "10737418240"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 8000712704
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-04T07:41:28Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-04T07:41:28Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:17Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-03-04T07:41:28Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: walmsley
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: openclaw
      pvName: pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec
      pvStatus: Bound
      pvcName: openclaw
      workloadsStatus:
      - podName: openclaw-d7b8d49fb-x97gw
        podStatus: Running
        workloadName: openclaw-d7b8d49fb
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: walmsley
    remountRequestedAt: "2026-06-22T09:35:07Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
- apiVersion: longhorn.io/v1beta2
  kind: Volume
  metadata:
    creationTimestamp: "2026-05-05T13:08:32Z"
    finalizers:
    - longhorn.io
    generation: 44
    labels:
      backup-target: default
      longhornvolume: pvc-f2a47938-9a54-4c8e-9384-1570563b9971
      recurring-job-group.longhorn.io/default: enabled
      setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
      setting.longhorn.io/replica-auto-balance: ignored
      setting.longhorn.io/snapshot-data-integrity: ignored
    name: pvc-f2a47938-9a54-4c8e-9384-1570563b9971
    namespace: longhorn-system
    resourceVersion: "148315034"
    uid: 7fe6932e-39ab-449a-bb26-619206a89129
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
    diskSelector: []
    encrypted: false
    freezeFilesystemForSnapshot: ignored
    fromBackup: ""
    frontend: blockdev
    image: longhornio/longhorn-engine:v1.10.1
    lastAttachedBy: ""
    migratable: false
    migrationNodeID: ""
    nodeID: walmsley
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
    size: "52428800"
    snapshotDataIntegrity: ignored
    snapshotMaxCount: 250
    snapshotMaxSize: "0"
    staleReplicaTimeout: 30
    unmapMarkSnapChainRemoved: ignored
  status:
    actualSize: 51175424
    cloneStatus:
      attemptCount: 0
      nextAllowedAttemptAt: ""
      snapshot: ""
      sourceVolume: ""
      state: ""
    conditions:
    - lastProbeTime: ""
      lastTransitionTime: "2026-05-05T13:08:33Z"
      message: ""
      reason: ""
      status: "False"
      type: WaitForBackingImage
    - lastProbeTime: ""
      lastTransitionTime: "2026-05-05T13:08:33Z"
      message: ""
      reason: ""
      status: "False"
      type: TooManySnapshots
    - lastProbeTime: ""
      lastTransitionTime: "2026-06-21T13:19:22Z"
      message: ""
      reason: ""
      status: "True"
      type: Scheduled
    - lastProbeTime: ""
      lastTransitionTime: "2026-05-05T13:08:34Z"
      message: ""
      reason: ""
      status: "False"
      type: Restore
    currentImage: longhornio/longhorn-engine:v1.10.1
    currentMigrationNodeID: ""
    currentNodeID: walmsley
    expansionRequired: false
    frontendDisabled: false
    isStandby: false
    kubernetesStatus:
      lastPVCRefAt: ""
      lastPodRefAt: ""
      namespace: openziti
      pvName: pvc-f2a47938-9a54-4c8e-9384-1570563b9971
      pvStatus: Bound
      pvcName: openziti-router
      workloadsStatus:
      - podName: openziti-router-5495cbb496-gnndk
        podStatus: Running
        workloadName: openziti-router-5495cbb496
        workloadType: ReplicaSet
    lastBackup: ""
    lastBackupAt: ""
    lastDegradedAt: ""
    ownerID: walmsley
    remountRequestedAt: "2026-06-21T14:08:00Z"
    restoreInitiated: false
    restoreRequired: false
    robustness: healthy
    shareEndpoint: ""
    shareState: ""
    state: attached
kind: List
metadata:
  resourceVersion: ""

## Node taints after run
["dauwalter",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-02T19:52:50Z"}]]
["fordyce",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-02T19:52:50Z"}]]
["kipsang",[]]
["selassie",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-02T19:52:50Z"}]]
["walmsley",[]]
