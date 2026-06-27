# Mayastor benchmark v2 health

## ArgoCD applications
NAME                            SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
openebs-mayastor                OutOfSync     Healthy         4.5.1                                      default
storage-benchmark-v2-mayastor   Synced        Healthy         be52dcad862d953fd16f7b7792c7208301a89f17   default

## DiskPools
NAME                       NODE        STATE     STATUS   ERROR   ALERTS    ENCRYPTED   CAPACITY   USED     AVAILABLE   DISK-CAPACITY   MAX-EXPANDABLE-SIZE
mayastor-bench-dauwalter   dauwalter   Created   Online           Healthy   false       30 GiB     20 GiB   10 GiB      30 GiB          127.8 GiB
mayastor-bench-fordyce     fordyce     Created   Online           Healthy   false       30 GiB     20 GiB   10 GiB      30 GiB          127.8 GiB
mayastor-bench-selassie    selassie    Created   Online           Healthy   false       30 GiB     20 GiB   10 GiB      30 GiB          127.8 GiB

## Benchmark resources
NAME                                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS           VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/mayastor-fio-pvc-v2-run-001   Bound    pvc-b163ad67-311b-4d8d-b233-29093d8a89a3   20Gi       RWO            mayastor-bench-v2-3r   <unset>                 23h   Filesystem

NAME                                          READY   STATUS      RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES
pod/storage-bench-mayastor-v2-run-002-dldrt   0/1     Completed   0          37m   10.42.3.206   fordyce   <none>           <none>

NAME                                          STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/storage-bench-mayastor-v2-run-002   Complete   1/1           35m        37m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=f9a87401-3795-46dc-9353-518d991606d8

## Mayastor VolumeAttachments

## Problem pods
