#!/usr/bin/env python3
"""Regression checks for provisioned Grafana alert definitions."""

from __future__ import annotations

from pathlib import Path


LOG_ERRORS = Path("argocd/homelab/grafana-dashboards/alert-log-errors.yaml")


def test_log_errors_alert_has_low_cardinality_query() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert "stats by (_msg)" not in content
    assert "| stats count()" in content
    assert "homelab_log_errors" in content


def main() -> None:
    tests = [test_log_errors_alert_has_low_cardinality_query]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")


if __name__ == "__main__":
    main()
