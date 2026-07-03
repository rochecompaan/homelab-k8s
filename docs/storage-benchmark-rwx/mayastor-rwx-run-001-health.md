# Mayastor-backed RWX via NFS run 001 health

Captured: 2026-07-03T10:36:36Z

Note: This is Mayastor-backed RWX via an NFS server and NFS CSI, not native Mayastor block RWX.

## ArgoCD applications
NAME                             SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
root                             Synced        Healthy         c08feb559fd30e4777ddf1cb06b3385254ad057e   default
openebs-mayastor                 OutOfSync     Progressing     4.5.1                                      default
csi-driver-nfs-rwx-benchmark     Synced        Healthy         4.13.3                                     default
storage-benchmark-rwx-mayastor   OutOfSync     Healthy         c08feb559fd30e4777ddf1cb06b3385254ad057e   default

## Benchmark resources
NAME                                                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS              VOLUMEATTRIBUTESCLASS   AGE     VOLUMEMODE
persistentvolumeclaim/mayastor-rwx-nfs-backend-pvc-run-001   Bound    pvc-b1c72dc4-ff47-4888-a304-113ea8a0d939   20Gi       RWO            mayastor-rwx-backend-3r   <unset>                 4h23m   Filesystem
persistentvolumeclaim/mayastor-rwx-pvc-run-001               Bound    pvc-4de06eb1-27f6-4751-8dca-60d0839cdc38   20Gi       RWX            mayastor-rwx-nfs-csi      <unset>                 113m    Filesystem

NAME                                           READY   STATUS      RESTARTS   AGE    IP            NODE        NOMINATED NODE   READINESS GATES
pod/mayastor-rwx-fio-run-001-0-z7sv2           0/1     Completed   0          113m   10.42.0.132   dauwalter   <none>           <none>
pod/mayastor-rwx-fio-run-001-1-smmkh           0/1     Completed   0          113m   10.42.2.171   selassie    <none>           <none>
pod/mayastor-rwx-fio-run-001-2-dnpgd           0/1     Completed   0          113m   10.42.3.122   fordyce     <none>           <none>
pod/mayastor-rwx-nfs-server-66b8948fc7-2qm26   1/1     Running     0          113m   10.42.3.120   fordyce     <none>           <none>
pod/mayastor-rwx-proof-a                       1/1     Running     0          113m   10.42.3.121   fordyce     <none>           <none>
pod/mayastor-rwx-proof-b                       1/1     Running     0          113m   10.42.2.170   selassie    <none>           <none>

NAME                                 STATUS     COMPLETIONS   DURATION   AGE    CONTAINERS   IMAGES                              SELECTOR
job.batch/mayastor-rwx-fio-run-001   Complete   3/3           55m        113m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=61b9df80-007e-4a4b-adc6-e91ac88a5e02

NAME                              TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE     SELECTOR
service/mayastor-rwx-nfs-server   ClusterIP   10.43.22.72   <none>        2049/TCP   4h23m   app=mayastor-rwx-nfs-server

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES                                   SELECTOR
deployment.apps/mayastor-rwx-nfs-server   1/1     1            1           4h23m   nfs-server   itsthenetwork/nfs-server-alpine:latest   app=mayastor-rwx-nfs-server

## Backend PVC YAML (mayastor-rwx-nfs-backend-pvc-run-001)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/tracking-id: storage-benchmark-rwx-mayastor:/PersistentVolumeClaim:storage-benchmark-rwx/mayastor-rwx-nfs-backend-pvc-run-001
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"1","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-mayastor:/PersistentVolumeClaim:storage-benchmark-rwx/mayastor-rwx-nfs-backend-pvc-run-001"},"labels":{"app.kubernetes.io/name":"storage-benchmark-rwx","storage.compaan.io/backend":"mayastor-rwx","storage.compaan.io/role":"nfs-backend"},"name":"mayastor-rwx-nfs-backend-pvc-run-001","namespace":"storage-benchmark-rwx"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"20Gi"}},"storageClassName":"mayastor-rwx-backend-3r"}}
    pv.kubernetes.io/bind-completed: "yes"
    pv.kubernetes.io/bound-by-controller: "yes"
    volume.beta.kubernetes.io/storage-provisioner: io.openebs.csi-mayastor
    volume.kubernetes.io/selected-node: fordyce
    volume.kubernetes.io/storage-provisioner: io.openebs.csi-mayastor
  creationTimestamp: "2026-07-03T06:13:19Z"
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: mayastor-rwx
    storage.compaan.io/role: nfs-backend
  name: mayastor-rwx-nfs-backend-pvc-run-001
  namespace: storage-benchmark-rwx
  resourceVersion: "150502300"
  uid: b1c72dc4-ff47-4888-a304-113ea8a0d939
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: mayastor-rwx-backend-3r
  volumeMode: Filesystem
  volumeName: pvc-b1c72dc4-ff47-4888-a304-113ea8a0d939
status:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 20Gi
  phase: Bound

## Backend PV pvc-b1c72dc4-ff47-4888-a304-113ea8a0d939
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: io.openebs.csi-mayastor
    volume.kubernetes.io/provisioner-deletion-secret-name: ""
    volume.kubernetes.io/provisioner-deletion-secret-namespace: ""
  creationTimestamp: "2026-07-03T08:42:51Z"
  finalizers:
  - external-provisioner.volume.kubernetes.io/finalizer
  - kubernetes.io/pv-protection
  - external-attacher/io-openebs-csi-mayastor
  name: pvc-b1c72dc4-ff47-4888-a304-113ea8a0d939
  resourceVersion: "150502312"
  uid: 742a6f06-3dba-4522-a285-a0a1ec02baf6
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 20Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: mayastor-rwx-nfs-backend-pvc-run-001
    namespace: storage-benchmark-rwx
    resourceVersion: "150502288"
    uid: b1c72dc4-ff47-4888-a304-113ea8a0d939
  csi:
    driver: io.openebs.csi-mayastor
    fsType: ext4
    volumeAttributes:
      csi.storage.k8s.io/pv/name: pvc-b1c72dc4-ff47-4888-a304-113ea8a0d939
      csi.storage.k8s.io/pvc/name: mayastor-rwx-nfs-backend-pvc-run-001
      csi.storage.k8s.io/pvc/namespace: storage-benchmark-rwx
      protocol: nvmf
      repl: "3"
      storage.kubernetes.io/csiProvisionerIdentity: 1782468104041-7482-io.openebs.csi-mayastor
    volumeHandle: b1c72dc4-ff47-4888-a304-113ea8a0d939
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: openebs.io/csi-node
          operator: In
          values:
          - mayastor
        - key: openebs.io/engine
          operator: In
          values:
          - mayastor
  persistentVolumeReclaimPolicy: Delete
  storageClassName: mayastor-rwx-backend-3r
  volumeMode: Filesystem
status:
  lastPhaseTransitionTime: "2026-07-03T08:42:51Z"
  phase: Bound

## RWX PVC YAML (mayastor-rwx-pvc-run-001)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
    argocd.argoproj.io/tracking-id: storage-benchmark-rwx-mayastor:/PersistentVolumeClaim:storage-benchmark-rwx/mayastor-rwx-pvc-run-001
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"2","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-mayastor:/PersistentVolumeClaim:storage-benchmark-rwx/mayastor-rwx-pvc-run-001"},"labels":{"app.kubernetes.io/name":"storage-benchmark-rwx","storage.compaan.io/backend":"mayastor-rwx"},"name":"mayastor-rwx-pvc-run-001","namespace":"storage-benchmark-rwx"},"spec":{"accessModes":["ReadWriteMany"],"resources":{"requests":{"storage":"20Gi"}},"storageClassName":"mayastor-rwx-nfs-csi"}}
    pv.kubernetes.io/bind-completed: "yes"
    pv.kubernetes.io/bound-by-controller: "yes"
    volume.beta.kubernetes.io/storage-provisioner: nfs.csi.k8s.io
    volume.kubernetes.io/storage-provisioner: nfs.csi.k8s.io
  creationTimestamp: "2026-07-03T08:43:06Z"
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: mayastor-rwx
  name: mayastor-rwx-pvc-run-001
  namespace: storage-benchmark-rwx
  resourceVersion: "150502532"
  uid: 4de06eb1-27f6-4751-8dca-60d0839cdc38
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
  storageClassName: mayastor-rwx-nfs-csi
  volumeMode: Filesystem
  volumeName: pvc-4de06eb1-27f6-4751-8dca-60d0839cdc38
status:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 20Gi
  phase: Bound

## RWX PV pvc-4de06eb1-27f6-4751-8dca-60d0839cdc38
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: nfs.csi.k8s.io
    volume.kubernetes.io/provisioner-deletion-secret-name: ""
    volume.kubernetes.io/provisioner-deletion-secret-namespace: ""
  creationTimestamp: "2026-07-03T08:43:06Z"
  finalizers:
  - external-provisioner.volume.kubernetes.io/finalizer
  - kubernetes.io/pv-protection
  name: pvc-4de06eb1-27f6-4751-8dca-60d0839cdc38
  resourceVersion: "150502517"
  uid: ad0f0d2f-de12-4abf-ad35-d05fc917f358
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 20Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: mayastor-rwx-pvc-run-001
    namespace: storage-benchmark-rwx
    resourceVersion: "150502486"
    uid: 4de06eb1-27f6-4751-8dca-60d0839cdc38
  csi:
    driver: nfs.csi.k8s.io
    volumeAttributes:
      csi.storage.k8s.io/pv/name: pvc-4de06eb1-27f6-4751-8dca-60d0839cdc38
      csi.storage.k8s.io/pvc/name: mayastor-rwx-pvc-run-001
      csi.storage.k8s.io/pvc/namespace: storage-benchmark-rwx
      server: mayastor-rwx-nfs-server.storage-benchmark-rwx.svc.cluster.local
      share: /
      storage.kubernetes.io/csiProvisionerIdentity: 1783059264585-1557-nfs.csi.k8s.io
      subdir: pvc-4de06eb1-27f6-4751-8dca-60d0839cdc38
    volumeHandle: mayastor-rwx-nfs-server.storage-benchmark-rwx.svc.cluster.local##pvc-4de06eb1-27f6-4751-8dca-60d0839cdc38##
  mountOptions:
  - nfsvers=4.1
  persistentVolumeReclaimPolicy: Delete
  storageClassName: mayastor-rwx-nfs-csi
  volumeMode: Filesystem
status:
  lastPhaseTransitionTime: "2026-07-03T08:43:06Z"
  phase: Bound

## StorageClass mayastor-rwx-backend-3r
allowVolumeExpansion: false
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    argocd.argoproj.io/tracking-id: storage-benchmark-rwx-mayastor:storage.k8s.io/StorageClass:storage-benchmark-rwx/mayastor-rwx-backend-3r
    kubectl.kubernetes.io/last-applied-configuration: |
      {"allowVolumeExpansion":false,"apiVersion":"storage.k8s.io/v1","kind":"StorageClass","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"0","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-mayastor:storage.k8s.io/StorageClass:storage-benchmark-rwx/mayastor-rwx-backend-3r"},"labels":{"storage.compaan.io/backend":"mayastor-rwx","storage.compaan.io/benchmark":"true"},"name":"mayastor-rwx-backend-3r"},"parameters":{"protocol":"nvmf","repl":"3"},"provisioner":"io.openebs.csi-mayastor","reclaimPolicy":"Delete","volumeBindingMode":"WaitForFirstConsumer"}
  creationTimestamp: "2026-07-03T06:13:17Z"
  labels:
    storage.compaan.io/backend: mayastor-rwx
    storage.compaan.io/benchmark: "true"
  name: mayastor-rwx-backend-3r
  resourceVersion: "150415318"
  uid: 9b557579-a2b1-439e-bc98-10b0fc2142e2
parameters:
  protocol: nvmf
  repl: "3"
provisioner: io.openebs.csi-mayastor
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer

## StorageClass mayastor-rwx-nfs-csi
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    argocd.argoproj.io/tracking-id: csi-driver-nfs-rwx-benchmark:storage.k8s.io/StorageClass:csi-nfs/mayastor-rwx-nfs-csi
    kubectl.kubernetes.io/last-applied-configuration: |
      {"allowVolumeExpansion":true,"apiVersion":"storage.k8s.io/v1","kind":"StorageClass","metadata":{"annotations":{"argocd.argoproj.io/tracking-id":"csi-driver-nfs-rwx-benchmark:storage.k8s.io/StorageClass:csi-nfs/mayastor-rwx-nfs-csi"},"labels":{"app.kubernetes.io/instance":"csi-driver-nfs-rwx-benchmark","app.kubernetes.io/managed-by":"Helm","app.kubernetes.io/name":"csi-driver-nfs","app.kubernetes.io/version":"4.13.3","helm.sh/chart":"csi-driver-nfs-4.13.3"},"name":"mayastor-rwx-nfs-csi"},"mountOptions":["nfsvers=4.1"],"parameters":{"server":"mayastor-rwx-nfs-server.storage-benchmark-rwx.svc.cluster.local","share":"/"},"provisioner":"nfs.csi.k8s.io","reclaimPolicy":"Delete","volumeBindingMode":"Immediate"}
  creationTimestamp: "2026-07-03T06:13:13Z"
  labels:
    app.kubernetes.io/instance: csi-driver-nfs-rwx-benchmark
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: csi-driver-nfs
    app.kubernetes.io/version: 4.13.3
    helm.sh/chart: csi-driver-nfs-4.13.3
  name: mayastor-rwx-nfs-csi
  resourceVersion: "150415188"
  uid: a0fa7689-e683-491e-a760-5ed1c413d113
mountOptions:
- nfsvers=4.1
parameters:
  server: mayastor-rwx-nfs-server.storage-benchmark-rwx.svc.cluster.local
  share: /
provisioner: nfs.csi.k8s.io
reclaimPolicy: Delete
volumeBindingMode: Immediate

## OpenEBS DiskPools
NAME                           NODE        STATE     STATUS   ERROR   ALERTS    ENCRYPTED   CAPACITY   USED     AVAILABLE   DISK-CAPACITY   MAX-EXPANDABLE-SIZE
mayastor-rwx-bench-dauwalter   dauwalter   Created   Online           Healthy   false       30 GiB     20 GiB   10 GiB      30 GiB          127.8 GiB
mayastor-rwx-bench-fordyce     fordyce     Created   Online           Healthy   false       30 GiB     20 GiB   10 GiB      30 GiB          127.8 GiB
mayastor-rwx-bench-selassie    selassie    Created   Online           Healthy   false       30 GiB     20 GiB   10 GiB      30 GiB          127.8 GiB

apiVersion: v1
items:
- apiVersion: openebs.io/v1beta3
  kind: DiskPool
  metadata:
    annotations:
      argocd.argoproj.io/sync-wave: "0"
      argocd.argoproj.io/tracking-id: storage-benchmark-rwx-mayastor:openebs.io/DiskPool:openebs/mayastor-rwx-bench-dauwalter
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"openebs.io/v1beta3","kind":"DiskPool","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"0","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-mayastor:openebs.io/DiskPool:openebs/mayastor-rwx-bench-dauwalter"},"name":"mayastor-rwx-bench-dauwalter","namespace":"openebs"},"spec":{"disks":["aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench"],"maxExpansion":"1x","node":"dauwalter"}}
    creationTimestamp: "2026-07-03T06:13:17Z"
    finalizers:
    - openebs.io/diskpool-protection
    generation: 1
    name: mayastor-rwx-bench-dauwalter
    namespace: openebs
    resourceVersion: "150502315"
    uid: a9f4ece8-09e6-4bf9-a2d2-543bf123e0e8
  spec:
    disks:
    - aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench
    maxExpansion: 1x
    node: dauwalter
  status:
    alertError: Healthy
    available: 10703863808
    available_q: 10 GiB
    capacity: 32178700288
    capacity_q: 30 GiB
    clusterSize: 4 MiB
    conditions:
    - lastTransitionTime: "2026-07-03T06:13:17Z"
      message: ""
      observedGeneration: 1
      reason: ""
      status: "True"
      type: PoolReady
    cr_state: Created
    diskCapacity: 30 GiB
    encrypted: false
    errorInfo:
      alerts:
        attention: []
        critical: []
        notice: []
        status: Healthy
        warning: []
      ioErrorCount: 0
      ioStallTransitionCount: 0
      ioStalled: false
    maxExpandableSize: 127.8 GiB
    pool_status: Online
    status: Online
    used: 21474836480
    used_q: 20 GiB
- apiVersion: openebs.io/v1beta3
  kind: DiskPool
  metadata:
    annotations:
      argocd.argoproj.io/sync-wave: "0"
      argocd.argoproj.io/tracking-id: storage-benchmark-rwx-mayastor:openebs.io/DiskPool:openebs/mayastor-rwx-bench-fordyce
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"openebs.io/v1beta3","kind":"DiskPool","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"0","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-mayastor:openebs.io/DiskPool:openebs/mayastor-rwx-bench-fordyce"},"name":"mayastor-rwx-bench-fordyce","namespace":"openebs"},"spec":{"disks":["aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench"],"maxExpansion":"1x","node":"fordyce"}}
    creationTimestamp: "2026-07-03T06:13:17Z"
    finalizers:
    - openebs.io/diskpool-protection
    generation: 1
    name: mayastor-rwx-bench-fordyce
    namespace: openebs
    resourceVersion: "150502316"
    uid: 96f898c7-b3b4-4928-9537-bc5b028765a4
  spec:
    disks:
    - aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench
    maxExpansion: 1x
    node: fordyce
  status:
    alertError: Healthy
    available: 10703863808
    available_q: 10 GiB
    capacity: 32178700288
    capacity_q: 30 GiB
    clusterSize: 4 MiB
    conditions:
    - lastTransitionTime: "2026-07-03T06:13:17Z"
      message: ""
      observedGeneration: 1
      reason: ""
      status: "True"
      type: PoolReady
    cr_state: Created
    diskCapacity: 30 GiB
    encrypted: false
    errorInfo:
      alerts:
        attention: []
        critical: []
        notice: []
        status: Healthy
        warning: []
      ioErrorCount: 0
      ioStallTransitionCount: 0
      ioStalled: false
    maxExpandableSize: 127.8 GiB
    pool_status: Online
    status: Online
    used: 21474836480
    used_q: 20 GiB
- apiVersion: openebs.io/v1beta3
  kind: DiskPool
  metadata:
    annotations:
      argocd.argoproj.io/sync-wave: "0"
      argocd.argoproj.io/tracking-id: storage-benchmark-rwx-mayastor:openebs.io/DiskPool:openebs/mayastor-rwx-bench-selassie
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"openebs.io/v1beta3","kind":"DiskPool","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"0","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-mayastor:openebs.io/DiskPool:openebs/mayastor-rwx-bench-selassie"},"name":"mayastor-rwx-bench-selassie","namespace":"openebs"},"spec":{"disks":["aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench"],"maxExpansion":"1x","node":"selassie"}}
    creationTimestamp: "2026-07-03T06:13:17Z"
    finalizers:
    - openebs.io/diskpool-protection
    generation: 1
    name: mayastor-rwx-bench-selassie
    namespace: openebs
    resourceVersion: "150502314"
    uid: 8a187c82-5025-4d91-b7a7-0e400d08fe8e
  spec:
    disks:
    - aio:///dev/disk/by-id/dm-name-vg--nvme-mayastor--bench
    maxExpansion: 1x
    node: selassie
  status:
    alertError: Healthy
    available: 10703863808
    available_q: 10 GiB
    capacity: 32178700288
    capacity_q: 30 GiB
    clusterSize: 4 MiB
    conditions:
    - lastTransitionTime: "2026-07-03T06:13:17Z"
      message: ""
      observedGeneration: 1
      reason: ""
      status: "True"
      type: PoolReady
    cr_state: Created
    diskCapacity: 30 GiB
    encrypted: false
    errorInfo:
      alerts:
        attention: []
        critical: []
        notice: []
        status: Healthy
        warning: []
      ioErrorCount: 0
      ioStallTransitionCount: 0
      ioStalled: false
    maxExpandableSize: 127.8 GiB
    pool_status: Online
    status: Online
    used: 21474836480
    used_q: 20 GiB
kind: List
metadata:
  resourceVersion: ""

## OpenEBS pods
NAME                                         READY   STATUS    RESTARTS   AGE     IP              NODE        NOMINATED NODE   READINESS GATES
openebs-agent-core-594c64dd9-s6dqk           2/2     Running   0          7d      10.42.0.15      dauwalter   <none>           <none>
openebs-agent-ha-node-5fhzc                  1/1     Running   0          7d      192.168.1.104   selassie    <none>           <none>
openebs-agent-ha-node-c5pjp                  1/1     Running   0          7d      192.168.1.102   fordyce     <none>           <none>
openebs-agent-ha-node-w2r5s                  1/1     Running   0          7d      192.168.1.100   dauwalter   <none>           <none>
openebs-api-rest-68f49d874-kvnfj             1/1     Running   0          7d      10.42.0.16      dauwalter   <none>           <none>
openebs-csi-controller-5cbb6cd9df-7jp2p      6/6     Running   0          7d      192.168.1.100   dauwalter   <none>           <none>
openebs-csi-node-86nkc                       2/2     Running   0          7d      192.168.1.104   selassie    <none>           <none>
openebs-csi-node-l695k                       2/2     Running   0          7d      192.168.1.102   fordyce     <none>           <none>
openebs-csi-node-wmcx4                       2/2     Running   0          7d      192.168.1.100   dauwalter   <none>           <none>
openebs-etcd-0                               0/1     Pending   0          4h20m   <none>          <none>      <none>           <none>
openebs-etcd-1                               1/1     Running   0          4h22m   10.42.4.155     walmsley    <none>           <none>
openebs-etcd-2                               1/1     Running   0          4h23m   10.42.1.58      kipsang     <none>           <none>
openebs-io-engine-8kz66                      2/2     Running   0          7d      192.168.1.102   fordyce     <none>           <none>
openebs-io-engine-r8c2z                      2/2     Running   0          7d      192.168.1.100   dauwalter   <none>           <none>
openebs-io-engine-zmdxd                      2/2     Running   0          7d      192.168.1.104   selassie    <none>           <none>
openebs-nats-0                               3/3     Running   0          7d      10.42.0.18      dauwalter   <none>           <none>
openebs-nats-1                               3/3     Running   0          7d      10.42.2.183     selassie    <none>           <none>
openebs-nats-2                               3/3     Running   0          7d      10.42.3.205     fordyce     <none>           <none>
openebs-operator-diskpool-6f7f4d9985-vm5jt   1/1     Running   0          7d      10.42.0.17      dauwalter   <none>           <none>

## CSI NFS pods
NAME                                  READY   STATUS    RESTARTS        AGE     IP              NODE        NOMINATED NODE   READINESS GATES
csi-nfs-controller-856999dbf7-d9jxb   5/5     Running   1 (4h22m ago)   4h23m   192.168.1.101   kipsang     <none>           <none>
csi-nfs-node-2tck8                    3/3     Running   0               4h23m   192.168.1.101   kipsang     <none>           <none>
csi-nfs-node-4n4vg                    3/3     Running   0               4h23m   192.168.1.102   fordyce     <none>           <none>
csi-nfs-node-5n26g                    3/3     Running   0               4h23m   192.168.1.104   selassie    <none>           <none>
csi-nfs-node-6kmg7                    3/3     Running   0               4h23m   192.168.1.100   dauwalter   <none>           <none>
csi-nfs-node-w8gbr                    3/3     Running   0               4h23m   192.168.1.103   walmsley    <none>           <none>

## Mayastor volume CRs (best effort)
error: the server doesn't have a resource type "volumes"
error: the server doesn't have a resource type "volumes"

## Mayastor replica CRs (best effort)
error: the server doesn't have a resource type "replicas"
error: the server doesn't have a resource type "replicas"

## OpenEBS recent events
LAST SEEN   TYPE      REASON             OBJECT               MESSAGE
3m28s       Warning   FailedScheduling   pod/openebs-etcd-0   0/5 nodes are available: 2 node(s) didn't match PersistentVolume's node affinity, 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/5 nodes are available: 5 Preemption is not helpful for scheduling.
