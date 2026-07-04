# Controlled RWX Storage Benchmark Placement Audit

## Placement contract

- Serving/active node: `fordyce`
- fio client nodes: `dauwalter`, `selassie`
- excluded from this benchmark: `walmsley`, `kipsang`
- no fio client on `fordyce`

## Backend placement evidence

| Backend | Serving/active evidence | fio client evidence | Validity |
| --- | --- | --- | --- |
| Longhorn RWX | PV `pvc-28d642c9-5b7e-4d22-934f-4f549ab98c34` share-manager pod on `fordyce`; Volume YAML contains `currentNodeID: fordyce`. | 4 fio pods on `dauwalter`, `selassie`. | Valid |
| Piraeus/LINSTOR RWX | Serving anchor pod on `fordyce`; LINSTOR resource `pvc-494b412e-d23f-44c5-8996-caff4a09ec4c` is `InUse` on `fordyce`. | 4 fio pods on `dauwalter`, `selassie`. | Valid |
| Mayastor-backed RWX via NFS/NFS CSI | NFS server pod on `fordyce`. | 4 fio pods on `dauwalter`, `selassie`. | Valid |

## Read/cache note

These results control serving/client locality. They are not cache-cold results unless a separate artifact documents an approved cache-flush runbook.
