# Mayastor recovery observation

Recorded: 2026-06-22T08:27:15Z

## Plan adjustment

- Original plan named `selassie` as the recovery observation node.
- Operator instructed to exclude `selassie` from outage tests because it hosts a large Garage S3 volume.
- Candidate outage nodes are therefore `dauwalter` and `fordyce`.
- Selected candidate: `dauwalter`, because `fordyce` currently hosts the `nextcloud/postgres` CNPG primary (`postgres-10`), while `dauwalter` hosts only CNPG replicas among the checked local-path database pods.

## Pre-outage health snapshot

### Nodes
```text
NAME        STATUS   ROLES                AGE   VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE               KERNEL-VERSION   CONTAINER-RUNTIME
dauwalter   Ready    control-plane,etcd   25h   v1.35.5+k3s1   192.168.1.100   <none>        NixOS 26.05 (Yarara)   6.18.35          containerd://2.2.3-k3s1
fordyce     Ready    control-plane,etcd   24h   v1.35.5+k3s1   192.168.1.102   <none>        NixOS 26.05 (Yarara)   6.18.35          containerd://2.2.3-k3s1
selassie    Ready    control-plane,etcd   22h   v1.35.5+k3s1   192.168.1.104   <none>        NixOS 26.05 (Yarara)   6.18.35          containerd://2.2.3-k3s1
```

### ArgoCD Applications
```text
NAME                 SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
openebs-mayastor     OutOfSync     Healthy         4.5.1                                      default
mayastor-benchmark   Synced        Healthy         d5e8018761a20c9faa723c5405347d61dabf9697   default
```

### DiskPools
```text
NAME                       NODE        STATE     STATUS   ERROR   ALERTS    ENCRYPTED   CAPACITY   USED     AVAILABLE   DISK-CAPACITY   MAX-EXPANDABLE-SIZE
mayastor-bench-dauwalter   dauwalter   Created   Online           Healthy   false       30 GiB     10 GiB   20 GiB      30 GiB          127.8 GiB
mayastor-bench-fordyce     fordyce     Created   Online           Healthy   false       30 GiB     10 GiB   20 GiB      30 GiB          127.8 GiB
mayastor-bench-selassie    selassie    Created   Online           Healthy   false       30 GiB     10 GiB   20 GiB      30 GiB          127.8 GiB
```

### Benchmark PVC, pod, and job
```text
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/mayastor-fio-pvc   Bound    pvc-a8515b32-1fd9-40af-9fe7-fc78d6e55c1c   10Gi       RWO            mayastor-bench-3r   <unset>                 74m   Filesystem

NAME                                       READY   STATUS      RESTARTS   AGE   IP           NODE        NOMINATED NODE   READINESS GATES
pod/storage-bench-mayastor-run-001-n8fb4   0/1     Completed   0          59m   10.42.0.57   dauwalter   <none>           <none>

NAME                                       STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/storage-bench-mayastor-run-001   Complete   1/1           22m        59m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=6c916c62-1b6e-46a1-931f-43030daab096
```

### OpenEBS selected pods
```text
NAME                                         READY   STATUS    RESTARTS   AGE   IP              NODE        NOMINATED NODE   READINESS GATES
openebs-agent-ha-node-2rxbq                  1/1     Running   0          77m   192.168.1.102   fordyce     <none>           <none>
openebs-agent-ha-node-7xjgj                  1/1     Running   0          78m   192.168.1.100   dauwalter   <none>           <none>
openebs-agent-ha-node-8ks4g                  1/1     Running   0          78m   192.168.1.104   selassie    <none>           <none>
openebs-api-rest-68f49d874-njqvr             1/1     Running   0          87m   10.42.4.103     walmsley    <none>           <none>
openebs-csi-node-9mxzz                       2/2     Running   0          77m   192.168.1.102   fordyce     <none>           <none>
openebs-csi-node-t55pv                       2/2     Running   0          77m   192.168.1.100   dauwalter   <none>           <none>
openebs-csi-node-ts2sm                       2/2     Running   0          77m   192.168.1.104   selassie    <none>           <none>
openebs-etcd-0                               1/1     Running   0          75m   10.42.0.56      dauwalter   <none>           <none>
openebs-etcd-1                               1/1     Running   0          76m   10.42.4.109     walmsley    <none>           <none>
openebs-etcd-2                               1/1     Running   0          77m   10.42.3.40      fordyce     <none>           <none>
openebs-io-engine-mdfqf                      2/2     Running   0          87m   192.168.1.104   selassie    <none>           <none>
openebs-io-engine-nl7sh                      2/2     Running   0          87m   192.168.1.100   dauwalter   <none>           <none>
openebs-io-engine-xqzg7                      2/2     Running   0          87m   192.168.1.102   fordyce     <none>           <none>
openebs-nats-0                               3/3     Running   0          87m   10.42.4.105     walmsley    <none>           <none>
openebs-nats-1                               3/3     Running   0          87m   10.42.1.40      kipsang     <none>           <none>
openebs-nats-2                               3/3     Running   0          87m   10.42.3.36      fordyce     <none>           <none>
```

### Candidate node workload risk summary

#### dauwalter non-DaemonSet pods
```text
non-daemonset pods=33
ns=argocd count=3 pods=argocd-application-controller-0,argocd-notifications-controller-55b4d8859f-cxmtz,argocd-repo-server-759ccb78dc-xsmtv
ns=cert-manager count=3 pods=cert-manager-cainjector-65fcfd6ccf-vt44w,cert-manager-webhook-9b4dd78-54fp9,trust-manager-85d8d8994b-cl84f
ns=forgejo count=1 pods=forgejo-runner-8688f45c4d-r4c89
ns=kube-system count=2 pods=coredns-5bf648f7b5-vhpwm,helm-install-argocd-4znpz
ns=local-path-storage count=1 pods=local-path-provisioner-7d6dddf9dd-dm26n
ns=longhorn-system count=6 pods=csi-attacher-5945f65f4-tn2k9,csi-provisioner-84dbb8d478-jxcgz,csi-resizer-f8498868f-7nrsl,csi-snapshotter-54c9dc4c66-8pkmn,instance-manager-7e677607497a70d7a9560e5c1a955448,share-manager-pvc-830baa59-fa1c-4370-bd54-1ba55596e32a
ns=matrix count=3 pods=coturn-5779dcf5bf-kxsjm,matrix-whatsapp-7c56fd845-jc29j,matrix-whatsapp-postgres-8
ns=monitoring count=5 pods=alertmanager-kube-prometheus-stack-alertmanager-0,grafana-matrix-webhook-bb7c694d9-xqbzp,grafana-postgres-4,kube-prometheus-stack-grafana-755f58bdb4-f9tjq,kube-prometheus-stack-kube-state-metrics-7c7ff6864c-85dqx
ns=mosquitto count=1 pods=mosquitto-6bdf7dccd7-95kc8
ns=nextcloud count=1 pods=postgres-9
ns=openclaw count=2 pods=openclaw-d7b8d49fb-kwg5s,openclaw-mbsync-84dbb45b88-z7x7d
ns=openebs count=1 pods=openebs-etcd-0
ns=storage-benchmark count=1 pods=storage-bench-mayastor-run-001-n8fb4
ns=victoria-logs count=1 pods=victoria-logs-victoria-logs-single-server-0
ns=webmutt count=1 pods=webmutt-75c66488d9-2zvff
ns=ziti count=1 pods=miniziti-controller-manager-558576945b-8wd8b
```

#### fordyce non-DaemonSet pods
```text
non-daemonset pods=20
ns=forgejo count=1 pods=forgejo-578d8d959b-976pq
ns=home-assistant count=1 pods=home-assistant-595b88f764-hskfh
ns=kube-system count=2 pods=metrics-server-c8774f4f4-44pbv,snapshot-controller-5b7776766f-7npdl
ns=kyverno count=2 pods=kyverno-admission-controller-84bd95bf65-zld9x,kyverno-background-controller-5b9995865f-nb6w7
ns=longhorn-system count=6 pods=csi-attacher-5945f65f4-q5lbp,csi-provisioner-84dbb8d478-nxccq,csi-resizer-f8498868f-4xscd,csi-snapshotter-54c9dc4c66-ggxzb,instance-manager-2d4e3ea1f8f71691a8f88612b2579baf,share-manager-pvc-417d4dc3-8d09-4bad-adee-2e984e394706
ns=matrix count=2 pods=matrix-84fccc4d55-qjxzr,matrix-whatsapp-postgres-9
ns=monitoring count=1 pods=grafana-postgres-5
ns=nextcloud count=2 pods=nextcloud-5dcfd4bbb-fxdvc,postgres-10
ns=openebs count=2 pods=openebs-etcd-2,openebs-nats-2
ns=openziti count=1 pods=openziti-router-5495cbb496-7k7p5
```

#### Candidate local-path PVs
```text
- pvc-2d2d9603-dc74-44f8-89d6-95eab1f9679c: node=fordyce, claim=monitoring/grafana-postgres-5, phase=Bound
- pvc-56989935-dbed-4212-b01f-7eb7474cb4c2: node=dauwalter, claim=matrix/matrix-whatsapp-postgres-8, phase=Bound
- pvc-5d74fa68-fa99-4859-8dc0-1fda2222ac8c: node=dauwalter, claim=nextcloud/postgres-9, phase=Bound
- pvc-5f4889e7-0a15-4676-80f7-99e2b2a34902: node=fordyce, claim=nextcloud/postgres-10, phase=Bound
- pvc-84cb4288-ba1f-4714-afcc-e4b270c14738: node=dauwalter, claim=monitoring/grafana-postgres-4, phase=Bound
- pvc-a9e4f8aa-ea47-4257-8279-15ea55de198f: node=fordyce, claim=matrix/matrix-whatsapp-postgres-9, phase=Bound
- pvc-bf48d42d-317c-491e-a877-0e1fc8994fa0: node=fordyce, claim=openebs/data-openebs-etcd-2, phase=Bound
- pvc-cbfa0455-5a61-494a-842b-6fd10c02bae6: node=dauwalter, claim=openebs/data-openebs-etcd-0, phase=Bound
```

#### CNPG clusters
```text
- matrix/matrix-whatsapp-postgres: instances=3, ready=3, primary=matrix-whatsapp-postgres-7
- monitoring/grafana-postgres: instances=3, ready=3, primary=grafana-postgres-2
- nextcloud/postgres: instances=3, ready=3, primary=postgres-10
```

## Outage test plan

- Do not outage `selassie`.
- Add a temporary GitOps-managed `mayastor-recovery-probe` Deployment before the outage.
- The probe mounts the existing `mayastor-fio-pvc`, continuously appends heartbeat records, and fsyncs a small block file on the Mayastor volume.
- The probe is allowed to run only on `dauwalter` or `fordyce`, prefers `dauwalter` initially, and uses short `NoExecute` tolerations so a `dauwalter` failure should migrate it during the observation window.
- Reboot `dauwalter` only after typed operator confirmation.
- Planned reboot command: `ssh roche@192.168.1.100 sudo systemctl reboot`.
- Observe Deployment migration, pod replacement, PVC detach/reattach, Mayastor nexus/replica state, node readiness, DiskPool state, OpenEBS pods, benchmark PVC, and ArgoCD health until recovery.
