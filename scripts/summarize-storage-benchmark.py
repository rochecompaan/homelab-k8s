#!/usr/bin/env python3
"""Summarize storage benchmark RESULT lines as markdown."""

from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from dataclasses import dataclass
from typing import Iterable, TextIO


FIELDS = (
    "marker",
    "backend",
    "profile",
    "pass",
    "read_iops",
    "write_iops",
    "read_mib_s",
    "write_mib_s",
    "read_mean_ms",
    "write_mean_ms",
    "read_p95_ms",
    "write_p95_ms",
    "read_p99_ms",
    "write_p99_ms",
    "read_p999_ms",
    "write_p999_ms",
    "errors",
)

AVERAGE_FIELDS = (
    "read_iops",
    "write_iops",
    "read_mib_s",
    "write_mib_s",
    "read_p99_ms",
    "write_p99_ms",
    "read_p999_ms",
    "write_p999_ms",
)

TABLE_COLUMNS = (
    "backend",
    "profile",
    "passes",
    "read_iops_avg",
    "write_iops_avg",
    "read_mib_s_avg",
    "write_mib_s_avg",
    "read_p99_ms_avg",
    "write_p99_ms_avg",
    "read_p999_ms_avg",
    "write_p999_ms_avg",
    "errors_total",
)


@dataclass(frozen=True)
class ResultRow:
    backend: str
    profile: str
    pass_number: str
    read_iops: float
    write_iops: float
    read_mib_s: float
    write_mib_s: float
    read_mean_ms: float
    write_mean_ms: float
    read_p95_ms: float
    write_p95_ms: float
    read_p99_ms: float
    write_p99_ms: float
    read_p999_ms: float
    write_p999_ms: float
    errors: int


def _parse_result_fields(fields: list[str], line_number: int | None = None) -> ResultRow:
    if len(fields) != len(FIELDS):
        location = f" on line {line_number}" if line_number is not None else ""
        raise ValueError(
            f"RESULT line{location} has wrong number of fields: "
            f"expected {len(FIELDS)}, got {len(fields)}"
        )

    row = dict(zip(FIELDS, fields, strict=True))
    return ResultRow(
        backend=row["backend"],
        profile=row["profile"],
        pass_number=row["pass"],
        read_iops=float(row["read_iops"]),
        write_iops=float(row["write_iops"]),
        read_mib_s=float(row["read_mib_s"]),
        write_mib_s=float(row["write_mib_s"]),
        read_mean_ms=float(row["read_mean_ms"]),
        write_mean_ms=float(row["write_mean_ms"]),
        read_p95_ms=float(row["read_p95_ms"]),
        write_p95_ms=float(row["write_p95_ms"]),
        read_p99_ms=float(row["read_p99_ms"]),
        write_p99_ms=float(row["write_p99_ms"]),
        read_p999_ms=float(row["read_p999_ms"]),
        write_p999_ms=float(row["write_p999_ms"]),
        errors=int(row["errors"]),
    )


def parse_result_lines(lines: Iterable[str]) -> list[ResultRow]:
    """Parse CSV RESULT lines from an iterable of log lines."""
    rows: list[ResultRow] = []
    for line_number, line in enumerate(lines, start=1):
        if not line.startswith("RESULT,"):
            continue
        parsed = next(csv.reader([line.rstrip("\n")]))
        rows.append(_parse_result_fields(parsed, line_number))
    return rows


def parse_result_files(paths: Iterable[str]) -> list[ResultRow]:
    rows: list[ResultRow] = []
    for path in paths:
        with open(path, "r", encoding="utf-8", newline="") as handle:
            rows.extend(parse_result_lines(handle))
    return rows


def render_markdown_table(rows: Iterable[ResultRow]) -> str:
    groups: dict[tuple[str, str], list[ResultRow]] = defaultdict(list)
    for row in rows:
        groups[(row.backend, row.profile)].append(row)

    lines = [
        "| " + " | ".join(TABLE_COLUMNS) + " |",
        "| " + " | ".join("---" for _ in TABLE_COLUMNS) + " |",
    ]

    for backend, profile in sorted(groups):
        group = groups[(backend, profile)]
        values = [backend, profile, str(len(group))]
        for field in AVERAGE_FIELDS:
            total = sum(getattr(row, field) for row in group)
            values.append(f"{total / len(group):.2f}")
        values.append(str(sum(row.errors for row in group)))
        lines.append("| " + " | ".join(values) + " |")

    return "\n".join(lines)


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Summarize storage benchmark RESULT lines from log files."
    )
    parser.add_argument("log_files", nargs="+", help="log file(s) to summarize")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None, stdout: TextIO = sys.stdout, stderr: TextIO = sys.stderr) -> int:
    args = _parse_args(sys.argv[1:] if argv is None else argv)
    try:
        rows = parse_result_files(args.log_files)
    except (OSError, ValueError) as error:
        print(error, file=stderr)
        return 1

    if not rows:
        print("no RESULT lines found", file=stderr)
        return 1

    print(render_markdown_table(rows), file=stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
