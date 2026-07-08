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

## Cleanup state

Captured: 2026-07-08T20:18:30+02:00

Cleanup commit pushed: 7613c0f chore(storage): deactivate strict RWO benchmarks

Bounded ArgoCD prune polling result: timed out after 5 minutes; no force/direct cluster mutation was performed.

Root Application status after polling:
```text
Synced	Healthy	Succeeded	successfully synced (all tasks run)
revision=caf3af5427b8bea5a1f54f972ad5a297b3ab6a3d
```

Strict RWO Applications still listed after bounded polling:
```text
storage-benchmark-rwo-strict-longhorn   Synced        Healthy
storage-benchmark-rwo-strict-mayastor   OutOfSync     Healthy
storage-benchmark-rwo-strict-piraeus    OutOfSync     Healthy
```

Strict RWO Application detail after bounded polling:
```text
storage-benchmark-rwo-strict-longhorn	deletionTimestamp=	finalizers=["resources-finalizer.argocd.argoproj.io"]	sync=Synced	health=Healthy
storage-benchmark-rwo-strict-mayastor	deletionTimestamp=	finalizers=["resources-finalizer.argocd.argoproj.io"]	sync=OutOfSync	health=Healthy
storage-benchmark-rwo-strict-piraeus	deletionTimestamp=	finalizers=["resources-finalizer.argocd.argoproj.io"]	sync=OutOfSync	health=Healthy
```

Namespace resources still present after bounded polling:
```text
NAME                                                          READY   STATUS      RESTARTS   AGE
pod/longhorn-nvme-rwo-strict-reader-dauwalter-run-001-52tl7   0/1     Completed   0          4h26m
pod/longhorn-nvme-rwo-strict-reader-selassie-run-001-wsp9n    0/1     Completed   0          4h11m
pod/longhorn-nvme-rwo-strict-writer-fordyce-run-001-zdzxs     0/1     Completed   0          4h38m
pod/mayastor-rwo-strict-reader-dauwalter-run-001-r7ssc        0/1     Completed   0          126m
pod/mayastor-rwo-strict-reader-selassie-run-001-p5kfx         0/1     Completed   0          113m
pod/mayastor-rwo-strict-writer-fordyce-run-001-m2jtt          0/1     Completed   0          3h37m
pod/piraeus-rwo-strict-reader-dauwalter-run-001-bt2pp         0/1     Completed   0          47m
pod/piraeus-rwo-strict-reader-selassie-run-001-p244z          0/1     Completed   0          34m
pod/piraeus-rwo-strict-writer-fordyce-run-001-pz2xh           0/1     Completed   0          54m

NAME                                                          STATUS     COMPLETIONS   DURATION   AGE
job.batch/longhorn-nvme-rwo-strict-reader-dauwalter-run-001   Complete   1/1           12m        4h26m
job.batch/longhorn-nvme-rwo-strict-reader-selassie-run-001    Complete   1/1           12m        4h11m
job.batch/longhorn-nvme-rwo-strict-writer-fordyce-run-001     Complete   1/1           8m10s      4h38m
job.batch/mayastor-rwo-strict-reader-dauwalter-run-001        Complete   1/1           11m        126m
job.batch/mayastor-rwo-strict-reader-selassie-run-001         Complete   1/1           11m        113m
job.batch/mayastor-rwo-strict-writer-fordyce-run-001          Complete   1/1           89m        3h37m
job.batch/piraeus-rwo-strict-reader-dauwalter-run-001         Complete   1/1           11m        47m
job.batch/piraeus-rwo-strict-reader-selassie-run-001          Complete   1/1           11m        34m
job.batch/piraeus-rwo-strict-writer-fordyce-run-001           Complete   1/1           2m48s      54m

NAME                                                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                  VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/longhorn-nvme-rwo-strict-pvc-run-001   Bound    pvc-1c6a994a-8327-46b2-af64-3cb27f0adc33   20Gi       RWO            longhorn-nvme-rwo-strict-3r   <unset>                 4h38m
persistentvolumeclaim/mayastor-rwo-strict-pvc-run-001        Bound    pvc-b58a44fa-ec8b-4bea-a957-911ad57ed2b2   20Gi       RWO            mayastor-rwo-strict-3r        <unset>                 3h48m
persistentvolumeclaim/piraeus-rwo-strict-pvc-run-001         Bound    pvc-e1455cd2-5669-4156-b3d0-4e1bb60a3b26   20Gi       RWO            piraeus-rwo-strict-3r         <unset>                 89m
```

Follow-up validation after cleanup evidence commit:

Captured: 2026-07-08T20:19:29+02:00

Strict RWO Applications still listed:
```text
storage-benchmark-rwo-strict-piraeus   OutOfSync     Missing
```

Remaining strict RWO Application detail:
```text
storage-benchmark-rwo-strict-piraeus	deletionTimestamp=2026-07-08T18:18:58Z	finalizers=["resources-finalizer.argocd.argoproj.io"]	sync=OutOfSync	health=Missing
```

Namespace resources:
```text
No resources found in storage-benchmark-rwo-strict namespace.
```
