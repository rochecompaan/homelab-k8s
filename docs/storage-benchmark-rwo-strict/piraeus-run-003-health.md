# Piraeus strict RWO run 003 health

## Writer pod placement
NAME                                              READY   STATUS      RESTARTS   AGE    IP            NODE      NOMINATED NODE   READINESS GATES
piraeus-rwo-strict-writer-fordyce-run-003-j6jfl   0/1     Completed   0          6m3s   10.42.3.133   fordyce   <none>           <none>

## PVC and PV identity
NAME                             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS            VOLUMEATTRIBUTESCLASS   AGE    VOLUMEMODE
piraeus-rwo-strict-pvc-run-003   Bound    pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08   20Gi       RWO            piraeus-rwo-strict-3r   <unset>                 6m3s   Filesystem
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                         STORAGECLASS            VOLUMEATTRIBUTESCLASS   REASON   AGE   VOLUMEMODE
pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08   20Gi       RWO            Delete           Bound    storage-benchmark-rwo-strict/piraeus-rwo-strict-pvc-run-003   piraeus-rwo-strict-3r   <unset>                          6m    Filesystem

## LINSTOR resources after writer
+--------------------------------------------------------------------------------------------------------+
| ResourceName                             | Node      | Layers       | Usage  | Conns |    State | Vote |
|========================================================================================================|
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | dauwalter | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | fordyce   | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | selassie  | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
+--------------------------------------------------------------------------------------------------------+

## LINSTOR volumes after writer
+---------------------------------------------------------------------------------------------------------------------------------------------------------+
| Resource                                 | Node      | StoragePool   | VolNr | MinorNr | DeviceName    | Allocated | InUse  |    State | Repl           |
|=========================================================================================================================================================|
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | dauwalter | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.32 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | fordyce   | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.45 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | selassie  | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.32 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
+---------------------------------------------------------------------------------------------------------------------------------------------------------+

## LINSTOR storage pools after writer
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
| StoragePool          | Node      | Driver   | PoolName                   | FreeCapacity | TotalCapacity | CanSnapshots | State | SharedName                     |
|=================================================================================================================================================================|
| DfltDisklessStorPool | dauwalter | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | dauwalter;DfltDisklessStorPool |
| DfltDisklessStorPool | fordyce   | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | fordyce;DfltDisklessStorPool   |
| DfltDisklessStorPool | selassie  | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | selassie;DfltDisklessStorPool  |
| linstor-bench        | dauwalter | LVM_THIN | vg-nvme/linstor-bench-thin |    13.68 GiB |        30 GiB | True         | [1;32mOk   [0m | dauwalter;linstor-bench        |
| linstor-bench        | fordyce   | LVM_THIN | vg-nvme/linstor-bench-thin |    13.55 GiB |        30 GiB | True         | [1;32mOk   [0m | fordyce;linstor-bench          |
| linstor-bench        | selassie  | LVM_THIN | vg-nvme/linstor-bench-thin |    13.68 GiB |        30 GiB | True         | [1;32mOk   [0m | selassie;linstor-bench         |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+

## Reader pod placement: dauwalter
NAME                                                READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
piraeus-rwo-strict-reader-dauwalter-run-003-59cg8   0/1     Completed   0          12m   10.42.0.178   dauwalter   <none>           <none>

## LINSTOR resources after dauwalter reader
+--------------------------------------------------------------------------------------------------------+
| ResourceName                             | Node      | Layers       | Usage  | Conns |    State | Vote |
|========================================================================================================|
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | dauwalter | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | fordyce   | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | selassie  | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
+--------------------------------------------------------------------------------------------------------+

## LINSTOR volumes after dauwalter reader
+---------------------------------------------------------------------------------------------------------------------------------------------------------+
| Resource                                 | Node      | StoragePool   | VolNr | MinorNr | DeviceName    | Allocated | InUse  |    State | Repl           |
|=========================================================================================================================================================|
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | dauwalter | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.32 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | fordyce   | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.45 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | selassie  | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.32 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
+---------------------------------------------------------------------------------------------------------------------------------------------------------+

## Reader pod placement: selassie
NAME                                               READY   STATUS      RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
piraeus-rwo-strict-reader-selassie-run-003-q8kbd   0/1     Completed   0          12m   10.42.2.176   selassie   <none>           <none>

## All Piraeus run 003 benchmark Jobs and Pods
NAME                                                    STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/piraeus-rwo-strict-reader-dauwalter-run-003   Complete   1/1           12m        30m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=2dd9bfc5-3e41-453c-8b86-a7d7addcb99c
job.batch/piraeus-rwo-strict-reader-selassie-run-003    Complete   1/1           11m        12m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=a321dfc1-e0d8-47c4-82ab-d440df660af7
job.batch/piraeus-rwo-strict-writer-fordyce-run-003     Complete   1/1           5m16s      42m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=da1bab93-ffb3-45ee-abe3-2f39ee4839a7

NAME                                                    READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
pod/piraeus-rwo-strict-reader-dauwalter-run-003-59cg8   0/1     Completed   0          30m   10.42.0.178   dauwalter   <none>           <none>
pod/piraeus-rwo-strict-reader-selassie-run-003-q8kbd    0/1     Completed   0          12m   10.42.2.176   selassie    <none>           <none>
pod/piraeus-rwo-strict-writer-fordyce-run-003-j6jfl     0/1     Completed   0          42m   10.42.3.133   fordyce     <none>           <none>

## LINSTOR resources after readers
+--------------------------------------------------------------------------------------------------------+
| ResourceName                             | Node      | Layers       | Usage  | Conns |    State | Vote |
|========================================================================================================|
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | dauwalter | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | fordyce   | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | selassie  | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32mUpToDate[0m | Yes  |
+--------------------------------------------------------------------------------------------------------+

## LINSTOR volumes after readers
+---------------------------------------------------------------------------------------------------------------------------------------------------------+
| Resource                                 | Node      | StoragePool   | VolNr | MinorNr | DeviceName    | Allocated | InUse  |    State | Repl           |
|=========================================================================================================================================================|
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | dauwalter | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.33 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | fordyce   | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.45 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-ac332ab9-3c20-4c2b-9513-e14ca1a40a08 | selassie  | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.33 GiB | Unused | [0;32mUpToDate[0m | [1;32mEstablished(2)[0m |
+---------------------------------------------------------------------------------------------------------------------------------------------------------+

## LINSTOR storage pools after readers
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
| StoragePool          | Node      | Driver   | PoolName                   | FreeCapacity | TotalCapacity | CanSnapshots | State | SharedName                     |
|=================================================================================================================================================================|
| DfltDisklessStorPool | dauwalter | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | dauwalter;DfltDisklessStorPool |
| DfltDisklessStorPool | fordyce   | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | fordyce;DfltDisklessStorPool   |
| DfltDisklessStorPool | selassie  | DISKLESS |                            |              |               | False        | [1;32mOk   [0m | selassie;DfltDisklessStorPool  |
| linstor-bench        | dauwalter | LVM_THIN | vg-nvme/linstor-bench-thin |    13.67 GiB |        30 GiB | True         | [1;32mOk   [0m | dauwalter;linstor-bench        |
| linstor-bench        | fordyce   | LVM_THIN | vg-nvme/linstor-bench-thin |    13.55 GiB |        30 GiB | True         | [1;32mOk   [0m | fordyce;linstor-bench          |
| linstor-bench        | selassie  | LVM_THIN | vg-nvme/linstor-bench-thin |    13.67 GiB |        30 GiB | True         | [1;32mOk   [0m | selassie;linstor-bench         |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
