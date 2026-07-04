# Longhorn Controlled RWX Run 001 Health

## ArgoCD applications
NAME                                        SYNC STATUS   HEALTH STATUS
root                                        Synced        Healthy
storage-benchmark-rwx-controlled-longhorn   OutOfSync     Healthy

## Benchmark resources
NAME                                                                  READY   STATUS      RESTARTS   AGE    IP            NODE        NOMINATED NODE   READINESS GATES
pod/longhorn-rwx-controlled-remote-concurrent-dauwalter-run-005cgwj   0/1     Completed   0          15m    10.42.0.173   dauwalter   <none>           <none>
pod/longhorn-rwx-controlled-remote-concurrent-selassie-run-001rsn25   0/1     Completed   0          15m    10.42.2.205   selassie    <none>           <none>
pod/longhorn-rwx-controlled-remote-single-dauwalter-run-001-tkjn6     0/1     Completed   0          103m   10.42.0.172   dauwalter   <none>           <none>
pod/longhorn-rwx-controlled-remote-single-selassie-run-001-svzc8      0/1     Completed   0          59m    10.42.2.204   selassie    <none>           <none>
pod/longhorn-rwx-controlled-serving-anchor-795bcc8cbd-sd945           1/1     Running     0          103m   10.42.3.153   fordyce     <none>           <none>
pod/longhorn-rwx-proof-a-run-002                                      1/1     Running     0          103m   10.42.0.171   dauwalter   <none>           <none>
pod/longhorn-rwx-proof-b-run-002                                      1/1     Running     0          103m   10.42.2.203   selassie    <none>           <none>

NAME                                                                    STATUS     COMPLETIONS   DURATION   AGE    CONTAINERS   IMAGES                              SELECTOR
job.batch/longhorn-rwx-controlled-remote-concurrent-dauwalter-run-001   Complete   1/1           15m        15m    fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=145c3f0e-82fd-4733-a080-a6bac901904e
job.batch/longhorn-rwx-controlled-remote-concurrent-selassie-run-001    Complete   1/1           14m        15m    fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=a7453ae6-05c8-45e9-b624-46e8a507bae1
job.batch/longhorn-rwx-controlled-remote-single-dauwalter-run-001       Complete   1/1           43m        103m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=eddc0863-d3c8-46af-b6b0-33392ad56198
job.batch/longhorn-rwx-controlled-remote-single-selassie-run-001        Complete   1/1           43m        59m    fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=8d1a2437-6044-4ceb-bf2d-5aee5caa978a

NAME                                                     READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES        SELECTOR
deployment.apps/longhorn-rwx-controlled-serving-anchor   1/1     1            1           103m   anchor       alpine:3.20   app=longhorn-rwx-controlled-serving-anchor

NAME                                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                            VOLUMEATTRIBUTESCLASS   AGE    VOLUMEMODE
persistentvolumeclaim/longhorn-rwx-controlled-pvc-run-001   Bound    pvc-28d642c9-5b7e-4d22-934f-4f549ab98c34   20Gi       RWX            longhorn-rwx-controlled-nvme-bench-3r   <unset>                 104m   Filesystem

## Fio pod node proof
NAME                                                              READY   STATUS      RESTARTS   AGE    IP            NODE        NOMINATED NODE   READINESS GATES
longhorn-rwx-controlled-remote-concurrent-dauwalter-run-005cgwj   0/1     Completed   0          15m    10.42.0.173   dauwalter   <none>           <none>
longhorn-rwx-controlled-remote-concurrent-selassie-run-001rsn25   0/1     Completed   0          15m    10.42.2.205   selassie    <none>           <none>
longhorn-rwx-controlled-remote-single-dauwalter-run-001-tkjn6     0/1     Completed   0          103m   10.42.0.172   dauwalter   <none>           <none>
longhorn-rwx-controlled-remote-single-selassie-run-001-svzc8      0/1     Completed   0          59m    10.42.2.204   selassie    <none>           <none>

## Serving anchor proof
NAME                                                      READY   STATUS    RESTARTS   AGE    IP            NODE      NOMINATED NODE   READINESS GATES
longhorn-rwx-controlled-serving-anchor-795bcc8cbd-sd945   1/1     Running   0          103m   10.42.3.153   fordyce   <none>           <none>

## Controlled PV name
pvc-28d642c9-5b7e-4d22-934f-4f549ab98c34

## Longhorn controlled share manager pod
NAME                                                     READY   STATUS    RESTARTS   AGE    IP            NODE      NOMINATED NODE   READINESS GATES
share-manager-pvc-28d642c9-5b7e-4d22-934f-4f549ab98c34   1/1     Running   0          103m   10.42.3.152   fordyce   <none>           <none>

## Longhorn controlled volume YAML
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  creationTimestamp: "2026-07-04T16:14:06Z"
  finalizers:
  - longhorn.io
  generation: 2
  labels:
    backup-target: default
    longhornvolume: pvc-28d642c9-5b7e-4d22-934f-4f549ab98c34
    recurring-job-group.longhorn.io/default: enabled
    setting.longhorn.io/remove-snapshots-during-filesystem-trim: ignored
    setting.longhorn.io/replica-auto-balance: ignored
    setting.longhorn.io/snapshot-data-integrity: ignored
  name: pvc-28d642c9-5b7e-4d22-934f-4f549ab98c34
  namespace: longhorn-system
  resourceVersion: "151610262"
  uid: f293bb6e-6b27-43f9-8e82-84adbfd263be
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
  size: "21474836480"
  snapshotDataIntegrity: ignored
  snapshotMaxCount: 250
  snapshotMaxSize: "0"
  staleReplicaTimeout: 30
  unmapMarkSnapChainRemoved: ignored
status:
  actualSize: 20391518208
  cloneStatus:
    attemptCount: 0
    nextAllowedAttemptAt: ""
    snapshot: ""
    sourceVolume: ""
    state: ""
  conditions:
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-04T16:14:07Z"
    message: ""
    reason: ""
    status: "False"
    type: WaitForBackingImage
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-04T16:14:07Z"
    message: ""
    reason: ""
    status: "False"
    type: TooManySnapshots
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-04T16:14:07Z"
    message: ""
    reason: ""
    status: "True"
    type: Scheduled
  - lastProbeTime: ""
    lastTransitionTime: "2026-07-04T16:14:07Z"
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
    namespace: storage-benchmark-rwx
    pvName: pvc-28d642c9-5b7e-4d22-934f-4f549ab98c34
    pvStatus: Bound
    pvcName: longhorn-rwx-controlled-pvc-run-001
    workloadsStatus:
    - podName: longhorn-rwx-controlled-remote-concurrent-dauwalter-run-005cgwj
      podStatus: Succeeded
      workloadName: longhorn-rwx-controlled-remote-concurrent-dauwalter-run-001
      workloadType: Job
    - podName: longhorn-rwx-controlled-remote-concurrent-selassie-run-001rsn25
      podStatus: Succeeded
      workloadName: longhorn-rwx-controlled-remote-concurrent-selassie-run-001
      workloadType: Job
    - podName: longhorn-rwx-controlled-remote-single-dauwalter-run-001-tkjn6
      podStatus: Succeeded
      workloadName: longhorn-rwx-controlled-remote-single-dauwalter-run-001
      workloadType: Job
    - podName: longhorn-rwx-controlled-remote-single-selassie-run-001-svzc8
      podStatus: Succeeded
      workloadName: longhorn-rwx-controlled-remote-single-selassie-run-001
      workloadType: Job
    - podName: longhorn-rwx-controlled-serving-anchor-795bcc8cbd-sd945
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
  ownerID: fordyce
  remountRequestedAt: ""
  restoreInitiated: false
  restoreRequired: false
  robustness: healthy
  shareEndpoint: nfs://10.43.198.74/pvc-28d642c9-5b7e-4d22-934f-4f549ab98c34
  shareState: running
  state: attached

## Node taints after run
["dauwalter",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-04T12:51:20Z"}]]
["fordyce",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-04T12:51:20Z"}]]
["kipsang",[]]
["selassie",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-04T12:51:20Z"}]]
["walmsley",[]]
