# Mayastor-backed RWX via NFS/NFS CSI Controlled Run 001 Health

## ArgoCD applications
NAME                                        SYNC STATUS   HEALTH STATUS
root                                        Synced        Healthy
openebs-mayastor                            OutOfSync     Healthy
csi-driver-nfs-rwx-controlled               Synced        Healthy
storage-benchmark-rwx-controlled-mayastor   OutOfSync     Healthy

## Benchmark resources
NAME                                                                  READY   STATUS      RESTARTS   AGE    IP            NODE        NOMINATED NODE   READINESS GATES
pod/mayastor-rwx-controlled-nfs-server-f458cbd84-4c7n2                1/1     Running     0          152m   10.42.3.151   fordyce     <none>           <none>
pod/mayastor-rwx-controlled-remote-concurrent-dauwalter-run-00vwlbc   0/1     Completed   0          14m    10.42.0.170   dauwalter   <none>           <none>
pod/mayastor-rwx-controlled-remote-concurrent-selassie-run-001q74wn   0/1     Completed   0          14m    10.42.2.202   selassie    <none>           <none>
pod/mayastor-rwx-controlled-remote-single-dauwalter-run-001-9vmwh     0/1     Completed   0          95m    10.42.0.169   dauwalter   <none>           <none>
pod/mayastor-rwx-controlled-remote-single-selassie-run-001-62926      0/1     Completed   0          53m    10.42.2.201   selassie    <none>           <none>
pod/mayastor-rwx-proof-a                                              1/1     Running     0          95m    10.42.0.168   dauwalter   <none>           <none>
pod/mayastor-rwx-proof-b                                              1/1     Running     0          95m    10.42.2.200   selassie    <none>           <none>

NAME                                                                    STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/mayastor-rwx-controlled-remote-concurrent-dauwalter-run-001   Complete   1/1           11m        14m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=b05515df-995b-4fad-90eb-d0e7a7ad50fc
job.batch/mayastor-rwx-controlled-remote-concurrent-selassie-run-001    Complete   1/1           12m        14m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=1534fa9c-77ea-43a5-8845-e8b5f251a000
job.batch/mayastor-rwx-controlled-remote-single-dauwalter-run-001       Complete   1/1           41m        95m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=18379268-1dc4-4eaa-8824-4e6f59ddfa83
job.batch/mayastor-rwx-controlled-remote-single-selassie-run-001        Complete   1/1           39m        53m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=af022cfd-7f8f-4c43-9c60-e0f6a784fe12

NAME                                                 READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES                                   SELECTOR
deployment.apps/mayastor-rwx-controlled-nfs-server   1/1     1            1           152m   nfs-server   itsthenetwork/nfs-server-alpine:latest   app=mayastor-rwx-controlled-nfs-server

NAME                                         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE    SELECTOR
service/mayastor-rwx-controlled-nfs-server   ClusterIP   10.43.143.86   <none>        2049/TCP   152m   app=mayastor-rwx-controlled-nfs-server

NAME                                                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                         VOLUMEATTRIBUTESCLASS   AGE    VOLUMEMODE
persistentvolumeclaim/mayastor-rwx-controlled-nfs-backend-pvc-run-001   Bound    pvc-d8a3f540-52c3-4267-9a52-fe62d23876af   20Gi       RWO            mayastor-rwx-controlled-backend-3r   <unset>                 152m   Filesystem
persistentvolumeclaim/mayastor-rwx-controlled-pvc-run-001               Bound    pvc-775578f3-0295-474a-b7f7-381071c5d803   20Gi       RWX            mayastor-rwx-controlled-nfs-csi      <unset>                 95m    Filesystem

## Fio pod node proof
NAME                                                              READY   STATUS      RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
mayastor-rwx-controlled-remote-concurrent-dauwalter-run-00vwlbc   0/1     Completed   0          14m   10.42.0.170   dauwalter   <none>           <none>
mayastor-rwx-controlled-remote-concurrent-selassie-run-001q74wn   0/1     Completed   0          14m   10.42.2.202   selassie    <none>           <none>
mayastor-rwx-controlled-remote-single-dauwalter-run-001-9vmwh     0/1     Completed   0          95m   10.42.0.169   dauwalter   <none>           <none>
mayastor-rwx-controlled-remote-single-selassie-run-001-62926      0/1     Completed   0          53m   10.42.2.201   selassie    <none>           <none>

## NFS server placement proof
NAME                                                 READY   STATUS    RESTARTS   AGE    IP            NODE      NOMINATED NODE   READINESS GATES
mayastor-rwx-controlled-nfs-server-f458cbd84-4c7n2   1/1     Running   0          152m   10.42.3.151   fordyce   <none>           <none>

## NFS CSI controller resources
NAME                                     READY   STATUS    RESTARTS   AGE    IP              NODE        NOMINATED NODE   READINESS GATES
pod/csi-nfs-controller-85d8db7f8-nkpwx   5/5     Running   0          152m   192.168.1.101   kipsang     <none>           <none>
pod/csi-nfs-node-b8qfd                   3/3     Running   0          152m   192.168.1.102   fordyce     <none>           <none>
pod/csi-nfs-node-fgd2r                   3/3     Running   0          152m   192.168.1.104   selassie    <none>           <none>
pod/csi-nfs-node-mrzrz                   3/3     Running   0          152m   192.168.1.100   dauwalter   <none>           <none>
pod/csi-nfs-node-pfh89                   3/3     Running   0          152m   192.168.1.101   kipsang     <none>           <none>
pod/csi-nfs-node-s5464                   3/3     Running   0          152m   192.168.1.103   walmsley    <none>           <none>

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS                                                       IMAGES                                                                                                                                                                                                                                                 SELECTOR
deployment.apps/csi-nfs-controller   1/1     1            1           152m   csi-provisioner,csi-resizer,csi-snapshotter,liveness-probe,nfs   registry.k8s.io/sig-storage/csi-provisioner:v6.1.0,registry.k8s.io/sig-storage/csi-resizer:v2.0.0,registry.k8s.io/sig-storage/csi-snapshotter:v8.4.0,registry.k8s.io/sig-storage/livenessprobe:v2.17.0,registry.k8s.io/sig-storage/nfsplugin:v4.13.3   app=csi-nfs-controller

NAME                          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE    CONTAINERS                                 IMAGES                                                                                                                                                          SELECTOR
daemonset.apps/csi-nfs-node   5         5         5       5            5           kubernetes.io/os=linux   152m   liveness-probe,node-driver-registrar,nfs   registry.k8s.io/sig-storage/livenessprobe:v2.17.0,registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.15.0,registry.k8s.io/sig-storage/nfsplugin:v4.13.3   app=csi-nfs-node

## Mayastor DiskPools and volumes
error: the server doesn't have a resource type "mayastorvolumes"

## Mayastor DaemonSets
NAME                    DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                                                                      AGE    CONTAINERS                             IMAGES                                                                                                       SELECTOR
openebs-agent-ha-node   3         3         3       3            3           kubernetes.io/arch=amd64,openebs.io/csi-node=mayastor,openebs.io/engine=mayastor   152m   agent-ha-node                          docker.io/openebs/mayastor-agent-ha-node:v2.11.1                                                             app=agent-ha-node,openebs.io/release=openebs
openebs-csi-node        3         3         3       3            3           kubernetes.io/arch=amd64,openebs.io/csi-node=mayastor,openebs.io/engine=mayastor   152m   csi-node,csi-driver-registrar          docker.io/openebs/mayastor-csi-node:v2.11.1,registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.13.0    app=csi-node,openebs.io/release=openebs
openebs-io-engine       3         3         3       3            3           kubernetes.io/arch=amd64,openebs.io/engine=mayastor                                152m   io-engine,metrics-exporter-io-engine   docker.io/openebs/mayastor-io-engine:v2.11.1,docker.io/openebs/mayastor-metrics-exporter-io-engine:v2.11.1   app=io-engine,openebs.io/release=openebs

## Mayastor pods
NAME                                         READY   STATUS    RESTARTS   AGE    IP              NODE        NOMINATED NODE   READINESS GATES
openebs-agent-core-594c64dd9-p5bdq           2/2     Running   0          152m   10.42.4.158     walmsley    <none>           <none>
openebs-agent-ha-node-2zwjr                  1/1     Running   0          98m    192.168.1.104   selassie    <none>           <none>
openebs-agent-ha-node-cgpt2                  1/1     Running   0          98m    192.168.1.102   fordyce     <none>           <none>
openebs-agent-ha-node-vmbcf                  1/1     Running   0          98m    192.168.1.100   dauwalter   <none>           <none>
openebs-api-rest-68f49d874-vrtrm             1/1     Running   0          152m   10.42.1.62      kipsang     <none>           <none>
openebs-csi-controller-5cbb6cd9df-rp7w2      6/6     Running   0          152m   192.168.1.101   kipsang     <none>           <none>
openebs-csi-node-gnd4p                       2/2     Running   0          98m    192.168.1.102   fordyce     <none>           <none>
openebs-csi-node-ltqbl                       2/2     Running   0          98m    192.168.1.104   selassie    <none>           <none>
openebs-csi-node-xrq8g                       2/2     Running   0          98m    192.168.1.100   dauwalter   <none>           <none>
openebs-etcd-0                               1/1     Running   0          96m    10.42.1.69      kipsang     <none>           <none>
openebs-etcd-1                               1/1     Running   0          97m    10.42.4.167     walmsley    <none>           <none>
openebs-etcd-2                               1/1     Running   0          98m    10.42.4.166     walmsley    <none>           <none>
openebs-io-engine-9gdgf                      2/2     Running   0          98m    192.168.1.100   dauwalter   <none>           <none>
openebs-io-engine-fkgp5                      2/2     Running   0          98m    192.168.1.102   fordyce     <none>           <none>
openebs-io-engine-gz2dn                      2/2     Running   0          98m    192.168.1.104   selassie    <none>           <none>
openebs-nats-0                               3/3     Running   0          140m   10.42.2.199     selassie    <none>           <none>
openebs-nats-1                               3/3     Running   0          140m   10.42.3.150     fordyce     <none>           <none>
openebs-nats-2                               3/3     Running   0          140m   10.42.0.167     dauwalter   <none>           <none>
openebs-operator-diskpool-6f7f4d9985-rbg6j   1/1     Running   0          152m   10.42.1.63      kipsang     <none>           <none>

## CSI node topology
dauwalter	io.openebs.csi-mayastor openebs.io/csi-node,openebs.io/engine,openebs.io/nodename
fordyce	io.openebs.csi-mayastor openebs.io/csi-node,openebs.io/engine,openebs.io/nodename
kipsang	
selassie	io.openebs.csi-mayastor openebs.io/csi-node,openebs.io/engine,openebs.io/nodename
walmsley	

## Node taints after run
["dauwalter",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-04T12:51:20Z"}]]
["fordyce",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-04T12:51:20Z"}]]
["kipsang",[]]
["selassie",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-04T12:51:20Z"}]]
["walmsley",[]]
