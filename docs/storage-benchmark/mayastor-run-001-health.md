# Mayastor post-benchmark health
Mon 22 Jun 2026 07:51:34 UTC

## ArgoCD Applications
NAME                 SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
openebs-mayastor     OutOfSync     Healthy         4.5.1                                      default
mayastor-benchmark   Synced        Healthy         bda08f6be2101821c99978891b86f38e1451ebaa   default

## DiskPools
NAME                       NODE        STATE     STATUS   ERROR   ALERTS    ENCRYPTED   CAPACITY   USED     AVAILABLE   DISK-CAPACITY   MAX-EXPANDABLE-SIZE
mayastor-bench-dauwalter   dauwalter   Created   Online           Healthy   false       30 GiB     10 GiB   20 GiB      30 GiB          127.8 GiB
mayastor-bench-fordyce     fordyce     Created   Online           Healthy   false       30 GiB     10 GiB   20 GiB      30 GiB          127.8 GiB
mayastor-bench-selassie    selassie    Created   Online           Healthy   false       30 GiB     10 GiB   20 GiB      30 GiB          127.8 GiB

## OpenEBS pods
NAME                                         READY   STATUS    RESTARTS   AGE   IP              NODE        NOMINATED NODE   READINESS GATES
openebs-agent-core-594c64dd9-psqg7           2/2     Running   0          51m   10.42.4.104     walmsley    <none>           <none>
openebs-agent-ha-node-2rxbq                  1/1     Running   0          42m   192.168.1.102   fordyce     <none>           <none>
openebs-agent-ha-node-7xjgj                  1/1     Running   0          42m   192.168.1.100   dauwalter   <none>           <none>
openebs-agent-ha-node-8ks4g                  1/1     Running   0          42m   192.168.1.104   selassie    <none>           <none>
openebs-api-rest-68f49d874-njqvr             1/1     Running   0          51m   10.42.4.103     walmsley    <none>           <none>
openebs-csi-controller-5cbb6cd9df-kscn8      6/6     Running   0          42m   192.168.1.103   walmsley    <none>           <none>
openebs-csi-node-9mxzz                       2/2     Running   0          41m   192.168.1.102   fordyce     <none>           <none>
openebs-csi-node-t55pv                       2/2     Running   0          41m   192.168.1.100   dauwalter   <none>           <none>
openebs-csi-node-ts2sm                       2/2     Running   0          42m   192.168.1.104   selassie    <none>           <none>
openebs-etcd-0                               1/1     Running   0          39m   10.42.0.56      dauwalter   <none>           <none>
openebs-etcd-1                               1/1     Running   0          41m   10.42.4.109     walmsley    <none>           <none>
openebs-etcd-2                               1/1     Running   0          42m   10.42.3.40      fordyce     <none>           <none>
openebs-io-engine-mdfqf                      2/2     Running   0          51m   192.168.1.104   selassie    <none>           <none>
openebs-io-engine-nl7sh                      2/2     Running   0          51m   192.168.1.100   dauwalter   <none>           <none>
openebs-io-engine-xqzg7                      2/2     Running   0          51m   192.168.1.102   fordyce     <none>           <none>
openebs-nats-0                               3/3     Running   0          51m   10.42.4.105     walmsley    <none>           <none>
openebs-nats-1                               3/3     Running   0          51m   10.42.1.40      kipsang     <none>           <none>
openebs-nats-2                               3/3     Running   0          51m   10.42.3.36      fordyce     <none>           <none>
openebs-operator-diskpool-6f7f4d9985-z7l92   1/1     Running   0          51m   10.42.4.106     walmsley    <none>           <none>

## Benchmark PVC/PV/Pod/Job
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/mayastor-fio-pvc   Bound    pvc-a8515b32-1fd9-40af-9fe7-fc78d6e55c1c   10Gi       RWO            mayastor-bench-3r   <unset>                 38m   Filesystem

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                                                                                                     STORAGECLASS        VOLUMEATTRIBUTESCLASS   REASON   AGE    VOLUMEMODE
persistentvolume/pvc-0275c181-4d89-43f0-ab32-ecd8085f8a64   10Gi       RWO            Delete           Bound      monitoring/grafana-postgres-2                                                                             local-path          <unset>                          15d    Filesystem
persistentvolume/pvc-04650777-c194-4eb9-b2af-fd455255cdde   10Ti       RWO            Retain           Bound      garage/data-garage-1                                                                                      sata-local-path     <unset>                          169d   Filesystem
persistentvolume/pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48   20Gi       RWO            Delete           Bound      monitoring/prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0   longhorn            <unset>                          195d   Filesystem
persistentvolume/pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083   1Gi        RWO            Delete           Bound      mosquitto/mosquitto-data                                                                                  longhorn            <unset>                          72d    Filesystem
persistentvolume/pvc-0a6edf35-8a7e-4778-9b85-9ec6f62708f2   10Ti       RWO            Retain           Bound      garage/data-garage-2                                                                                      sata-local-path     <unset>                          78d    Filesystem
persistentvolume/pvc-12694f26-e364-48a2-b865-ab3a2bbaaa21   50Gi       RWO            Delete           Bound      nextcloud/postgres-7                                                                                      local-path          <unset>                          33d    Filesystem
persistentvolume/pvc-2d2d9603-dc74-44f8-89d6-95eab1f9679c   10Gi       RWO            Delete           Bound      monitoring/grafana-postgres-5                                                                             local-path          <unset>                          23h    Filesystem
persistentvolume/pvc-417d4dc3-8d09-4bad-adee-2e984e394706   512Mi      RWX            Delete           Bound      home-assistant/home-assistant-pvc                                                                         longhorn            <unset>                          71d    Filesystem
persistentvolume/pvc-56989935-dbed-4212-b01f-7eb7474cb4c2   10Gi       RWO            Delete           Bound      matrix/matrix-whatsapp-postgres-8                                                                         local-path          <unset>                          24h    Filesystem
persistentvolume/pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec   5Gi        RWX            Delete           Bound      openclaw/openclaw-maildir                                                                                 longhorn            <unset>                          91d    Filesystem
persistentvolume/pvc-5d74fa68-fa99-4859-8dc0-1fda2222ac8c   50Gi       RWO            Delete           Bound      nextcloud/postgres-9                                                                                      local-path          <unset>                          24h    Filesystem
persistentvolume/pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b   10Gi       RWO            Delete           Bound      matrix/matrix                                                                                             longhorn            <unset>                          89d    Filesystem
persistentvolume/pvc-5f4889e7-0a15-4676-80f7-99e2b2a34902   50Gi       RWO            Delete           Bound      nextcloud/postgres-10                                                                                     local-path          <unset>                          23h    Filesystem
persistentvolume/pvc-675fae54-7948-4c47-b7f8-51ff6c75c534   10Ti       RWO            Retain           Bound      garage/data-garage-0                                                                                      sata-local-path     <unset>                          169d   Filesystem
persistentvolume/pvc-830baa59-fa1c-4370-bd54-1ba55596e32a   100Gi      RWX            Retain           Bound      webmutt/webmutt-maildir                                                                                   longhorn-sata       <unset>                          91d    Filesystem
persistentvolume/pvc-84cb4288-ba1f-4714-afcc-e4b270c14738   10Gi       RWO            Delete           Bound      monitoring/grafana-postgres-4                                                                             local-path          <unset>                          24h    Filesystem
persistentvolume/pvc-8c021ed3-0e21-4e69-88db-d6917955b1fc   100Gi      RWO            Delete           Bound      garage/meta-garage-1                                                                                      local-path          <unset>                          169d   Filesystem
persistentvolume/pvc-9371c00f-2380-402a-8ff6-c6c0035191a1   2Gi        RWO            Delete           Bound      openebs/data-openebs-etcd-1                                                                               local-path          <unset>                          51m    Filesystem
persistentvolume/pvc-941fab52-0e56-4cb0-9a8f-33a8cb384d63   10Gi       RWO            Delete           Bound      matrix/matrix-whatsapp-postgres-7                                                                         local-path          <unset>                          33d    Filesystem
persistentvolume/pvc-972b33e1-0574-4a37-b81e-9913be95e3b6   8Gi        RWO            Delete           Bound      matrix/data-matrix-postgresql-0                                                                           longhorn            <unset>                          79d    Filesystem
persistentvolume/pvc-9a7dacd4-df75-47bf-ba93-48ab81f9ee0e   10Ti       RWO            Retain           Released   garage/data-garage-2                                                                                      sata-local-path     <unset>                          78d    Filesystem
persistentvolume/pvc-a17cf722-8299-4ade-b9df-026092eeb320   100Gi      RWO            Delete           Bound      garage/meta-garage-0                                                                                      local-path          <unset>                          169d   Filesystem
persistentvolume/pvc-a6835410-a25a-4f6d-ae79-b2a51738130a   10Gi       RWO            Delete           Bound      victoria-logs/server-volume-victoria-logs-victoria-logs-single-server-0                                   longhorn            <unset>                          147d   Filesystem
persistentvolume/pvc-a8515b32-1fd9-40af-9fe7-fc78d6e55c1c   10Gi       RWO            Delete           Bound      storage-benchmark/mayastor-fio-pvc                                                                        mayastor-bench-3r   <unset>                          23m    Filesystem
persistentvolume/pvc-a9e4f8aa-ea47-4257-8279-15ea55de198f   10Gi       RWO            Delete           Bound      matrix/matrix-whatsapp-postgres-9                                                                         local-path          <unset>                          24h    Filesystem
persistentvolume/pvc-af5e16df-be5a-4994-9eca-5af0da01f1ec   10Ti       RWO            Retain           Released   garage/data-garage-2                                                                                      sata-local-path     <unset>                          169d   Filesystem
persistentvolume/pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c   10Gi       RWO            Delete           Bound      forgejo/gitea-shared-storage                                                                              longhorn            <unset>                          78d    Filesystem
persistentvolume/pvc-bc05468c-aad4-402c-afdd-ba6546fc474d   100Gi      RWO            Retain           Bound      ftp/ftp-data                                                                                              sata-local-path     <unset>                          162d   Filesystem
persistentvolume/pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0   1Ti        RWX            Retain           Bound      jellyfin/media-pvc                                                                                        longhorn-sata       <unset>                          71d    Filesystem
persistentvolume/pvc-bf48d42d-317c-491e-a877-0e1fc8994fa0   2Gi        RWO            Delete           Bound      openebs/data-openebs-etcd-2                                                                               local-path          <unset>                          51m    Filesystem
persistentvolume/pvc-c5493dba-1f9f-4a98-b8d4-2c1d0a21097c   10Ti       RWO            Retain           Released   garage/data-garage-2                                                                                      sata-local-path     <unset>                          138d   Filesystem
persistentvolume/pvc-cbfa0455-5a61-494a-842b-6fd10c02bae6   2Gi        RWO            Delete           Bound      openebs/data-openebs-etcd-0                                                                               local-path          <unset>                          51m    Filesystem
persistentvolume/pvc-cccf0c12-09ed-4209-92b2-96419ec81e15   2Gi        RWO            Delete           Bound      openziti/openziti-controller                                                                              longhorn            <unset>                          148d   Filesystem
persistentvolume/pvc-db52bf7e-393d-4d28-81f0-4774369b7c42   10Gi       RWO            Delete           Bound      nextcloud/nextcloud-nextcloud                                                                             longhorn            <unset>                          147d   Filesystem
persistentvolume/pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec   10Gi       RWO            Delete           Bound      openclaw/openclaw                                                                                         longhorn            <unset>                          110d   Filesystem
persistentvolume/pvc-ebfc44a0-b130-40cd-8ef6-ec059dff7bb2   100Gi      RWO            Delete           Bound      garage/meta-garage-2                                                                                      local-path          <unset>                          78d    Filesystem
persistentvolume/pvc-f2a47938-9a54-4c8e-9384-1570563b9971   50Mi       RWO            Delete           Bound      openziti/openziti-router                                                                                  longhorn            <unset>                          47d    Filesystem

NAME                                       READY   STATUS      RESTARTS   AGE   IP           NODE        NOMINATED NODE   READINESS GATES
pod/storage-bench-mayastor-run-001-n8fb4   0/1     Completed   0          23m   10.42.0.57   dauwalter   <none>           <none>

NAME                                       STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/storage-bench-mayastor-run-001   Complete   1/1           22m        23m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=6c916c62-1b6e-46a1-931f-43030daab096

## Benchmark events tail
LAST SEEN   TYPE     REASON                   OBJECT                                     MESSAGE
23m         Normal   Scheduled                pod/storage-bench-mayastor-run-001-n8fb4   Successfully assigned storage-benchmark/storage-bench-mayastor-run-001-n8fb4 to dauwalter
23m         Normal   WaitForFirstConsumer     persistentvolumeclaim/mayastor-fio-pvc     waiting for first consumer to be created before binding
23m         Normal   Provisioning             persistentvolumeclaim/mayastor-fio-pvc     External provisioner is provisioning volume for claim "storage-benchmark/mayastor-fio-pvc"
23m         Normal   ProvisioningSucceeded    persistentvolumeclaim/mayastor-fio-pvc     Successfully provisioned volume pvc-a8515b32-1fd9-40af-9fe7-fc78d6e55c1c
23m         Normal   SuccessfulCreate         job/storage-bench-mayastor-run-001         Created pod: storage-bench-mayastor-run-001-n8fb4
23m         Normal   SuccessfulAttachVolume   pod/storage-bench-mayastor-run-001-n8fb4   AttachVolume.Attach succeeded for volume "pvc-a8515b32-1fd9-40af-9fe7-fc78d6e55c1c"
23m         Normal   Pulling                  pod/storage-bench-mayastor-run-001-n8fb4   Pulling image "nixery.dev/shell/fio/jq/coreutils"
23m         Normal   Pulled                   pod/storage-bench-mayastor-run-001-n8fb4   Successfully pulled image "nixery.dev/shell/fio/jq/coreutils" in 18.916s (18.916s including waiting). Image size: 125930167 bytes.
23m         Normal   Created                  pod/storage-bench-mayastor-run-001-n8fb4   Container created
23m         Normal   Started                  pod/storage-bench-mayastor-run-001-n8fb4   Container started
84s         Normal   Completed                job/storage-bench-mayastor-run-001         Job completed
