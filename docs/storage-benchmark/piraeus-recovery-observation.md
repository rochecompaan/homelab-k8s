# Piraeus recovery observation

Observation node: dauwalter
Started: 2026-06-24T08:31:57Z

## Pre-reboot context

- User manually rebooted `dauwalter` for the Piraeus/LINSTOR recovery observation.
- `selassie` was explicitly excluded because it is an important Garage node.

## Outcome

- `dauwalter` was observed as `Ready=Unknown` at `2026-06-24T08:31:57Z`.
- LINSTOR reported the `dauwalter` satellite `OFFLINE` by `2026-06-24T08:32:58Z` while `fordyce` and `selassie` remained `Online`.
- `dauwalter` returned `Ready=True` by `2026-06-24T08:33:30Z` and LINSTOR reported it `Online` by `2026-06-24T08:34:01Z`.
- The Piraeus benchmark volume `pvc-fac962ee-369f-46d4-a67a-645feed28492` recovered to three `UpToDate` replicas with `Established(2)` replication.
- CNPG clusters stayed `3/3` ready with primaries off `dauwalter` throughout the sampled observations.
- Final state had `dauwalter` Ready, all LINSTOR satellites Online, the benchmark PVC Bound, the run-002 Job Complete, and problem pods `none`.

## Observation 1 — 2026-06-24T08:31:57Z

- dauwalter Ready: Unknown
- dauwalter unschedulable: false
- problem pods: 0
- CNPG: matrix/matrix-whatsapp-postgres=3/3 primary=matrix-whatsapp-postgres-7; monitoring/grafana-postgres=3/3 primary=grafana-postgres-2; nextcloud/postgres=3/3 primary=postgres-7
- LINSTOR nodes: 
- benchmark resources: PVC/piraeus-fio-pvc-run-002=Bound; Job/storage-bench-piraeus-run-002=a0s1f0; Pod/storage-bench-piraeus-run-002-svpn6=Succeeded@fordyce

### LINSTOR resource volumes

```text
(resource list unavailable or empty)
```

## Observation 2 — 2026-06-24T08:32:28Z

- dauwalter Ready: Unknown
- dauwalter unschedulable: false
- problem pods: 1
- CNPG: matrix/matrix-whatsapp-postgres=3/3 primary=matrix-whatsapp-postgres-7; monitoring/grafana-postgres=3/3 primary=grafana-postgres-2; nextcloud/postgres=3/3 primary=postgres-7
- LINSTOR nodes: 
- benchmark resources: PVC/piraeus-fio-pvc-run-002=Bound; Job/storage-bench-piraeus-run-002=a0s1f0; Pod/storage-bench-piraeus-run-002-svpn6=Succeeded@fordyce

### LINSTOR resource volumes

```text
(resource list unavailable or empty)
```

## Observation 3 — 2026-06-24T08:32:58Z

- dauwalter Ready: Unknown
- dauwalter unschedulable: false
- problem pods: 0
- CNPG: matrix/matrix-whatsapp-postgres=3/3 primary=matrix-whatsapp-postgres-7; monitoring/grafana-postgres=3/3 primary=grafana-postgres-2; nextcloud/postgres=3/3 primary=postgres-7
- LINSTOR nodes: dauwalter|SATELLITE|10.42.0.83:3366 (PLAIN)|OFFLINE;fordyce|SATELLITE|10.42.3.50:3366 (PLAIN)|Online  selassie|SATELLITE|10.42.2.41:3366 (PLAIN)|Online 
- benchmark resources: PVC/piraeus-fio-pvc-run-002=Bound; Job/storage-bench-piraeus-run-002=a0s1f0; Pod/storage-bench-piraeus-run-002-svpn6=Succeeded@fordyce

### LINSTOR resource volumes

```text
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | dauwalter | linstor-bench |     0 |    1001 | None          |           |        |  Unknown |                |
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | fordyce   | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.23 GiB | Unused | UpToDate | Established(1) |
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | selassie  | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(1) |
```

## Observation 4 — 2026-06-24T08:33:30Z

- dauwalter Ready: True
- dauwalter unschedulable: false
- problem pods: 2
- CNPG: matrix/matrix-whatsapp-postgres=3/3 primary=matrix-whatsapp-postgres-7; monitoring/grafana-postgres=3/3 primary=grafana-postgres-2; nextcloud/postgres=3/3 primary=postgres-7
- LINSTOR nodes: dauwalter|SATELLITE|10.42.0.118:3366 (PLAIN)|Connected;fordyce|SATELLITE|10.42.3.50:3366 (PLAIN)|Online    selassie|SATELLITE|10.42.2.41:3366 (PLAIN)|Online   
- benchmark resources: PVC/piraeus-fio-pvc-run-002=Bound; Job/storage-bench-piraeus-run-002=a0s1f0; Pod/storage-bench-piraeus-run-002-svpn6=Succeeded@fordyce

### LINSTOR resource volumes

```text
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | dauwalter | linstor-bench |     0 |    1001 | None          |           |        |  Unknown |                |
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | fordyce   | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.23 GiB | Unused | UpToDate | Established(1) |
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | selassie  | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(1) |
```

## Observation 5 — 2026-06-24T08:34:01Z

- dauwalter Ready: True
- dauwalter unschedulable: false
- problem pods: 0
- CNPG: matrix/matrix-whatsapp-postgres=3/3 primary=matrix-whatsapp-postgres-7; monitoring/grafana-postgres=3/3 primary=grafana-postgres-2; nextcloud/postgres=3/3 primary=postgres-7
- LINSTOR nodes: dauwalter|SATELLITE|10.42.0.118:3366 (PLAIN)|Online;fordyce|SATELLITE|10.42.3.50:3366 (PLAIN)|Online selassie|SATELLITE|10.42.2.41:3366 (PLAIN)|Online
- benchmark resources: PVC/piraeus-fio-pvc-run-002=Bound; Job/storage-bench-piraeus-run-002=a0s1f0; Pod/storage-bench-piraeus-run-002-svpn6=Succeeded@fordyce

### LINSTOR resource volumes

```text
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | dauwalter | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(2) |
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | fordyce   | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.23 GiB | Unused | UpToDate | Established(2) |
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | selassie  | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(2) |
```

## Observation 6 — 2026-06-24T08:34:32Z

- dauwalter Ready: True
- dauwalter unschedulable: false
- problem pods: 0
- CNPG: matrix/matrix-whatsapp-postgres=3/3 primary=matrix-whatsapp-postgres-7; monitoring/grafana-postgres=3/3 primary=grafana-postgres-2; nextcloud/postgres=3/3 primary=postgres-7
- LINSTOR nodes: dauwalter|SATELLITE|10.42.0.118:3366 (PLAIN)|Online;fordyce|SATELLITE|10.42.3.50:3366 (PLAIN)|Online selassie|SATELLITE|10.42.2.41:3366 (PLAIN)|Online
- benchmark resources: PVC/piraeus-fio-pvc-run-002=Bound; Job/storage-bench-piraeus-run-002=a0s1f0; Pod/storage-bench-piraeus-run-002-svpn6=Succeeded@fordyce

### LINSTOR resource volumes

```text
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | dauwalter | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(2) |
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | fordyce   | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.23 GiB | Unused | UpToDate | Established(2) |
    | pvc-fac962ee-369f-46d4-a67a-645feed28492 | selassie  | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(2) |
```

## Final snapshot

```text
NAME        STATUS   ROLES                AGE    VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE               KERNEL-VERSION   CONTAINER-RUNTIME
dauwalter   Ready    control-plane,etcd   3d1h   v1.35.5+k3s1   192.168.1.100   <none>        NixOS 26.05 (Yarara)   6.18.35          containerd://2.2.3-k3s1

+-----------------------------------------------------------+
| Node      | NodeType  | Addresses                | State  |
|===========================================================|
| dauwalter | SATELLITE | 10.42.0.118:3366 (PLAIN) | Online |
| fordyce   | SATELLITE | 10.42.3.50:3366 (PLAIN)  | Online |
| selassie  | SATELLITE | 10.42.2.41:3366 (PLAIN)  | Online |
+-----------------------------------------------------------+

+---------------------------------------------------------------------------------------------------------------------------------------------------------+
| Resource                                 | Node      | StoragePool   | VolNr | MinorNr | DeviceName    | Allocated | InUse  |    State | Repl           |
|=========================================================================================================================================================|
| pvc-fac962ee-369f-46d4-a67a-645feed28492 | dauwalter | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(2) |
| pvc-fac962ee-369f-46d4-a67a-645feed28492 | fordyce   | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.23 GiB | Unused | UpToDate | Established(2) |
| pvc-fac962ee-369f-46d4-a67a-645feed28492 | selassie  | linstor-bench |     0 |    1001 | /dev/drbd1001 |  4.20 GiB | Unused | UpToDate | Established(2) |
+---------------------------------------------------------------------------------------------------------------------------------------------------------+

NAME                                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS       VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/piraeus-fio-pvc-run-002   Bound    pvc-fac962ee-369f-46d4-a67a-645feed28492   10Gi       RWO            piraeus-bench-3r   <unset>                 55m   Filesystem

NAME                                      STATUS     COMPLETIONS   DURATION   AGE   CONTAINERS   IMAGES                              SELECTOR
job.batch/storage-bench-piraeus-run-002   Complete   1/1           22m        55m   fio          nixery.dev/shell/fio/jq/coreutils   batch.kubernetes.io/controller-uid=b49e9eeb-f31e-45ad-9393-edfe67eb3b63

NAME                                      READY   STATUS      RESTARTS   AGE   IP           NODE      NOMINATED NODE   READINESS GATES
pod/storage-bench-piraeus-run-002-svpn6   0/1     Completed   0          55m   10.42.3.63   fordyce   <none>           <none>

problem pods: none
```
