#!/usr/bin/env python3
"""Regression checks for provisioned Grafana alert definitions."""

from __future__ import annotations

from pathlib import Path


LOG_ERRORS = Path("argocd/homelab/grafana-dashboards/alert-log-errors.yaml")
NOTIFICATIONS = Path("argocd/homelab/grafana-dashboards/grafana-alert-notifications.yaml")


def test_log_errors_alert_groups_by_message() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert "| stats by (_msg) count()" in content
    assert "homelab_log_errors" in content


def test_log_errors_alert_excludes_synapse_preview_404_noise() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert "media/preview_url.*SynapseError: 404 - Unrecognized request" in content
    assert "404 .*GET /_matrix/client/v1/media/preview_url" in content


def test_log_errors_alert_excludes_grafana_provisioning_file_noise() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert "Applying resource ConfigMap/alert-log-errors" in content
    assert "Writing /etc/grafana/provisioning/alerting/log-errors" in content


def test_matrix_notification_message_uses_log_message_template() -> None:
    content = NOTIFICATIONS.read_text(encoding="utf-8")

    assert '{{ template "default.message" . }}' not in content
    assert '<font color="#D50000"><b>🚨 Firing</b></font>' in content
    assert '<font color="#00C853"><b>✅ Resolved</b></font>' in content
    assert "{{ if .Labels._msg }}" in content
    assert "Error: {{ .Labels._msg }}" in content


def main() -> None:
    tests = [
        test_log_errors_alert_groups_by_message,
        test_log_errors_alert_excludes_synapse_preview_404_noise,
        test_log_errors_alert_excludes_grafana_provisioning_file_noise,
        test_matrix_notification_message_uses_log_message_template,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")


if __name__ == "__main__":
    main()
