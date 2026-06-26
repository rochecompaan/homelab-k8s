# local-path benchmark v2 health

## ArgoCD application
NAME                              SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
storage-benchmark-v2-local-path   Synced        Healthy         3bef5add5dc1130bea20d72a8ec3f219e3647b4e   default

## Benchmark resources
NAME                                                  STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/local-path-fio-pvc-v2-run-001   Bound    pvc-14ea3fa7-3fcd-440a-83b5-756085277037   20Gi       RWO            local-path     <unset>                 37m   Filesystem

NAME                                            READY   STATUS      RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES
pod/storage-bench-local-path-v2-run-001-tsdf9   0/1     Completed   0          37m   10.42.3.203   fordyce   <none>           <none>

NAME                                            STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/storage-bench-local-path-v2-run-001   Complete   1/1           35m        37m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=3ebb9363-92de-4094-9859-0a284cdb9e93

## Selected PV
pvc-14ea3fa7-3fcd-440a-83b5-756085277037   20Gi       RWO            Delete           Bound      storage-benchmark-v2/local-path-fio-pvc-v2-run-001                                                        local-path        <unset>                          37m     Filesystem

## Problem pods
