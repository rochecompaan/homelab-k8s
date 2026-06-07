#!/usr/bin/env python3
"""Regression tests for the Grafana-to-Matrix webhook relay module."""

from __future__ import annotations

import importlib.util
from pathlib import Path
from types import ModuleType


MODULE_PATH = Path("argocd/homelab/grafana-dashboards/webhook/grafana_matrix_webhook.py")


def _load_server_module() -> ModuleType:
    spec = importlib.util.spec_from_file_location("grafana_matrix_webhook", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError(f"Unable to load webhook module from {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_matrix_send_url_escapes_room_id_and_uses_transaction_id() -> None:
    server = _load_server_module()

    url = server.matrix_send_url(
        "https://matrix.compaan/",
        "!alerts:matrix.compaan",
        "grafana-test-123",
    )

    assert url == (
        "https://matrix.compaan/_matrix/client/v3/rooms/"
        "%21alerts%3Amatrix.compaan/send/m.room.message/grafana-test-123"
    )


def test_build_matrix_event_summarizes_grafana_alert_payload() -> None:
    server = _load_server_module()
    payload = {
        "status": "firing",
        "title": "[FIRING:1] homelab node CPU usage above 90%",
        "message": "CPU usage above 90% on node nuc-1",
        "externalURL": "https://grafana.compaan/",
        "alerts": [
            {
                "status": "firing",
                "labels": {
                    "alertname": "homelab node CPU usage above 90%",
                    "severity": "critical",
                    "instance": "nuc-1",
                },
                "annotations": {
                    "summary": "CPU usage above 90% on homelab node nuc-1",
                    "description": "Node nuc-1 CPU usage is above 90%.",
                },
                "generatorURL": "https://grafana.compaan/alerting/rule/view",
            }
        ],
    }

    event = server.build_matrix_event(payload)

    assert event["msgtype"] == "m.notice"
    assert "🚨 [FIRING:1] homelab node CPU usage above 90%" in event["body"]
    assert "severity: critical" in event["body"]
    assert "CPU usage above 90% on homelab node nuc-1" in event["body"]
    assert "https://grafana.compaan/alerting/rule/view" in event["body"]
    assert event["format"] == "org.matrix.custom.html"
    assert "<strong>" in event["formatted_body"]


def test_build_matrix_event_preserves_safe_grafana_message_html() -> None:
    server = _load_server_module()
    payload = {
        "status": "firing",
        "title": "[FIRING:1] homelab log errors detected",
        "message": (
            '<span data-mx-color="#D50000"><strong>🚨 Firing</strong></span>\n'
            "Error: disk <boom> & retry failed"
        ),
    }

    event = server.build_matrix_event(payload)

    assert '<span data-mx-color="#D50000"><strong>🚨 Firing</strong></span>' in event["formatted_body"]
    assert "Error: disk &lt;boom&gt; &amp; retry failed" in event["formatted_body"]
    assert "&lt;span" not in event["formatted_body"]
    assert '<span data-mx-color="#D50000">' not in event["body"]
    assert "Error: disk <boom> & retry failed" in event["body"]


def test_build_matrix_event_decodes_grafana_escaped_message_html() -> None:
    server = _load_server_module()
    payload = {
        "status": "resolved",
        "title": "[RESOLVED] homelab log errors detected",
        "message": (
            '&lt;span data-mx-color=&quot;#00C853&quot;&gt;&lt;strong&gt;✅ Resolved&lt;/strong&gt;&lt;/span&gt;\n'
            "Error: disk &lt;boom&gt; &amp; retry failed"
        ),
    }

    event = server.build_matrix_event(payload)

    assert '<span data-mx-color="#00C853"><strong>✅ Resolved</strong></span>' in event["formatted_body"]
    assert "Error: disk &lt;boom&gt; &amp; retry failed" in event["formatted_body"]
    assert "&lt;span" not in event["formatted_body"]
    assert '<span data-mx-color="#00C853">' not in event["body"]
    assert "Error: disk <boom> & retry failed" in event["body"]


def main() -> None:
    tests = [
        test_matrix_send_url_escapes_room_id_and_uses_transaction_id,
        test_build_matrix_event_summarizes_grafana_alert_payload,
        test_build_matrix_event_preserves_safe_grafana_message_html,
        test_build_matrix_event_decodes_grafana_escaped_message_html,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")


if __name__ == "__main__":
    main()
