# Piraeus post-benchmark health

Captured: 2026-06-24T08:02:28Z

## ArgoCD applications
NAME                SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
piraeus-operator    Synced        Healthy         2.10.7                                     default
piraeus-benchmark   Synced        Healthy         c3d9389b9f2857b6af14c0ba1a999246935273b1   default

## Piraeus pods
NAME                                                  READY   STATUS    RESTARTS      AGE   IP              NODE        NOMINATED NODE   READINESS GATES
ha-controller-dql74                                   1/1     Running   2 (23h ago)   42h   10.42.2.40      selassie    <none>           <none>
ha-controller-ltnj7                                   1/1     Running   1 (40h ago)   42h   10.42.3.48      fordyce     <none>           <none>
ha-controller-tgx5p                                   1/1     Running   1 (40h ago)   42h   10.42.0.82      dauwalter   <none>           <none>
linstor-affinity-controller-65d75455c9-tcs4w          1/1     Running   0             40h   10.42.0.97      dauwalter   <none>           <none>
linstor-controller-654969cdb4-2dd4c                   1/1     Running   0             40h   10.42.0.102     dauwalter   <none>           <none>
linstor-csi-controller-5975dff45d-px2fl               7/7     Running   0             40h   10.42.0.103     dauwalter   <none>           <none>
linstor-csi-nfs-server-4pqqp                          1/1     Running   0             42h   10.42.0.84      dauwalter   <none>           <none>
linstor-csi-nfs-server-t4dxp                          1/1     Running   0             42h   10.42.2.42      selassie    <none>           <none>
linstor-csi-nfs-server-v6rxf                          1/1     Running   0             42h   10.42.3.55      fordyce     <none>           <none>
linstor-csi-node-4spdj                                3/3     Running   0             42h   192.168.1.102   fordyce     <none>           <none>
linstor-csi-node-fc6v4                                3/3     Running   0             42h   192.168.1.100   dauwalter   <none>           <none>
linstor-csi-node-gzlkx                                3/3     Running   0             42h   192.168.1.104   selassie    <none>           <none>
linstor-satellite.dauwalter-2p47m                     2/2     Running   0             41h   10.42.0.83      dauwalter   <none>           <none>
linstor-satellite.fordyce-mrfnh                       2/2     Running   0             41h   10.42.3.50      fordyce     <none>           <none>
linstor-satellite.selassie-qpmwf                      2/2     Running   0             41h   10.42.2.41      selassie    <none>           <none>
piraeus-operator-controller-manager-bbbb9dbb9-k44zk   1/1     Running   0             41h   10.42.4.129     walmsley    <none>           <none>

## LINSTOR cluster CRs
NAME                                       AVAILABLE   CONFIGURED   VERSION   SATELLITES   USED CAPACITY   VOLUMES   SNAPSHOTS   AGE
linstorcluster.piraeus.io/linstorcluster   True        True         1.33.3    3/3          14/97GiB        1         0           42h

NAME                                                             SELECTOR                                          APPLIED   MATCHED   SATELLITES                           AGE
linstorsatelliteconfiguration.piraeus.io/linstor-bench-storage   {"storage.compaan.io/linstor-benchmark":"true"}   True      3         ["dauwalter","fordyce","selassie"]   42h

NAME                                    CONNECTED   CONFIGURED   APPLIED CONFIGURATIONS   DELETION POLICY   USED CAPACITY   VOLUMES   SNAPSHOTS   STORAGE PROVIDERS                                                                        DEVICE LAYERS               AGE
linstorsatellite.piraeus.io/dauwalter   True        True         linstor-bench-storage    Retain            5/33GiB         1         0           ["DISKLESS","EBS_INIT","EBS_TARGET","FILE","FILE_THIN","LVM","LVM_THIN","REMOTE_SPDK"]   ["DRBD","LUKS","STORAGE"]   42h
linstorsatellite.piraeus.io/fordyce     True        True         linstor-bench-storage    Retain            5/33GiB         1         0           ["DISKLESS","EBS_INIT","EBS_TARGET","FILE","FILE_THIN","LVM","LVM_THIN","REMOTE_SPDK"]   ["DRBD","LUKS","STORAGE"]   42h
linstorsatellite.piraeus.io/selassie    True        True         linstor-bench-storage    Retain            5/33GiB         1         0           ["DISKLESS","EBS_INIT","EBS_TARGET","FILE","FILE_THIN","LVM","LVM_THIN","REMOTE_SPDK"]   ["DRBD","LUKS","STORAGE"]   42h

## LINSTOR nodes
+----------------------------------------------------------+
| Node      | NodeType  | Addresses               | State  |
|==========================================================|
| dauwalter | SATELLITE | 10.42.0.83:3366 (PLAIN) | Online |
| fordyce   | SATELLITE | 10.42.3.50:3366 (PLAIN) | Online |
| selassie  | SATELLITE | 10.42.2.41:3366 (PLAIN) | Online |
+----------------------------------------------------------+

## LINSTOR storage pools
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
| StoragePool          | Node      | Driver   | PoolName                   | FreeCapacity | TotalCapacity | CanSnapshots | State | SharedName                     |
|=================================================================================================================================================================|
| DfltDisklessStorPool | dauwalter | DISKLESS |                            |              |               | False        | Ok    | dauwalter;DfltDisklessStorPool |
| DfltDisklessStorPool | fordyce   | DISKLESS |                            |              |               | False        | Ok    | fordyce;DfltDisklessStorPool   |
| DfltDisklessStorPool | selassie  | DISKLESS |                            |              |               | False        | Ok    | selassie;DfltDisklessStorPool  |
| linstor-bench        | dauwalter | LVM_THIN | vg-nvme/linstor-bench-thin |    25.80 GiB |        30 GiB | True         | Ok    | dauwalter;linstor-bench        |
| linstor-bench        | fordyce   | LVM_THIN | vg-nvme/linstor-bench-thin |    25.77 GiB |        30 GiB | True         | Ok    | fordyce;linstor-bench          |
| linstor-bench        | selassie  | LVM_THIN | vg-nvme/linstor-bench-thin |    25.80 GiB |        30 GiB | True         | Ok    | selassie;linstor-bench         |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+

## LINSTOR resource volumes
+---------------------------------------------------------------------------------------------------------------------------------------------------------+
| Resource                                 | Node      | StoragePool   | VolNr | MinorNr | DeviceName    | Allocated | InUse  |    State | Repl           |
|=========================================================================================================================================================|
| pvc-fac962ee-369f-46d4-a67a-645feed28492 | dauwalter | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(2) |
| pvc-fac962ee-369f-46d4-a67a-645feed28492 | fordyce   | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.23 GiB | Unused | UpToDate | Established(2) |
| pvc-fac962ee-369f-46d4-a67a-645feed28492 | selassie  | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(2) |
+---------------------------------------------------------------------------------------------------------------------------------------------------------+

## Storage benchmark resources
NAME                                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS       VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/piraeus-fio-pvc-run-002   Bound    pvc-fac962ee-369f-46d4-a67a-645feed28492   10Gi       RWO            piraeus-bench-3r   <unset>                 23m   Filesystem

NAME                                      READY   STATUS      RESTARTS   AGE   IP           NODE      NOMINATED NODE   READINESS GATES
pod/storage-bench-piraeus-run-002-svpn6   0/1     Completed   0          23m   10.42.3.63   fordyce   <none>           <none>

NAME                                      STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/storage-bench-piraeus-run-002   Complete   1/1           22m        23m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=b49e9eeb-f31e-45ad-9393-edfe67eb3b63

## Piraeus benchmark PVs
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                                                                                                     STORAGECLASS       VOLUMEATTRIBUTESCLASS   REASON   AGE    VOLUMEMODE
pvc-fac962ee-369f-46d4-a67a-645feed28492   10Gi       RWO            Delete           Bound      storage-benchmark/piraeus-fio-pvc-run-002                                                                 piraeus-bench-3r   <unset>                          23m    Filesystem

## Problem pods
none
