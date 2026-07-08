# Strict-placement RWO Storage Benchmark

This directory contains artifacts for the replicated RWO read-after-write benchmark.

## Methodology

- Backends: Piraeus/LINSTOR RWO, Longhorn NVMe RWO, and Mayastor RWO.
- Writer node: `fordyce`.
- Reader nodes: `dauwalter` and `selassie`.
- Writer phase: a dedicated writer Job fully writes `/volume/fio-test-file` with `fio --direct=1`, `--rw=write`, `--bs=1m`, and `--size=16G`.
- Reader phase: dedicated reader Jobs run only `seq-read-1m` and `rand-read-4k`.
- Locality is allowed. A reader node with a local or up-to-date replica/resource remains valid and must be documented.
- These results are not cold remote/no-replica reads.

## Artifact naming

- Raw logs: `piraeus-writer-fordyce-run-001.log`, `longhorn-nvme-reader-dauwalter-run-001.log`, and `mayastor-reader-selassie-run-001.log` show the naming pattern.
- Health and placement evidence: `piraeus-run-001-health.md`, `longhorn-nvme-run-001-health.md`, and `mayastor-run-001-health.md`.
- Per-backend summaries: `piraeus-run-001-summary.md`, `longhorn-nvme-run-001-summary.md`, and `mayastor-run-001-summary.md`.
- Cross-backend placement audit: `placement-audit.md`.
- Final comparison: `final-comparison.md`.

Use `runbook.md` for the GitOps activation, evidence capture, summary, and cleanup procedure.
