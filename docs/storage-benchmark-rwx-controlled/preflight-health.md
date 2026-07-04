# Controlled RWX Benchmark Preflight Health

## Nodes
NAME        STATUS   ROLES                       AGE    VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE               KERNEL-VERSION   CONTAINER-RUNTIME
dauwalter   Ready    control-plane,etcd          13d    v1.35.5+k3s1   192.168.1.100   <none>        NixOS 26.05 (Yarara)   6.18.35          containerd://2.2.3-k3s1
fordyce     Ready    control-plane,etcd          13d    v1.35.5+k3s1   192.168.1.102   <none>        NixOS 26.05 (Yarara)   6.18.35          containerd://2.2.3-k3s1
kipsang     Ready    control-plane,etcd,master   208d   v1.35.5+k3s1   192.168.1.101   <none>        NixOS 26.05 (Yarara)   6.18.35          containerd://2.2.3-k3s1
selassie    Ready    control-plane,etcd          12d    v1.35.5+k3s1   192.168.1.104   <none>        NixOS 26.05 (Yarara)   6.18.35          containerd://2.2.3-k3s1
walmsley    Ready    control-plane,etcd,master   208d   v1.35.5+k3s1   192.168.1.103   <none>        NixOS 26.05 (Yarara)   6.18.35          containerd://2.2.3-k3s1

## Taints
["dauwalter",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-02T19:52:50Z"}]]
["fordyce",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-02T19:52:50Z"}]]
["kipsang",[]]
["selassie",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-02T19:52:50Z"}]]
["walmsley",[]]

## Storage benchmark namespace
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                                                                                                     STORAGECLASS      VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-0275c181-4d89-43f0-ab32-ecd8085f8a64   10Gi       RWO            Delete           Bound      monitoring/grafana-postgres-2                                                                             local-path        <unset>                          27d
persistentvolume/pvc-04650777-c194-4eb9-b2af-fd455255cdde   10Ti       RWO            Retain           Bound      garage/data-garage-1                                                                                      sata-local-path   <unset>                          181d
persistentvolume/pvc-08b5eeb9-33be-4571-ac04-8f1c6e9f7d48   20Gi       RWO            Delete           Bound      monitoring/prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0   longhorn          <unset>                          208d
persistentvolume/pvc-08ef49c4-f9a7-4491-ba9f-8db3b90ba083   1Gi        RWO            Delete           Bound      mosquitto/mosquitto-data                                                                                  longhorn          <unset>                          84d
persistentvolume/pvc-0a6edf35-8a7e-4778-9b85-9ec6f62708f2   10Ti       RWO            Retain           Bound      garage/data-garage-2                                                                                      sata-local-path   <unset>                          90d
persistentvolume/pvc-10307bff-383d-4a16-acc8-12c71360a862   10Gi       RWO            Delete           Bound      monitoring/grafana-postgres-6                                                                             local-path        <unset>                          11d
persistentvolume/pvc-12694f26-e364-48a2-b865-ab3a2bbaaa21   50Gi       RWO            Delete           Bound      nextcloud/postgres-7                                                                                      local-path        <unset>                          45d
persistentvolume/pvc-2d2d9603-dc74-44f8-89d6-95eab1f9679c   10Gi       RWO            Delete           Bound      monitoring/grafana-postgres-5                                                                             local-path        <unset>                          13d
persistentvolume/pvc-417d4dc3-8d09-4bad-adee-2e984e394706   512Mi      RWX            Delete           Bound      home-assistant/home-assistant-pvc                                                                         longhorn          <unset>                          84d
persistentvolume/pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec   5Gi        RWX            Delete           Bound      openclaw/openclaw-maildir                                                                                 longhorn          <unset>                          103d
persistentvolume/pvc-5d74fa68-fa99-4859-8dc0-1fda2222ac8c   50Gi       RWO            Delete           Bound      nextcloud/postgres-9                                                                                      local-path        <unset>                          13d
persistentvolume/pvc-5ec17e5c-b3a3-4c66-8189-b56ff346006b   10Gi       RWO            Delete           Bound      matrix/matrix                                                                                             longhorn          <unset>                          101d
persistentvolume/pvc-5f4889e7-0a15-4676-80f7-99e2b2a34902   50Gi       RWO            Delete           Bound      nextcloud/postgres-10                                                                                     local-path        <unset>                          13d
persistentvolume/pvc-675fae54-7948-4c47-b7f8-51ff6c75c534   10Ti       RWO            Retain           Bound      garage/data-garage-0                                                                                      sata-local-path   <unset>                          181d
persistentvolume/pvc-830baa59-fa1c-4370-bd54-1ba55596e32a   100Gi      RWX            Retain           Bound      webmutt/webmutt-maildir                                                                                   longhorn-sata     <unset>                          103d
persistentvolume/pvc-8c021ed3-0e21-4e69-88db-d6917955b1fc   100Gi      RWO            Delete           Bound      garage/meta-garage-1                                                                                      local-path        <unset>                          181d
persistentvolume/pvc-941fab52-0e56-4cb0-9a8f-33a8cb384d63   10Gi       RWO            Delete           Bound      matrix/matrix-whatsapp-postgres-7                                                                         local-path        <unset>                          45d
persistentvolume/pvc-972b33e1-0574-4a37-b81e-9913be95e3b6   8Gi        RWO            Delete           Bound      matrix/data-matrix-postgresql-0                                                                           longhorn          <unset>                          91d
persistentvolume/pvc-9a7dacd4-df75-47bf-ba93-48ab81f9ee0e   10Ti       RWO            Retain           Released   garage/data-garage-2                                                                                      sata-local-path   <unset>                          90d
persistentvolume/pvc-a17cf722-8299-4ade-b9df-026092eeb320   100Gi      RWO            Delete           Bound      garage/meta-garage-0                                                                                      local-path        <unset>                          181d
persistentvolume/pvc-a6835410-a25a-4f6d-ae79-b2a51738130a   10Gi       RWO            Delete           Bound      victoria-logs/server-volume-victoria-logs-victoria-logs-single-server-0                                   longhorn          <unset>                          160d
persistentvolume/pvc-a9e4f8aa-ea47-4257-8279-15ea55de198f   10Gi       RWO            Delete           Bound      matrix/matrix-whatsapp-postgres-9                                                                         local-path        <unset>                          13d
persistentvolume/pvc-af5e16df-be5a-4994-9eca-5af0da01f1ec   10Ti       RWO            Retain           Released   garage/data-garage-2                                                                                      sata-local-path   <unset>                          181d
persistentvolume/pvc-b7b5baeb-8b60-4823-81e2-2bc6b35ba79c   10Gi       RWO            Delete           Bound      forgejo/gitea-shared-storage                                                                              longhorn          <unset>                          90d
persistentvolume/pvc-bc05468c-aad4-402c-afdd-ba6546fc474d   100Gi      RWO            Retain           Bound      ftp/ftp-data                                                                                              sata-local-path   <unset>                          174d
persistentvolume/pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0   1Ti        RWX            Retain           Bound      jellyfin/media-pvc                                                                                        longhorn-sata     <unset>                          83d
persistentvolume/pvc-c5493dba-1f9f-4a98-b8d4-2c1d0a21097c   10Ti       RWO            Retain           Released   garage/data-garage-2                                                                                      sata-local-path   <unset>                          150d
persistentvolume/pvc-cccf0c12-09ed-4209-92b2-96419ec81e15   2Gi        RWO            Delete           Bound      openziti/openziti-controller                                                                              longhorn          <unset>                          160d
persistentvolume/pvc-d7b0fadf-0fe8-4b8e-b349-42deb41c4d35   10Gi       RWO            Delete           Bound      matrix/matrix-whatsapp-postgres-10                                                                        local-path        <unset>                          11d
persistentvolume/pvc-db52bf7e-393d-4d28-81f0-4774369b7c42   10Gi       RWO            Delete           Bound      nextcloud/nextcloud-nextcloud                                                                             longhorn          <unset>                          159d
persistentvolume/pvc-e02647a9-1002-42f1-b1d5-23846b4f0fec   10Gi       RWO            Delete           Bound      openclaw/openclaw                                                                                         longhorn          <unset>                          122d
persistentvolume/pvc-ebfc44a0-b130-40cd-8ef6-ec059dff7bb2   100Gi      RWO            Delete           Bound      garage/meta-garage-2                                                                                      local-path        <unset>                          90d
persistentvolume/pvc-f2a47938-9a54-4c8e-9384-1570563b9971   50Mi       RWO            Delete           Bound      openziti/openziti-router                                                                                  longhorn          <unset>                          59d

## Longhorn share managers
NAME                                                     READY   STATUS    RESTARTS       AGE   IP            NODE        NOMINATED NODE   READINESS GATES
share-manager-pvc-417d4dc3-8d09-4bad-adee-2e984e394706   1/1     Running   0              11d   10.42.4.136   walmsley    <none>           <none>
share-manager-pvc-570ec643-63ea-43b2-bbd8-71cf52af04ec   1/1     Running   0              11d   10.42.3.62    fordyce     <none>           <none>
share-manager-pvc-830baa59-fa1c-4370-bd54-1ba55596e32a   1/1     Running   0              11d   10.42.4.132   walmsley    <none>           <none>
share-manager-pvc-bdd16c20-7f37-4418-89d9-b3d11edcb5f0   1/1     Running   0              11d   10.42.3.61    fordyce     <none>           <none>

## Piraeus CRs
No resources found

## OpenEBS Mayastor CRs
error: the server doesn't have a resource type "mayastorvolumes"
