# Superseded Piraeus strict RWO run 001 summary

This run is retained as historical evidence only. It is superseded by `piraeus-run-003-summary.md` because LINSTOR reported `Diskless, SkipDisk (R)` for the `dauwalter` resource during run 001.

| backend | profile | passes | read_iops_avg | write_iops_avg | read_mib_s_avg | write_mib_s_avg | read_p99_ms_avg | write_p99_ms_avg | read_p999_ms_avg | write_p999_ms_avg | errors_total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| piraeus-rwo-strict-dauwalter | rand-read-4k | 5 | 22587.37 | 0.00 | 88.23 | 0.00 | 2.14 | 0.00 | 3.77 | 0.00 | 0 |
| piraeus-rwo-strict-dauwalter | seq-read-1m | 5 | 107.62 | 0.00 | 107.87 | 0.00 | 199.44 | 0.00 | 232.57 | 0.00 | 0 |
| piraeus-rwo-strict-selassie | rand-read-4k | 5 | 99121.98 | 0.00 | 387.20 | 0.00 | 0.39 | 0.00 | 1.25 | 0.00 | 0 |
| piraeus-rwo-strict-selassie | seq-read-1m | 5 | 1742.12 | 0.00 | 1742.37 | 0.00 | 18.69 | 0.00 | 22.52 | 0.00 | 0 |
