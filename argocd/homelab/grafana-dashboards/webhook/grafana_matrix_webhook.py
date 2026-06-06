#!/usr/bin/env python3
"""Receive Grafana webhooks and forward them as Matrix room notices."""

from __future__ import annotations

import html
import json
import logging
import os
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib import error, parse, request


LOG = logging.getLogger("grafana-matrix-webhook")
MAX_BODY_CHARS = 6000


def matrix_send_url(homeserver: str, room_id: str, txn_id: str) -> str:
    base = homeserver.rstrip("/")
    encoded_room = parse.quote(room_id, safe="")
    encoded_txn = parse.quote(txn_id, safe="")
    return f"{base}/_matrix/client/v3/rooms/{encoded_room}/send/m.room.message/{encoded_txn}"


def _configured(value: str | None) -> bool:
    return bool(value) and not value.startswith("replace-with-")


def is_ready() -> bool:
    return _configured(os.getenv("MATRIX_ACCESS_TOKEN")) and _configured(os.getenv("MATRIX_ROOM_ID"))


def _clean(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    return str(value).strip()


def _target_label(labels: dict[str, Any]) -> str:
    for key in ("instance", "node", "pod", "persistentvolumeclaim", "volume", "namespace", "job"):
        value = _clean(labels.get(key))
        if value:
            return f"{key}: {value}"
    return ""


def _truncate(body: str) -> str:
    if len(body) <= MAX_BODY_CHARS:
        return body
    return body[: MAX_BODY_CHARS - 32].rstrip() + "\n… truncated by relay"


def build_matrix_event(payload: dict[str, Any]) -> dict[str, str]:
    status = _clean(payload.get("status")).lower() or "unknown"
    title = _clean(payload.get("title")) or f"Grafana alert {status}"
    message = _clean(payload.get("message"))
    emoji = "✅" if status == "resolved" else "🚨" if status == "firing" else "ℹ️"

    lines: list[str] = [f"{emoji} {title}"]
    if message:
        lines.extend(["", message])

    alerts = payload.get("alerts") or []
    if isinstance(alerts, list) and alerts:
        lines.append("")
        lines.append("Alerts:")
        for alert in alerts[:10]:
            if not isinstance(alert, dict):
                continue
            labels = alert.get("labels") if isinstance(alert.get("labels"), dict) else {}
            annotations = alert.get("annotations") if isinstance(alert.get("annotations"), dict) else {}
            alert_status = _clean(alert.get("status")) or status
            alert_name = _clean(labels.get("alertname")) or _clean(alert.get("fingerprint")) or "alert"
            lines.append(f"- {alert_status}: {alert_name}")
            severity = _clean(labels.get("severity"))
            if severity:
                lines.append(f"  severity: {severity}")
            target = _target_label(labels)
            if target:
                lines.append(f"  {target}")
            summary = _clean(annotations.get("summary"))
            if summary:
                lines.append(f"  summary: {summary}")
            description = _clean(annotations.get("description"))
            if description and description != summary:
                lines.append(f"  description: {description}")
            generator_url = _clean(alert.get("generatorURL"))
            if generator_url:
                lines.append(f"  source: {generator_url}")
        if len(alerts) > 10:
            lines.append(f"- … {len(alerts) - 10} additional alert(s) omitted")

    external_url = _clean(payload.get("externalURL"))
    if external_url:
        lines.extend(["", f"Grafana: {external_url}"])

    body = _truncate("\n".join(lines))
    formatted = "<br>".join(html.escape(line) for line in body.splitlines())
    if lines:
        first, *rest = body.splitlines()
        formatted = "<strong>" + html.escape(first) + "</strong>"
        if rest:
            formatted += "<br>" + "<br>".join(html.escape(line) for line in rest)
    return {
        "msgtype": "m.notice",
        "body": body,
        "format": "org.matrix.custom.html",
        "formatted_body": formatted,
    }


def send_matrix_event(event: dict[str, str]) -> dict[str, Any]:
    homeserver = os.getenv("MATRIX_HOMESERVER", "https://matrix.compaan")
    room_id = os.getenv("MATRIX_ROOM_ID", "")
    token = os.getenv("MATRIX_ACCESS_TOKEN", "")
    txn_id = f"grafana-{int(time.time())}-{uuid.uuid4().hex}"
    url = matrix_send_url(homeserver, room_id, txn_id)
    body = json.dumps(event).encode("utf-8")
    req = request.Request(
        url,
        data=body,
        method="PUT",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "grafana-matrix-webhook/1",
        },
    )
    with request.urlopen(req, timeout=10) as resp:
        response_body = resp.read().decode("utf-8")
        try:
            parsed = json.loads(response_body) if response_body else {}
        except json.JSONDecodeError:
            parsed = {"raw": response_body}
        return {"status": resp.status, "body": parsed}


class Handler(BaseHTTPRequestHandler):
    server_version = "grafana-matrix-webhook/1"

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if self.path == "/healthz":
            self._json(200, {"ok": True})
            return
        if self.path == "/readyz":
            self._json(200 if is_ready() else 503, {"ready": is_ready()})
            return
        self._json(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if self.path != "/alert":
            self._json(404, {"error": "not found"})
            return
        if not is_ready():
            self._json(503, {"error": "matrix room or token is not configured"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            event = build_matrix_event(payload)
            result = send_matrix_event(event)
            self._json(202, {"ok": True, "matrix": result.get("body", {})})
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            LOG.exception("Matrix API returned HTTP %s", exc.code)
            self._json(502, {"error": "matrix api error", "status": exc.code, "detail": detail})
        except Exception as exc:  # pragma: no cover - defensive runtime handler
            LOG.exception("Failed to process webhook")
            self._json(500, {"error": str(exc)})

    def log_message(self, fmt: str, *args: Any) -> None:
        LOG.info("%s - %s", self.client_address[0], fmt % args)


def main() -> None:
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format="%(levelname)s %(message)s")
    port = int(os.getenv("PORT", "8080"))
    LOG.info("starting Grafana Matrix webhook relay on :%s", port)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
