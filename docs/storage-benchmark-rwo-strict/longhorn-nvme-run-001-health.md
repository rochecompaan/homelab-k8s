# Longhorn NVMe strict RWO run 001 health

## Pod placement
NAME                                                      READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
longhorn-nvme-rwo-strict-reader-dauwalter-run-001-52tl7   0/1     Completed   0          27m   10.42.0.174   dauwalter   <none>           <none>
longhorn-nvme-rwo-strict-reader-selassie-run-001-wsp9n    0/1     Completed   0          12m   10.42.2.206   selassie    <none>           <none>
longhorn-nvme-rwo-strict-writer-fordyce-run-001-zdzxs     0/1     Completed   0          39m   10.42.3.154   fordyce     <none>           <none>

## Backend-specific placement evidence files
- Writer: longhorn-nvme-writer-placement-run-001.txt
- Dauwalter reader: longhorn-nvme-reader-dauwalter-placement-run-001.txt
- Selassie reader: longhorn-nvme-reader-selassie-placement-run-001.txt

## PVC and PV identity
NAME                                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                  VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
longhorn-nvme-rwo-strict-pvc-run-001   Bound    pvc-1c6a994a-8327-46b2-af64-3cb27f0adc33   20Gi       RWO            longhorn-nvme-rwo-strict-3r   <unset>                 39m   Filesystem
pvc-1c6a994a-8327-46b2-af64-3cb27f0adc33   20Gi       RWO            Delete           Bound      storage-benchmark-rwo-strict/longhorn-nvme-rwo-strict-pvc-run-001                                         longhorn-nvme-rwo-strict-3r       <unset>                          39m    Filesystem

## Longhorn volumes
NAME                                       DATA ENGINE   STATE      ROBUSTNESS   SCHEDULED   SIZE            NODE       AGE
pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48   v1            attached   healthy                  21474836480     kipsang    212d
pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083   v1            attached   healthy                  1073741824      kipsang    88d
pvc-1c6a994a-8327-46b2-af64-3cb27f0adc33   v1            detached   unknown                  21474836480                39m
pvc-417d4dc3-8d09-4bad-adee-2e984e394706   v1            attached   healthy                  536870912       walmsley   88d
pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec   v1            attached   healthy                  5368709120      fordyce    108d
pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b   v1            attached   healthy                  10737418240     walmsley   105d
pvc-830baa59-fa1c-4370-bd54-1ba55596e32a   v1            attached   degraded                 107374182400    walmsley   108d
pvc-972b33e1-0574-4a37-b81e-9913be95e3b6   v1            attached   healthy                  8589934592      kipsang    96d
pvc-a6835410-a25a-4f6d-ae79-b2a51738130a   v1            attached   healthy                  10737418240     walmsley   164d
pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c   v1            attached   healthy                  10737418240     walmsley   94d
pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0   v1            attached   degraded                 1099511627776   fordyce    88d
pvc-cccf0c12-09ed-4209-92b2-96419ec81e15   v1            attached   healthy                  2147483648      kipsang    164d
pvc-db52bf7e-393d-4d28-81f0-4774369b7c42   v1            attached   healthy                  10737418240     walmsley   163d
pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec   v1            attached   healthy                  10737418240     walmsley   126d
pvc-f2a47938-9a54-4c8e-9384-1570563b9971   v1            attached   healthy                  52428800        walmsley   64d

## Longhorn replicas
NAME                                                  DATA ENGINE   STATE     NODE        DISK                                   INSTANCEMANAGER                                     IMAGE                                AGE
pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48-r-3c686a3d   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   20d
pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48-r-6365d2b6   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48-r-6f5bcd1f   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083-r-4bcb0f2c   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083-r-52a9e8f1   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   20d
pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083-r-7401e14a   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-1c6a994a-8327-46b2-af64-3cb27f0adc33-r-3060f6ed   v1            stopped   kipsang     413befa8-2e7e-45cc-8dd8-3bd8cb4dca49                                                                                            39m
pvc-1c6a994a-8327-46b2-af64-3cb27f0adc33-r-6a6252f1   v1            stopped   walmsley    79622d60-33c2-4a3a-b03d-4c5d410580f3                                                                                            39m
pvc-1c6a994a-8327-46b2-af64-3cb27f0adc33-r-cf64cc50   v1            stopped   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690                                                                                            39m
pvc-417d4dc3-8d09-4bad-adee-2e984e394706-r-042cfc47   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-417d4dc3-8d09-4bad-adee-2e984e394706-r-4d8c2025   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   18d
pvc-417d4dc3-8d09-4bad-adee-2e984e394706-r-fb4f072a   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec-r-35dfebee   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec-r-58320f9f   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   18d
pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec-r-d2474b75   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b-r-a28d16fb   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   20d
pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b-r-bd5fab26   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b-r-e0991abf   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-830baa59-fa1c-4370-bd54-1ba55596e32a-r-3251158f   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   20d
pvc-830baa59-fa1c-4370-bd54-1ba55596e32a-r-603bd79a   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   21d
pvc-972b33e1-0574-4a37-b81e-9913be95e3b6-r-4ed5a2bc   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   20d
pvc-972b33e1-0574-4a37-b81e-9913be95e3b6-r-69d1d659   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-972b33e1-0574-4a37-b81e-9913be95e3b6-r-f974482b   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-a6835410-a25a-4f6d-ae79-b2a51738130a-r-1d84a618   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-a6835410-a25a-4f6d-ae79-b2a51738130a-r-31be141c   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-a6835410-a25a-4f6d-ae79-b2a51738130a-r-cded715d   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   18d
pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c-r-1fcfda01   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c-r-223a614a   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   18d
pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c-r-e90a9aa5   v1            running   fordyce     e0d080c9-b32e-49ff-9697-55dabc01282c   instance-manager-2d4e3ea1f8f71691a8f88612b2579baf   longhornio/longhorn-engine:v1.10.1   15d
pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0-r-08db89e4   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   20d
pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0-r-cd2e379f   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   16d
pvc-cccf0c12-09ed-4209-92b2-96419ec81e15-r-29d7231f   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-cccf0c12-09ed-4209-92b2-96419ec81e15-r-61f12662   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-cccf0c12-09ed-4209-92b2-96419ec81e15-r-f1bb4b6e   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   20d
pvc-db52bf7e-393d-4d28-81f0-4774369b7c42-r-9bd69122   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-db52bf7e-393d-4d28-81f0-4774369b7c42-r-c271a48c   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   18d
pvc-db52bf7e-393d-4d28-81f0-4774369b7c42-r-f23784eb   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec-r-403e6ed9   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec-r-5a3da814   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d
pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec-r-ed060e9a   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   18d
pvc-f2a47938-9a54-4c8e-9384-1570563b9971-r-aa77b620   v1            running   dauwalter   0742a187-2434-4fb2-964d-05ea99ae8690   instance-manager-7e677607497a70d7a9560e5c1a955448   longhornio/longhorn-engine:v1.10.1   17d
pvc-f2a47938-9a54-4c8e-9384-1570563b9971-r-cdceb35b   v1            running   kipsang     a950ecee-510c-4a7c-8cbf-52f456df08c0   instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   18d
pvc-f2a47938-9a54-4c8e-9384-1570563b9971-r-ded6579f   v1            running   walmsley    9839f649-7bdd-444a-8a9b-da772a282d21   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   15d

## Longhorn engines
NAME                                           DATA ENGINE   STATE     NODE       INSTANCEMANAGER                                     IMAGE                                AGE
pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48-e-0   v1            running   kipsang    instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   212d
pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083-e-0   v1            running   kipsang    instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   88d
pvc-1c6a994a-8327-46b2-af64-3cb27f0adc33-e-0   v1            stopped                                                                                                       39m
pvc-417d4dc3-8d09-4bad-adee-2e984e394706-e-0   v1            running   walmsley   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   88d
pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec-e-0   v1            running   fordyce    instance-manager-2d4e3ea1f8f71691a8f88612b2579baf   longhornio/longhorn-engine:v1.10.1   108d
pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b-e-0   v1            running   walmsley   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   105d
pvc-830baa59-fa1c-4370-bd54-1ba55596e32a-e-0   v1            running   walmsley   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   108d
pvc-972b33e1-0574-4a37-b81e-9913be95e3b6-e-0   v1            running   kipsang    instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   96d
pvc-a6835410-a25a-4f6d-ae79-b2a51738130a-e-0   v1            running   walmsley   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   164d
pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c-e-0   v1            running   walmsley   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   94d
pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0-e-0   v1            running   fordyce    instance-manager-2d4e3ea1f8f71691a8f88612b2579baf   longhornio/longhorn-engine:v1.10.1   88d
pvc-cccf0c12-09ed-4209-92b2-96419ec81e15-e-0   v1            running   kipsang    instance-manager-7b720f693d6d43523767705e8e1d363d   longhornio/longhorn-engine:v1.10.1   164d
pvc-db52bf7e-393d-4d28-81f0-4774369b7c42-e-0   v1            running   walmsley   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   163d
pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec-e-0   v1            running   walmsley   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   126d
pvc-f2a47938-9a54-4c8e-9384-1570563b9971-e-0   v1            running   walmsley   instance-manager-0047d9c46fb847ee5b5cccf5fd60bed2   longhornio/longhorn-engine:v1.10.1   64d

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
