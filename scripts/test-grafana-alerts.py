#!/usr/bin/env python3
"""Regression checks for provisioned Grafana alert definitions."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path


GRAFANA_DASHBOARDS = Path("argocd/homelab/grafana-dashboards")
LOG_ERRORS = GRAFANA_DASHBOARDS / "alert-log-errors.yaml"
NOTIFICATIONS = GRAFANA_DASHBOARDS / "grafana-alert-notifications.yaml"


def test_log_errors_alert_groups_by_message() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert "| stats by (_msg) count()" in content
    assert "homelab_log_errors" in content


def test_log_errors_alert_trusts_structured_severity_before_message_fallback() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert 'log.level:* AND log.level:~"(?i)^(error|fatal|panic)$"' in content
    assert (
        'log.record.error_severity:* AND log.record.error_severity:~"(?i)^(error|fatal|panic)$"'
        in content
    )
    assert "NOT log.level:* AND NOT log.record.error_severity:*" in content
    assert '_msg:~"(?i)(^| )level=(error|fatal|panic)( |$)"' in content
    assert 'NOT _msg:~"(?i)(^| )level=(trace|debug|info|warn|warning)( |$)"' in content


def test_log_errors_alert_excludes_synapse_preview_404_noise() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert "media/preview_url.*SynapseError: 404 - Unrecognized request" in content
    assert "404 .*GET /_matrix/client/v1/media/preview_url" in content


def test_log_errors_alert_excludes_grafana_provisioning_file_noise() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert "Applying resource ConfigMap/alert-log-errors" in content
    assert "Writing /etc/grafana/provisioning/alerting/log-errors" in content


def _log_errors_exclusion_regex() -> re.Pattern[str]:
    content = LOG_ERRORS.read_text(encoding="utf-8")
    match = re.search(r'AND NOT ~"([^"]+)"', content)
    assert match is not None
    return re.compile(match.group(1).replace("''", "'"))


def test_log_errors_alert_excludes_transient_gmail_imap_noise() -> None:
    excluded = _log_errors_exclusion_regex()

    transient_messages = [
        "Error: Socket error on imap.gmail.com (108.177.15.109:993): timeout.",
        "Error: [ERROR] plugin/errors: 2 imap.gmail.com. AAAA: read udp 10.42.0.59:33113->192.168.1.1:53: i/o timeout",
        "Error: [ERROR] plugin/errors: 2 imap.gmail.com. AAAA: read udp 10.42.0.59:35171->192.168.1.1:53: i/o timeout",
        "Error: [ERROR] plugin/errors: 2 imap.gmail.com. AAAA: read udp 10.42.0.59:47097->192.168.1.1:53: i/o timeout",
        "Error: IMAP command 'UID FETCH 1:1653650 (UID FLAGS)' returned an error: Some messages could not be FETCHed (Failure)",
    ]

    for message in transient_messages:
        assert excluded.search(message), message


def test_matrix_notification_message_uses_log_message_template() -> None:
    content = NOTIFICATIONS.read_text(encoding="utf-8")

    assert '{{ template "default.message" . }}' not in content
    assert '<span data-mx-color="#D50000"><strong>🚨 Firing</strong></span>' in content
    assert '<span data-mx-color="#00C853"><strong>✅ Resolved</strong></span>' in content
    assert "{{ if .Labels._msg }}" in content
    assert "Error: {{ .Labels._msg }}" in content


def _kustomize_documents(path: Path) -> list[str]:
    result = subprocess.run(
        ["kubectl", "kustomize", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return [document for document in result.stdout.split("\n---\n") if document.strip()]


def _document_kind(document: str) -> str:
    match = re.search(r"(?m)^kind: (\S+)$", document)
    return match.group(1) if match else ""


def _metadata_name(document: str) -> str:
    match = re.search(r"(?m)^  name: ([^\n]+)$", document)
    return match.group(1) if match else ""


def test_matrix_webhook_configmap_changes_roll_deployment() -> None:
    documents = _kustomize_documents(GRAFANA_DASHBOARDS)
    webhook_configmaps = [
        _metadata_name(document)
        for document in documents
        if _document_kind(document) == "ConfigMap"
        and _metadata_name(document).startswith("grafana-matrix-webhook-")
    ]
    assert len(webhook_configmaps) == 1

    generated_name = webhook_configmaps[0]
    deployments = [
        document for document in documents if _document_kind(document) == "Deployment"
    ]
    assert any(f"          name: {generated_name}\n" in document for document in deployments)


def main() -> None:
    tests = [
        test_log_errors_alert_groups_by_message,
        test_log_errors_alert_trusts_structured_severity_before_message_fallback,
        test_log_errors_alert_excludes_synapse_preview_404_noise,
        test_log_errors_alert_excludes_grafana_provisioning_file_noise,
        test_log_errors_alert_excludes_transient_gmail_imap_noise,
        test_matrix_notification_message_uses_log_message_template,
        test_matrix_webhook_configmap_changes_roll_deployment,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")


if __name__ == "__main__":
    main()
