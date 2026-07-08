# Piraeus strict RWO run 001 health

## Writer pod placement
NAME                                              READY   STATUS      RESTARTS   AGE     IP            NODE      NOMINATED NODE   READINESS GATES
piraeus-rwo-strict-writer-fordyce-run-001-pz2xh   0/1     Completed   0          3m45s   10.42.3.163   fordyce   <none>           <none>

## PVC and PV identity
NAME                             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS            VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
piraeus-rwo-strict-pvc-run-001   Bound    pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26   20Gi       RWO            piraeus-rwo-strict-3r   <unset>                 38m   Filesystem
pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26   20Gi       RWO            Delete           Bound      storage-benchmark-rwo-strict/piraeus-rwo-strict-pvc-run-001                                               piraeus-rwo-strict-3r         <unset>                          16m     Filesystem

## LINSTOR resources after writer
+----------------------------------------------------------------------------------------------------------------------+
| ResourceName                             | Node      | Layers       | Usage  | Conns |                  State | Vote |
|======================================================================================================================|
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | dauwalter | DRBD,STORAGE | Unused | [0;32mOk   [0m | [1;31mDiskless, SkipDisk (R)[0m | Yes  |
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | fordyce   | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32m              UpToDate[0m | Yes  |
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | selassie  | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32m              UpToDate[0m | Yes  |
+----------------------------------------------------------------------------------------------------------------------+
[1;33mSkipDisk[0m:
  At least one resource has 'DrbdOptions/SkipDisk' enabled. This indicates an IO error on the
  affected resource(s). Remove this property (using 'linstor resource set-property $node $rsc DrbdOptions/SkipDisk') 
  to instruct LINSTOR and DRBD to adjust (and recreate if necessary) the affected logical volumes again.
  For more information please visit: https://linbit.com/drbd-user-guide/linstor-guide-1_0-en/#s-linstor-drbd-skip-disk

## LINSTOR volumes after writer
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Resource                                 | Node      | StoragePool   | VolNr | MinorNr | DeviceName    | Allocated | InUse  |                  State | Repl           |
|=======================================================================================================================================================================|
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | dauwalter | linstor-bench |     0 |    1000 | /dev/drbd1000 |  3.75 GiB | Unused | [1;31mDiskless, SkipDisk (R)[0m | [1;32mEstablished(2)[0m |
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | fordyce   | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.45 GiB | Unused | [0;32m              UpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | selassie  | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.32 GiB | Unused | [0;32m              UpToDate[0m | [1;32mEstablished(2)[0m |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------+
[1;33mSkipDisk[0m:
  At least one resource has 'DrbdOptions/SkipDisk' enabled. This indicates an IO error on the
  affected resource(s). Remove this property (using 'linstor resource set-property $node $rsc DrbdOptions/SkipDisk') 
  to instruct LINSTOR and DRBD to adjust (and recreate if necessary) the affected logical volumes again.
  For more information please visit: https://linbit.com/drbd-user-guide/linstor-guide-1_0-en/#s-linstor-drbd-skip-disk

## Reader pod placement: dauwalter

Placement evidence file: `piraeus-reader-dauwalter-placement-run-001.txt`.

NAME                                                READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
piraeus-rwo-strict-reader-dauwalter-run-001-bt2pp   0/1     Completed   0          11m   10.42.0.186   dauwalter   <none>           <none>

## Reader pod placement: selassie

Placement evidence file: `piraeus-reader-selassie-placement-run-001.txt`.

NAME                                               READY   STATUS      RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
piraeus-rwo-strict-reader-selassie-run-001-p244z   0/1     Completed   0          11m   10.42.2.214   selassie   <none>           <none>

## Final Job and pod state
NAME                                                    STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/piraeus-rwo-strict-reader-dauwalter-run-001   Complete   1/1           11m        25m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=9cbb68fe-4713-4fa0-9ac4-fad635c9a98b
job.batch/piraeus-rwo-strict-reader-selassie-run-001    Complete   1/1           11m        12m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=37f0077a-229e-4769-9564-20c7f2f8121c
job.batch/piraeus-rwo-strict-writer-fordyce-run-001     Complete   1/1           2m48s      32m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=6cc477c4-d0cf-4970-a789-5df5db5f5290

NAME                                                    READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
pod/piraeus-rwo-strict-reader-dauwalter-run-001-bt2pp   0/1     Completed   0          25m   10.42.0.186   dauwalter   <none>           <none>
pod/piraeus-rwo-strict-reader-selassie-run-001-p244z    0/1     Completed   0          12m   10.42.2.214   selassie    <none>           <none>
pod/piraeus-rwo-strict-writer-fordyce-run-001-pz2xh     0/1     Completed   0          32m   10.42.3.163   fordyce     <none>           <none>

## LINSTOR resources after readers
+----------------------------------------------------------------------------------------------------------------------+
| ResourceName                             | Node      | Layers       | Usage  | Conns |                  State | Vote |
|======================================================================================================================|
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | dauwalter | DRBD,STORAGE | Unused | [0;32mOk   [0m | [1;31mDiskless, SkipDisk (R)[0m | Yes  |
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | fordyce   | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32m              UpToDate[0m | Yes  |
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | selassie  | DRBD,STORAGE | Unused | [0;32mOk   [0m | [0;32m              UpToDate[0m | Yes  |
+----------------------------------------------------------------------------------------------------------------------+
[1;33mSkipDisk[0m:
  At least one resource has 'DrbdOptions/SkipDisk' enabled. This indicates an IO error on the
  affected resource(s). Remove this property (using 'linstor resource set-property $node $rsc DrbdOptions/SkipDisk') 
  to instruct LINSTOR and DRBD to adjust (and recreate if necessary) the affected logical volumes again.
  For more information please visit: https://linbit.com/drbd-user-guide/linstor-guide-1_0-en/#s-linstor-drbd-skip-disk

## LINSTOR volumes after readers
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Resource                                 | Node      | StoragePool   | VolNr | MinorNr | DeviceName    | Allocated | InUse  |                  State | Repl           |
|=======================================================================================================================================================================|
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | dauwalter | linstor-bench |     0 |    1000 | /dev/drbd1000 |  3.75 GiB | Unused | [1;31mDiskless, SkipDisk (R)[0m | [1;32mEstablished(2)[0m |
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | fordyce   | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.45 GiB | Unused | [0;32m              UpToDate[0m | [1;32mEstablished(2)[0m |
| pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26 | selassie  | linstor-bench |     0 |    1000 | /dev/drbd1000 | 16.33 GiB | Unused | [0;32m              UpToDate[0m | [1;32mEstablished(2)[0m |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------+
[1;33mSkipDisk[0m:
  At least one resource has 'DrbdOptions/SkipDisk' enabled. This indicates an IO error on the
  affected resource(s). Remove this property (using 'linstor resource set-property $node $rsc DrbdOptions/SkipDisk') 
  to instruct LINSTOR and DRBD to adjust (and recreate if necessary) the affected logical volumes again.
  For more information please visit: https://linbit.com/drbd-user-guide/linstor-guide-1_0-en/#s-linstor-drbd-skip-disk
