#!/usr/bin/env python3
"""Regression checks for provisioned Grafana alert definitions."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path


GRAFANA_DASHBOARDS = Path("argocd/homelab/grafana-dashboards")
LOG_ERRORS = GRAFANA_DASHBOARDS / "alert-log-errors.yaml"
NOTIFICATIONS = GRAFANA_DASHBOARDS / "grafana-alert-notifications.yaml"


def test_log_errors_alert_groups_by_normalized_fingerprint() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert "homelab_log_errors" in content
    assert "| copy _msg as error_fingerprint" in content
    assert "| collapse_nums at error_fingerprint" in content
    assert 'replace_regexp ("[a-f0-9]{8,}", "<hex>") at error_fingerprint' in content
    assert 'replace_regexp ("[a-z0-9-]+-[a-f0-9]{8,10}-[a-z0-9]{5}", "<pod>") at error_fingerprint' in content
    assert "| stats by (error_fingerprint) count() errors" in content
    assert "| stats by (_msg) count()" not in content


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


def _log_errors_threshold_value() -> int:
    content = LOG_ERRORS.read_text(encoding="utf-8")
    match = re.search(
        r"refId: C.*?evaluator:\n\s+params:\n\s+- ([0-9]+)\n\s+type: gt",
        content,
        re.S,
    )
    assert match is not None
    return int(match.group(1))


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


def test_log_errors_alert_uses_logsql_safe_literal_brackets() -> None:
    content = LOG_ERRORS.read_text(encoding="utf-8")

    assert r"\[ERROR\]" not in content
    assert r"\[metno\]" not in content
    assert "[[]ERROR[]]" in content
    assert "[[]metno[]]" in content


def test_log_errors_alert_excludes_known_transient_homelab_noise() -> None:
    excluded = _log_errors_exclusion_regex()

    transient_messages = [
        "Error: failed to set write deadline, connection is fully closed",
        'Error: time="2026-07-14T20:13:13Z" level=error msg="DiffFromCache error: error getting managed resources for app openebs-mayastor: cache: key is missing"',
        "Error: no edge forwarder found for edge circuit",
        'Error: time=2026-07-13T22:42:43.494Z level=ERROR source=collector.go:168 msg="collector failed" name=powersupplyclass duration_seconds=0.088315239 err="could not get power_supply class info: error obtaining power_supply class info: failed to read file "/host/sys/class/power_supply/BAT0/charge_types": input/output error"',
        'Error: 2026-07-13T16:13:11.877201Z ERROR pstor::etcd_watcher: Polling watch stream error, error: grpc request error: status: Unknown, message: "h2 protocol error: error reading a body from connection", details: [], metadata: MetadataMap { headers: {} }',
        "Error: 2026-07-13T16:13:24.133685Z ERROR pstor::etcd_keep_alive: error: Reconnect(Reconnect(1s))",
        "Error: 2026-07-13T16:13:25.138301Z ERROR pstor::etcd_keep_alive: error: LeaseGrant(LeaseGrant)",
        "Error: payload buffer closed",
        'Error: 2026-07-13T09:44:03Z WRN Error checking new version error="GET https://api.github.com/repos/traefik/traefik/releases: 403 API rate limit exceeded for 102.218.60.202. (But here\'s the good news: Authenticated requests get a higher rate limit. Check out the documentation for more details.) [rate reset in 3m31s]"',
        'Error: 2026-07-13T09:44:03Z WRN Error checking new version error="GET https://api.github.com/repos/traefik/traefik/releases: 403 API rate limit exceeded for 102.218.60.202. (But here\'s the good news: Authenticated requests get a higher rate limit. Check out the documentation for more details.) [rate reset in 3m32s]"',
        "Error: 2026-07-13T00:10:15.201635Z INFO garage_api_common::generic_server: Response: error 403 Forbidden, Forbidden: Garage does not support anonymous access yet",
    ]

    for message in transient_messages:
        assert excluded.search(message), message


def test_log_errors_alert_requires_repeated_fingerprint() -> None:
    assert _log_errors_threshold_value() == 2


def test_matrix_notification_message_uses_log_message_template() -> None:
    content = NOTIFICATIONS.read_text(encoding="utf-8")

    assert '{{ template "default.message" . }}' not in content
    assert '<span data-mx-color="#D50000"><strong>🚨 Firing</strong></span>' in content
    assert '<span data-mx-color="#00C853"><strong>✅ Resolved</strong></span>' in content
    assert "{{ if .Labels.error_fingerprint }}" in content
    assert "Error fingerprint: {{ .Labels.error_fingerprint }}" in content
    assert "{{ else if .Labels._msg }}" in content
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
        test_log_errors_alert_groups_by_normalized_fingerprint,
        test_log_errors_alert_trusts_structured_severity_before_message_fallback,
        test_log_errors_alert_excludes_synapse_preview_404_noise,
        test_log_errors_alert_excludes_grafana_provisioning_file_noise,
        test_log_errors_alert_excludes_transient_gmail_imap_noise,
        test_log_errors_alert_uses_logsql_safe_literal_brackets,
        test_log_errors_alert_excludes_known_transient_homelab_noise,
        test_log_errors_alert_requires_repeated_fingerprint,
        test_matrix_notification_message_uses_log_message_template,
        test_matrix_webhook_configmap_changes_roll_deployment,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")


if __name__ == "__main__":
    main()
