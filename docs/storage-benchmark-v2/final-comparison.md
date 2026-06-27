# Storage Benchmark v2 Final Comparison

## Scope

- Performance-only trial
- Fixed fio consumer node: `fordyce`
- Backends: existing `local-path`, 3-replica Mayastor, 3-replica LINSTOR/Piraeus
- PVC size: 20 GiB
- fio file size: 16 GiB
- passes: 5 per profile

## Performance Summary

| backend | profile | passes | read_iops_avg | write_iops_avg | read_mib_s_avg | write_mib_s_avg | read_p99_ms_avg | write_p99_ms_avg | read_p999_ms_avg | write_p999_ms_avg | errors_total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| local-path | rand-read-4k | 5 | 65250.04 | 0.00 | 254.88 | 0.00 | 0.43 | 0.00 | 1.21 | 0.00 | 0 |
| local-path | rand-write-4k | 5 | 0.00 | 96366.74 | 0.00 | 376.43 | 0.00 | 1.38 | 0.00 | 3.77 | 0 |
| local-path | randrw-4k-70r30w | 5 | 44549.07 | 19093.25 | 174.02 | 74.58 | 1.11 | 0.37 | 2.08 | 1.24 | 0 |
| local-path | seq-read-1m | 5 | 2924.58 | 0.00 | 2924.83 | 0.00 | 9.73 | 0.00 | 13.71 | 0.00 | 0 |
| local-path | seq-write-1m | 5 | 0.00 | 860.28 | 0.00 | 860.53 | 0.00 | 286.47 | 0.00 | 492.41 | 0 |
| local-path | sync-write-4k | 5 | 0.00 | 55207.73 | 0.00 | 215.66 | 0.00 | 0.06 | 0.00 | 0.57 | 0 |
| mayastor | rand-read-4k | 5 | 73629.00 | 0.00 | 287.61 | 0.00 | 1.17 | 0.00 | 3.55 | 0.00 | 0 |
| mayastor | rand-write-4k | 5 | 0.00 | 12495.31 | 0.00 | 48.81 | 0.00 | 4.63 | 0.00 | 6.63 | 0 |
| mayastor | randrw-4k-70r30w | 5 | 21846.94 | 9371.90 | 85.34 | 36.61 | 2.55 | 4.19 | 4.99 | 6.64 | 0 |
| mayastor | seq-read-1m | 5 | 365.17 | 0.00 | 365.43 | 0.00 | 130.34 | 0.00 | 141.98 | 0.00 | 0 |
| mayastor | seq-write-1m | 5 | 0.00 | 55.49 | 0.00 | 55.76 | 0.00 | 331.77 | 0.00 | 341.84 | 0 |
| mayastor | sync-write-4k | 5 | 0.00 | 1008.67 | 0.00 | 3.94 | 0.00 | 3.60 | 0.00 | 5.71 | 0 |
| piraeus | rand-read-4k | 5 | 229640.23 | 0.00 | 897.03 | 0.00 | 0.31 | 0.00 | 1.02 | 0.00 | 0 |
| piraeus | rand-write-4k | 5 | 0.00 | 1053.73 | 0.00 | 4.12 | 0.00 | 58.41 | 0.00 | 76.91 | 0 |
| piraeus | randrw-4k-70r30w | 5 | 1902.49 | 814.77 | 7.43 | 3.18 | 3.10 | 65.12 | 6.06 | 91.54 | 0 |
| piraeus | seq-read-1m | 5 | 5403.14 | 0.00 | 5403.40 | 0.00 | 7.95 | 0.00 | 9.97 | 0.00 | 0 |
| piraeus | seq-write-1m | 5 | 0.00 | 53.29 | 0.00 | 53.54 | 0.00 | 500.38 | 0.00 | 614.47 | 0 |
| piraeus | sync-write-4k | 5 | 0.00 | 279.08 | 0.00 | 1.09 | 0.00 | 7.10 | 0.00 | 10.71 | 0 |

## Plain-English Findings

- `local-path` is the local-node ceiling for writes: fastest sequential write, random write, mixed write, and single-depth 4 KiB writes. It is not replicated.
- Mayastor is the stronger replicated write backend. It beat Piraeus on random write, mixed write, and single-depth 4 KiB write, and was roughly tied on sequential write.
- Piraeus is the stronger replicated read backend. It had the best sequential read and random read numbers in v2.
- Piraeus write latency is the main concern: random-write p99 averaged 58.41 ms and mixed-write p99 averaged 65.12 ms, much higher than Mayastor.
- Mayastor read latency is the main Mayastor concern: sequential-read p99 averaged 130.34 ms.

## Validation Against v1

Compared with:

- `docs/storage-benchmark/mayastor-run-001-summary.md`
- `docs/storage-benchmark/piraeus-run-002-summary.md`

The surprising Mayastor write advantage repeated.

- Sequential 1 MiB writes stayed effectively tied: Mayastor was 55.76 MiB/s in both v1 and v2; Piraeus was 53.67 MiB/s in v1 and 53.54 MiB/s in v2.
- Random 4 KiB writes widened in Mayastor's favor: Mayastor was 47.08 MiB/s in v1 and 48.81 MiB/s in v2; Piraeus was 20.73 MiB/s in v1 and 4.12 MiB/s in v2.
- Mixed 70/30 4 KiB writes also widened in Mayastor's favor: Mayastor write throughput was 28.00 MiB/s in v1 and 36.61 MiB/s in v2; Piraeus was 23.56 MiB/s in v1 and 3.18 MiB/s in v2.
- Single-depth 4 KiB writes repeated the same pattern: Mayastor was 3.77 MiB/s in v1 and 3.94 MiB/s in v2; Piraeus was 1.27 MiB/s in v1 and 1.09 MiB/s in v2.

So the result did not reverse. It narrowed only for sequential writes; for random, mixed, and single-depth writes it repeated and widened.

## local-path Reference

`local-path` is a non-replicated local-node baseline. It shows what `fordyce` can do without network replication, quorum, or distributed-volume overhead. It is useful as a ceiling/reference, not as an HA app-state candidate.

## Recommendation

Proceed with one non-critical app trial on Mayastor.

Mayastor is the better next trial because v2 confirmed the replicated-write pattern that matters most for many stateful app workloads. Keep the trial non-critical: Mayastor still had an operational wrinkle from reused pool metadata, and production migration still needs the gates below.

Do not pick LINSTOR/Piraeus for the first write-sensitive app-state trial from these results. Its read performance is excellent, but v2 write throughput and write tail latency were much weaker.

## Remaining Gates Before Production App-State Migration

- monitoring and alerting
- documented restore path
- non-critical app migration trial
- rollback instructions
- cleanup rehearsal
