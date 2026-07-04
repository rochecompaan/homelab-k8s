# Controlled RWX Storage Benchmark Results

This directory stores the placement-controlled RWX benchmark rerun.

Placement contract:

- serving/active node: `fordyce`
- fio clients: `dauwalter`, `selassie`
- excluded from this benchmark: `walmsley`, `kipsang`
- no fio client may run on `fordyce`

Backends:

- Longhorn RWX
- Piraeus/LINSTOR RWX
- Mayastor-backed RWX via NFS/NFS CSI

Expected result row counts:

- `72` `RESULT,` rows per backend
- `216` `RESULT,` rows across all three backends

Activation order:

1. Longhorn controlled app only.
2. Remove Longhorn controlled app after capture.
3. Piraeus operator app plus Piraeus controlled app.
4. Remove Piraeus controlled app, then remove Piraeus operator app after cleanup verification.
5. OpenEBS Mayastor app plus controlled NFS CSI app plus Mayastor controlled app.
6. Remove Mayastor controlled app, then controlled NFS CSI app, then OpenEBS Mayastor app after cleanup verification.

Read results are placement-controlled remote-client results. They are not
cache-cold results unless a later artifact explicitly documents an approved
cache-flush runbook.
