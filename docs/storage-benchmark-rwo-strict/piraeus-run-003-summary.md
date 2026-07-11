# Piraeus strict RWO run 003 summary

| Backend | Profile | Passes | Read MiB/s | Read IOPS | Read p95 ms | Read p99 ms | Read p999 ms | Errors |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| piraeus-rwo-strict-dauwalter | rand-read-4k | 5 | 333.64 | 85412.17 | 0.24 | 0.31 | 1.37 | 0 |
| piraeus-rwo-strict-dauwalter | seq-read-1m | 5 | 2185.14 | 2184.89 | 24.67 | 25.81 | 35.63 | 0 |
| piraeus-rwo-strict-selassie | rand-read-4k | 5 | 385.73 | 98747.09 | 0.28 | 0.39 | 1.26 | 0 |
| piraeus-rwo-strict-selassie | seq-read-1m | 5 | 1746.43 | 1746.17 | 16.42 | 18.52 | 20.89 | 0 |

## Notes

- Writer node: `fordyce`; reader nodes: `dauwalter`, `selassie`.
- LINSTOR health evidence in `piraeus-run-003-health.md` shows all three resources `UpToDate` after writer and readers, with no `SkipDisk` entries.
