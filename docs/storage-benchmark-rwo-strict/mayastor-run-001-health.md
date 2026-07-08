# Mayastor strict RWO run 001 health

## Pod placement
NAME                                                 READY   STATUS      RESTARTS   AGE    IP            NODE        NOMINATED NODE   READINESS GATES
mayastor-rwo-strict-reader-dauwalter-run-001-r7ssc   0/1     Completed   0          25m    10.42.0.178   dauwalter   <none>           <none>
mayastor-rwo-strict-reader-selassie-run-001-p5kfx    0/1     Completed   0          12m    10.42.2.210   selassie    <none>           <none>
mayastor-rwo-strict-writer-fordyce-run-001-m2jtt     0/1     Completed   0          116m   10.42.3.158   fordyce     <none>           <none>

## Writer placement evidence file
See `docs/storage-benchmark-rwo-strict/mayastor-writer-placement-run-001.txt`.

```text
NAME                                               READY   STATUS      RESTARTS   AGE    IP            NODE      NOMINATED NODE   READINESS GATES
mayastor-rwo-strict-writer-fordyce-run-001-m2jtt   0/1     Completed   0          116m   10.42.3.158   fordyce   <none>           <none>
```

## Dauwalter reader placement evidence file
See `docs/storage-benchmark-rwo-strict/mayastor-reader-dauwalter-placement-run-001.txt`.

```text
NAME                                                 READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
mayastor-rwo-strict-reader-dauwalter-run-001-r7ssc   0/1     Completed   0          11m   10.42.0.178   dauwalter   <none>           <none>
```

## Selassie reader placement evidence file
See `docs/storage-benchmark-rwo-strict/mayastor-reader-selassie-placement-run-001.txt`.

```text
NAME                                                READY   STATUS      RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
mayastor-rwo-strict-reader-selassie-run-001-p5kfx   0/1     Completed   0          11m   10.42.2.210   selassie   <none>           <none>
```

## PVC and PV identity
NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS             VOLUMEATTRIBUTESCLASS   AGE    VOLUMEMODE
mayastor-rwo-strict-pvc-run-001   Bound    pvc-b58a44fa-ec8b-4bea-a957-911ad57ed2b2   20Gi       RWO            mayastor-rwo-strict-3r   <unset>                 127m   Filesystem
pvc-b58a44fa-ec8b-4bea-a957-911ad57ed2b2   20Gi       RWO            Delete           Bound      storage-benchmark-rwo-strict/mayastor-rwo-strict-pvc-run-001                                              mayastor-rwo-strict-3r            <unset>                          32m    Filesystem

## Mayastor disk pools
$ kubectl -n openebs get diskpools.openebs.io -o wide
NAME                       NODE        STATE     STATUS   ERROR   ALERTS    ENCRYPTED   CAPACITY   USED     AVAILABLE   DISK-CAPACITY   MAX-EXPANDABLE-SIZE
mayastor-bench-dauwalter   dauwalter   Created   Online           Healthy   false       30 GiB     20 GiB   10 GiB      30 GiB          127.8 GiB
mayastor-bench-fordyce     fordyce     Created   Online           Healthy   false       30 GiB     20 GiB   10 GiB      30 GiB          127.8 GiB
mayastor-bench-selassie    selassie    Created   Online           Healthy   false       30 GiB     20 GiB   10 GiB      30 GiB          127.8 GiB

## Mayastor volumes
$ kubectl get volumes.openebs.io -A -o wide
error: the server doesn't have a resource type "volumes"

## Mayastor replicas
$ kubectl get replicas.openebs.io -A -o wide
error: the server doesn't have a resource type "replicas"
