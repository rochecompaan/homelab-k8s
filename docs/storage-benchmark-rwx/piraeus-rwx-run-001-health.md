# Piraeus RWX run 001 health

Captured: 2026-07-02T19:44:51Z

## ArgoCD applications
NAME                            SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
root                            Synced        Healthy         9049633816a0fa01b43a1df5bbab37c08d397b9e   default
piraeus-operator                Synced        Healthy         2.10.7                                     default
storage-benchmark-rwx-piraeus   Synced        Healthy         9049633816a0fa01b43a1df5bbab37c08d397b9e   default

## Benchmark resources
NAME                                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS           VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/piraeus-rwx-pvc-run-001   Bound    pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930   20Gi       RWX            piraeus-rwx-bench-3r   <unset>                 47m   Filesystem

NAME                                  READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
pod/piraeus-rwx-fio-run-001-0-2m74c   0/1     Completed   0          47m   10.42.3.137   fordyce     <none>           <none>
pod/piraeus-rwx-fio-run-001-1-qdz62   0/1     Completed   0          47m   10.42.0.103   dauwalter   <none>           <none>
pod/piraeus-rwx-fio-run-001-2-qqcd6   0/1     Completed   0          47m   10.42.2.10    selassie    <none>           <none>
pod/piraeus-rwx-proof-a               1/1     Running     0          47m   10.42.3.136   fordyce     <none>           <none>
pod/piraeus-rwx-proof-b               1/1     Running     0          47m   10.42.2.11    selassie    <none>           <none>

NAME                                STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/piraeus-rwx-fio-run-001   Complete   3/3           45m        47m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=26e49a74-f626-4276-9fd5-73bd84ad0456

## PVC YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/tracking-id: storage-benchmark-rwx-piraeus:/PersistentVolumeClaim:storage-benchmark-rwx/piraeus-rwx-pvc-run-001
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"1","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-piraeus:/PersistentVolumeClaim:storage-benchmark-rwx/piraeus-rwx-pvc-run-001"},"labels":{"app.kubernetes.io/name":"storage-benchmark-rwx","storage.compaan.io/backend":"piraeus-rwx"},"name":"piraeus-rwx-pvc-run-001","namespace":"storage-benchmark-rwx"},"spec":{"accessModes":["ReadWriteMany"],"resources":{"requests":{"storage":"20Gi"}},"storageClassName":"piraeus-rwx-bench-3r"}}
    pv.kubernetes.io/bind-completed: "yes"
    pv.kubernetes.io/bound-by-controller: "yes"
    volume.beta.kubernetes.io/storage-provisioner: linstor.csi.linbit.com
    volume.kubernetes.io/selected-node: fordyce
    volume.kubernetes.io/storage-provisioner: linstor.csi.linbit.com
  creationTimestamp: "2026-07-02T18:58:09Z"
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    app.kubernetes.io/name: storage-benchmark-rwx
    storage.compaan.io/backend: piraeus-rwx
  name: piraeus-rwx-pvc-run-001
  namespace: storage-benchmark-rwx
  resourceVersion: "148372393"
  uid: 4103d321-aaab-4c25-86aa-2dae2ffa7930
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
  storageClassName: piraeus-rwx-bench-3r
  volumeMode: Filesystem
  volumeName: pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930
status:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 20Gi
  phase: Bound

## PV pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: linstor.csi.linbit.com
    volume.kubernetes.io/provisioner-deletion-secret-name: ""
    volume.kubernetes.io/provisioner-deletion-secret-namespace: ""
  creationTimestamp: "2026-07-02T18:59:02Z"
  finalizers:
  - external-provisioner.volume.kubernetes.io/finalizer
  - kubernetes.io/pv-protection
  - external-attacher/linstor-csi-linbit-com
  name: pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930
  resourceVersion: "148372405"
  uid: 21f314e5-c2fc-412a-926e-22eef9e50273
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 20Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: piraeus-rwx-pvc-run-001
    namespace: storage-benchmark-rwx
    resourceVersion: "148372179"
    uid: 4103d321-aaab-4c25-86aa-2dae2ffa7930
  csi:
    driver: linstor.csi.linbit.com
    fsType: ext4
    volumeAttributes:
      linstor.csi.linbit.com/mount-options: ""
      linstor.csi.linbit.com/nfs-export: nfs://linstor-csi-nfs.piraeus-datastore.svc:1000/pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930
      linstor.csi.linbit.com/post-mount-xfs-opts: ""
      linstor.csi.linbit.com/remote-access-policy: "true"
      linstor.csi.linbit.com/uses-volume-context: "true"
      storage.kubernetes.io/csiProvisionerIdentity: 1783018720137-8741-linstor.csi.linbit.com
    volumeHandle: pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930
  persistentVolumeReclaimPolicy: Delete
  storageClassName: piraeus-rwx-bench-3r
  volumeMode: Filesystem
status:
  lastPhaseTransitionTime: "2026-07-02T18:59:02Z"
  phase: Bound

## StorageClass piraeus-rwx-bench-3r
allowVolumeExpansion: false
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    argocd.argoproj.io/tracking-id: storage-benchmark-rwx-piraeus:storage.k8s.io/StorageClass:piraeus-datastore/piraeus-rwx-bench-3r
    kubectl.kubernetes.io/last-applied-configuration: |
      {"allowVolumeExpansion":false,"apiVersion":"storage.k8s.io/v1","kind":"StorageClass","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"0","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-piraeus:storage.k8s.io/StorageClass:piraeus-datastore/piraeus-rwx-bench-3r"},"labels":{"storage.compaan.io/backend":"piraeus-rwx","storage.compaan.io/benchmark":"true"},"name":"piraeus-rwx-bench-3r"},"parameters":{"linstor.csi.linbit.com/placementCount":"3","linstor.csi.linbit.com/storagePool":"linstor-bench"},"provisioner":"linstor.csi.linbit.com","reclaimPolicy":"Delete","volumeBindingMode":"WaitForFirstConsumer"}
  creationTimestamp: "2026-07-02T18:58:07Z"
  labels:
    storage.compaan.io/backend: piraeus-rwx
    storage.compaan.io/benchmark: "true"
  name: piraeus-rwx-bench-3r
  resourceVersion: "148371221"
  uid: cf47987e-b4e6-4600-843b-81dfb6750ec7
parameters:
  linstor.csi.linbit.com/placementCount: "3"
  linstor.csi.linbit.com/storagePool: linstor-bench
provisioner: linstor.csi.linbit.com
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer

## LinstorCluster summary
NAME             AVAILABLE   CONFIGURED   VERSION   SATELLITES   USED CAPACITY   VOLUMES   SNAPSHOTS   AGE
linstorcluster   True        True         1.33.3    3/3          38/97GiB        1         0           47m

## LinstorCluster YAML
apiVersion: piraeus.io/v1
kind: LinstorCluster
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    argocd.argoproj.io/tracking-id: storage-benchmark-rwx-piraeus:piraeus.io/LinstorCluster:piraeus-datastore/linstorcluster
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"piraeus.io/v1","kind":"LinstorCluster","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"0","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-piraeus:piraeus.io/LinstorCluster:piraeus-datastore/linstorcluster"},"name":"linstorcluster"},"spec":{"nodeSelector":{"storage.compaan.io/linstor-benchmark":"true"}}}
  creationTimestamp: "2026-07-02T18:58:07Z"
  generation: 1
  name: linstorcluster
  resourceVersion: "148402922"
  uid: 2563ec8e-7426-485d-875d-456e5ec82051
spec:
  nodeSelector:
    storage.compaan.io/linstor-benchmark: "true"
status:
  availableCapacityBytes: 96636764160
  capacity: 38/97GiB
  conditions:
  - lastTransitionTime: "2026-07-02T18:58:10Z"
    message: Resources applied
    observedGeneration: 1
    reason: AsExpected
    status: "True"
    type: Applied
  - lastTransitionTime: "2026-07-02T18:58:39Z"
    message: 'Controller 1.33.3 (API: 1.27.0, Git: 1ff3a1ea5cb5c77100265ec442bb9a492b225145)
      reachable at ''http://linstor-controller.piraeus-datastore.svc:3370'''
    observedGeneration: 1
    reason: AsExpected
    status: "True"
    type: Available
  - lastTransitionTime: "2026-07-02T18:59:01Z"
    message: Properties applied
    observedGeneration: 1
    reason: AsExpected
    status: "True"
    type: Configured
  freeCapacityBytes: 59309202432
  numberOfSnapshots: 0
  numberOfVolumes: 1
  runningSatellites: 3
  satellites: 3/3
  scheduledSatellites: 3
  version: 1.33.3

## LinstorSatelliteConfiguration linstor-bench-storage
apiVersion: piraeus.io/v1
kind: LinstorSatelliteConfiguration
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    argocd.argoproj.io/tracking-id: storage-benchmark-rwx-piraeus:piraeus.io/LinstorSatelliteConfiguration:piraeus-datastore/linstor-bench-storage
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"piraeus.io/v1","kind":"LinstorSatelliteConfiguration","metadata":{"annotations":{"argocd.argoproj.io/sync-wave":"0","argocd.argoproj.io/tracking-id":"storage-benchmark-rwx-piraeus:piraeus.io/LinstorSatelliteConfiguration:piraeus-datastore/linstor-bench-storage"},"name":"linstor-bench-storage"},"spec":{"nodeSelector":{"storage.compaan.io/linstor-benchmark":"true"},"podTemplate":{"spec":{"volumes":[{"hostPath":{"path":"/usr/src","type":"DirectoryOrCreate"},"name":"usr-src"}]}},"storagePools":[{"lvmThinPool":{"thinPool":"linstor-bench-thin","volumeGroup":"vg-nvme"},"name":"linstor-bench"}]}}
  creationTimestamp: "2026-07-02T18:58:07Z"
  generation: 1
  name: linstor-bench-storage
  resourceVersion: "148371466"
  uid: 1710a915-41aa-49f3-b8c6-ee436cd23f4a
spec:
  nodeSelector:
    storage.compaan.io/linstor-benchmark: "true"
  podTemplate:
    spec:
      volumes:
      - hostPath:
          path: /usr/src
          type: DirectoryOrCreate
        name: usr-src
  storagePools:
  - lvmThinPool:
      thinPool: linstor-bench-thin
      volumeGroup: vg-nvme
    name: linstor-bench
status:
  appliedTo:
  - dauwalter
  - fordyce
  - selassie
  conditions:
  - lastTransitionTime: "2026-07-02T18:58:10Z"
    message: ""
    observedGeneration: 1
    reason: AsExpected
    status: "True"
    type: Applied
  matched: 3

## Linstor satellites
NAME        CONNECTED   CONFIGURED   APPLIED CONFIGURATIONS   DELETION POLICY   USED CAPACITY   VOLUMES   SNAPSHOTS   STORAGE PROVIDERS                                                                        DEVICE LAYERS               AGE
dauwalter   True        True         linstor-bench-storage    Retain            13/33GiB        1         0           ["DISKLESS","EBS_INIT","EBS_TARGET","FILE","FILE_THIN","LVM","LVM_THIN","REMOTE_SPDK"]   ["DRBD","LUKS","STORAGE"]   47m
fordyce     True        True         linstor-bench-storage    Retain            13/33GiB        1         0           ["DISKLESS","EBS_INIT","EBS_TARGET","FILE","FILE_THIN","LVM","LVM_THIN","REMOTE_SPDK"]   ["DRBD","LUKS","STORAGE"]   47m
selassie    True        True         linstor-bench-storage    Retain            13/33GiB        1         0           ["DISKLESS","EBS_INIT","EBS_TARGET","FILE","FILE_THIN","LVM","LVM_THIN","REMOTE_SPDK"]   ["DRBD","LUKS","STORAGE"]   47m

## Piraeus pods
NAME                                                  READY   STATUS    RESTARTS   AGE   IP              NODE        NOMINATED NODE   READINESS GATES
ha-controller-2zqmd                                   1/1     Running   0          47m   10.42.0.100     dauwalter   <none>           <none>
ha-controller-6xsg4                                   1/1     Running   0          47m   10.42.2.7       selassie    <none>           <none>
ha-controller-8j9v9                                   1/1     Running   0          47m   10.42.3.132     fordyce     <none>           <none>
linstor-affinity-controller-65d75455c9-v22fw          1/1     Running   0          47m   10.42.3.133     fordyce     <none>           <none>
linstor-controller-654969cdb4-fb9zt                   1/1     Running   0          47m   10.42.0.98      dauwalter   <none>           <none>
linstor-csi-controller-5975dff45d-crsdx               7/7     Running   0          47m   10.42.0.99      dauwalter   <none>           <none>
linstor-csi-nfs-server-dp4ws                          1/1     Running   0          47m   10.42.0.101     dauwalter   <none>           <none>
linstor-csi-nfs-server-pj7sg                          1/1     Running   0          47m   10.42.2.8       selassie    <none>           <none>
linstor-csi-nfs-server-w4b4k                          1/1     Running   0          47m   10.42.3.134     fordyce     <none>           <none>
linstor-csi-node-4nm7m                                3/3     Running   0          47m   192.168.1.102   fordyce     <none>           <none>
linstor-csi-node-g55q7                                3/3     Running   0          47m   192.168.1.100   dauwalter   <none>           <none>
linstor-csi-node-gxtnr                                3/3     Running   0          47m   192.168.1.104   selassie    <none>           <none>
linstor-satellite.dauwalter-4c8xn                     2/2     Running   0          47m   10.42.0.102     dauwalter   <none>           <none>
linstor-satellite.fordyce-whgmf                       2/2     Running   0          47m   10.42.3.135     fordyce     <none>           <none>
linstor-satellite.selassie-5zppj                      2/2     Running   0          47m   10.42.2.9       selassie    <none>           <none>
piraeus-operator-controller-manager-bbbb9dbb9-mhnwm   1/1     Running   0          48m   10.42.0.97      dauwalter   <none>           <none>

## LINSTOR nodes
+-----------------------------------------------------------+
| Node      | NodeType  | Addresses                | State  |
|===========================================================|
| dauwalter | SATELLITE | 10.42.0.102:3366 (PLAIN) | [1;32mOnline[0m |
| fordyce   | SATELLITE | 10.42.3.135:3366 (PLAIN) | [1;32mOnline[0m |
| selassie  | SATELLITE | 10.42.2.9:3366 (PLAIN)   | [1;32mOnline[0m |
+-----------------------------------------------------------+

## LINSTOR storage pools
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
| StoragePool          | Node      | Driver   | PoolName                   | FreeCapacity | TotalCapacity | CanSnapshots | State | SharedName                     |
|=================================================================================================================================================================|
| DfltDisklessStorPool | dauwalter | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | dauwalter;DfltDisklessStorPool |
| DfltDisklessStorPool | fordyce   | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | fordyce;DfltDisklessStorPool   |
| DfltDisklessStorPool | selassie  | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | selassie;DfltDisklessStorPool  |
| linstor-bench        | dauwalter | LVM_THIN | vg-nvme/linstor-bench-thin |    18.41 GiB |        30 GiB | True         | [1;32mOk   [0m | dauwalter;linstor-bench        |
| linstor-bench        | fordyce   | LVM_THIN | vg-nvme/linstor-bench-thin |    18.41 GiB |        30 GiB | True         | [1;32mOk   [0m | fordyce;linstor-bench          |
| linstor-bench        | selassie  | LVM_THIN | vg-nvme/linstor-bench-thin |    18.41 GiB |        30 GiB | True         | [1;32mOk   [0m | selassie;linstor-bench         |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+

## LINSTOR resource definitions
+-----------------------------------------------------------------------------------------------------------+
| ResourceName                             | ResourceGroup                           | Layers       | State |
|===========================================================================================================|
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | sc-f9df07a3-72f3-578a-9c93-d7931a50d92d | DRBD,STORAGE | [0;32mok   [0m |
+-----------------------------------------------------------------------------------------------------------+

## LINSTOR resources
+--------------------------------------------------------------------------------------------------------+
| ResourceName                             | Node      | Layers       | Usage  | Conns |    State | Vote |
|========================================================================================================|
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | dauwalter | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | fordyce   | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | selassie  | DRBD,STORAGE | [1;32mInUse [0m | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
+--------------------------------------------------------------------------------------------------------+

## LINSTOR volumes
+---------------------------------------------------------------------------------------------------------------------------------------------------------+
| Resource                                 | Node      | StoragePool   | VolNr | MinorNr | DeviceName    | Allocated | InUse  |    State | Repl           |
|=========================================================================================================================================================|
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | dauwalter | linstor-bench |     0 |    1000 | /dev/drbd1000 | 11.57 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | dauwalter | linstor-bench |     1 |    1001 | /dev/drbd1001 | 20.19 MiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | fordyce   | linstor-bench |     0 |    1000 | /dev/drbd1000 | 11.57 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | fordyce   | linstor-bench |     1 |    1001 | /dev/drbd1001 | 28.18 MiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | selassie  | linstor-bench |     0 |    1000 | /dev/drbd1000 | 11.57 GiB | [1;32mInUse [0m | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-4103d321-aaab-4c25-86aa-2dae2ffa7930 | selassie  | linstor-bench |     1 |    1001 | /dev/drbd1001 | 20.19 MiB | [1;32mInUse [0m | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
+---------------------------------------------------------------------------------------------------------------------------------------------------------+

## LINSTOR error reports
+----------------------------------+
| Id | Datetime | Node | Exception |
|==================================|
+----------------------------------+
