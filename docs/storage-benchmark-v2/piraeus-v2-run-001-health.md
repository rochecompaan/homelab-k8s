# Piraeus benchmark v2 health

## ArgoCD applications
NAME                           SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
piraeus-operator               Synced        Healthy         2.10.7                                     default
storage-benchmark-v2-piraeus   Synced        Healthy         9336922b79f900caee80477342940e1cc207e496   default

## LINSTOR cluster CRs
NAME                                       AVAILABLE   CONFIGURED   VERSION   SATELLITES   USED CAPACITY   VOLUMES   SNAPSHOTS   AGE
linstorcluster.piraeus.io/linstorcluster   True        True         1.33.3    3/3          34/97GiB        1         0           39m

NAME                                    CONNECTED   CONFIGURED   APPLIED CONFIGURATIONS   DELETION POLICY   USED CAPACITY   VOLUMES   SNAPSHOTS   STORAGE PROVIDERS                                                                        DEVICE LAYERS               AGE
linstorsatellite.piraeus.io/dauwalter   True        True         linstor-bench-storage    Retain            12/33GiB        1         0           ["DISKLESS","EBS_INIT","EBS_TARGET","FILE","FILE_THIN","LVM","LVM_THIN","REMOTE_SPDK"]   ["DRBD","LUKS","STORAGE"]   39m
linstorsatellite.piraeus.io/fordyce     True        True         linstor-bench-storage    Retain            12/33GiB        1         0           ["DISKLESS","EBS_INIT","EBS_TARGET","FILE","FILE_THIN","LVM","LVM_THIN","REMOTE_SPDK"]   ["DRBD","LUKS","STORAGE"]   39m
linstorsatellite.piraeus.io/selassie    True        True         linstor-bench-storage    Retain            12/33GiB        1         0           ["DISKLESS","EBS_INIT","EBS_TARGET","FILE","FILE_THIN","LVM","LVM_THIN","REMOTE_SPDK"]   ["DRBD","LUKS","STORAGE"]   39m

## LINSTOR nodes
+-----------------------------------------------------------+
| Node      | NodeType  | Addresses                | State  |
|===========================================================|
| dauwalter | SATELLITE | 10.42.0.27:3366 (PLAIN)  | [1;32mOnline[0m |
| fordyce   | SATELLITE | 10.42.3.210:3366 (PLAIN) | [1;32mOnline[0m |
| selassie  | SATELLITE | 10.42.2.186:3366 (PLAIN) | [1;32mOnline[0m |
+-----------------------------------------------------------+

## LINSTOR storage pools
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
| StoragePool          | Node      | Driver   | PoolName                   | FreeCapacity | TotalCapacity | CanSnapshots | State | SharedName                     |
|=================================================================================================================================================================|
| DfltDisklessStorPool | dauwalter | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | dauwalter;DfltDisklessStorPool |
| DfltDisklessStorPool | fordyce   | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | fordyce;DfltDisklessStorPool   |
| DfltDisklessStorPool | selassie  | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | selassie;DfltDisklessStorPool  |
| linstor-bench        | dauwalter | LVM_THIN | vg-nvme/linstor-bench-thin |    19.30 GiB |        30 GiB | True         | [1;32mOk   [0m | dauwalter;linstor-bench        |
| linstor-bench        | fordyce   | LVM_THIN | vg-nvme/linstor-bench-thin |    19.30 GiB |        30 GiB | True         | [1;32mOk   [0m | fordyce;linstor-bench          |
| linstor-bench        | selassie  | LVM_THIN | vg-nvme/linstor-bench-thin |    19.30 GiB |        30 GiB | True         | [1;32mOk   [0m | selassie;linstor-bench         |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+

## LINSTOR resource volumes
+---------------------------------------------------------------------------------------------------------------------------------------------------------+
| Resource                                 | Node      | StoragePool   | VolNr | MinorNr | DeviceName    | Allocated | InUse  |    State | Repl           |
|=========================================================================================================================================================|
| pvc-74f83e5a-3dc6-433f-9f3a-157ea1089a13 | dauwalter | linstor-bench |     0 |    1000 | /dev/drbd1000 | 10.70 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-74f83e5a-3dc6-433f-9f3a-157ea1089a13 | fordyce   | linstor-bench |     0 |    1000 | /dev/drbd1000 | 10.70 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-74f83e5a-3dc6-433f-9f3a-157ea1089a13 | selassie  | linstor-bench |     0 |    1000 | /dev/drbd1000 | 10.70 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
+---------------------------------------------------------------------------------------------------------------------------------------------------------+

## Benchmark resources
NAME                                               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/piraeus-fio-pvc-v2-run-001   Bound    pvc-74f83e5a-3dc6-433f-9f3a-157ea1089a13   20Gi       RWO            piraeus-bench-v2-3r   <unset>                 39m   Filesystem

NAME                                         READY   STATUS      RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES
pod/storage-bench-piraeus-v2-run-001-fjktq   0/1     Completed   0          39m   10.42.3.211   fordyce   <none>           <none>

NAME                                         STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/storage-bench-piraeus-v2-run-001   Complete   1/1           38m        39m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=22ad33ea-557b-4473-8f4b-d146b65610e5

## Problem pods
