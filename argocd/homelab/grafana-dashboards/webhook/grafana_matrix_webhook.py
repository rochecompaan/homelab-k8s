#!/usr/bin/env python3
"""Receive Grafana webhooks and forward them as Matrix room notices."""

from __future__ import annotations

import html
import json
import logging
import os
import re
import time
import uuid
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib import error, parse, request


LOG = logging.getLogger("grafana-matrix-webhook")
MAX_BODY_CHARS = 6000
SAFE_MATRIX_TAGS = {"b", "strong", "i", "em", "code"}
SAFE_SPAN_COLOR_ATTRS = {"data-mx-bg-color", "data-mx-color"}
SAFE_FONT_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
ANSI_ESCAPE_RE = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
CONTROL_CHARACTER_RE = re.compile(r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]")
BR_TAG_RE = re.compile(r"<br\s*/?>", re.IGNORECASE)
MATRIX_FORMATTING_TAG_RE = re.compile(r"</?(?:span|font|b|strong|i|em|code)(?:\s+[^>]*)?>", re.IGNORECASE)


def matrix_send_url(homeserver: str, room_id: str, txn_id: str) -> str:
    base = homeserver.rstrip("/")
    encoded_room = parse.quote(room_id, safe="")
    encoded_txn = parse.quote(txn_id, safe="")
    return f"{base}/_matrix/client/v3/rooms/{encoded_room}/send/m.room.message/{encoded_txn}"


def _configured(value: str | None) -> bool:
    return bool(value) and not value.startswith("replace-with-")


def is_ready() -> bool:
    return _configured(os.getenv("MATRIX_ACCESS_TOKEN")) and _configured(os.getenv("MATRIX_ROOM_ID"))


def _strip_terminal_control_sequences(value: str) -> str:
    value = ANSI_ESCAPE_RE.sub("", value)
    return CONTROL_CHARACTER_RE.sub("", value)


def _clean(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return _strip_terminal_control_sequences(value).strip()
    return _strip_terminal_control_sequences(str(value)).strip()


def _target_label(labels: dict[str, Any]) -> str:
    for key in ("instance", "node", "pod", "persistentvolumeclaim", "volume", "namespace", "job"):
        value = _clean(labels.get(key))
        if value:
            return f"{key}: {value}"
    return ""


def _safe_span_attrs(attrs: list[tuple[str, str | None]]) -> list[str]:
    safe_attrs: list[str] = []
    for key, value in attrs:
        normalized_key = key.lower()
        color = _clean(value)
        if normalized_key in SAFE_SPAN_COLOR_ATTRS and SAFE_FONT_COLOR.fullmatch(color):
            safe_attrs.append(f'{normalized_key}="{html.escape(color, quote=True)}"')
    return safe_attrs


def _truncate(body: str) -> str:
    if len(body) <= MAX_BODY_CHARS:
        return body
    return body[: MAX_BODY_CHARS - 32].rstrip() + "\n… truncated by relay"


class _MatrixHTMLSanitizer(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.open_tags: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        normalized = tag.lower()
        if normalized == "br":
            self.parts.append("<br>")
            return
        if normalized == "span":
            safe_attrs = _safe_span_attrs(attrs)
            if safe_attrs:
                self.parts.append(f'<span {" ".join(safe_attrs)}>')
            else:
                self.parts.append("<span>")
            self.open_tags.append(normalized)
            return
        if normalized == "font":
            color = next((_clean(value) for key, value in attrs if key.lower() == "color"), "")
            if SAFE_FONT_COLOR.fullmatch(color):
                self.parts.append(f'<font color="{html.escape(color, quote=True)}">')
                self.open_tags.append(normalized)
                return
        elif normalized in SAFE_MATRIX_TAGS:
            self.parts.append(f"<{normalized}>")
            self.open_tags.append(normalized)
            return
        self.parts.append(html.escape(self.get_starttag_text() or "", quote=False))

    def handle_endtag(self, tag: str) -> None:
        normalized = tag.lower()
        if normalized in {"font", "span"} or normalized in SAFE_MATRIX_TAGS:
            for index in range(len(self.open_tags) - 1, -1, -1):
                if self.open_tags[index] == normalized:
                    del self.open_tags[index]
                    self.parts.append(f"</{normalized}>")
                    return
        self.parts.append(html.escape(f"</{tag}>", quote=False))

    def handle_data(self, data: str) -> None:
        self.parts.append(html.escape(data))

    def sanitized(self) -> str:
        return "".join(self.parts)


def _sanitize_matrix_html(value: str) -> str:
    sanitizer = _MatrixHTMLSanitizer()
    sanitizer.feed(value)
    sanitizer.close()
    return sanitizer.sanitized()


def _strip_matrix_formatting(value: str) -> str:
    value = _strip_terminal_control_sequences(html.unescape(value))
    value = BR_TAG_RE.sub("\n", value)
    value = MATRIX_FORMATTING_TAG_RE.sub("", value)
    return value


def _format_matrix_html(body: str) -> str:
    body = _strip_terminal_control_sequences(html.unescape(body))
    first, *rest = body.splitlines()
    formatted = "<strong>" + _sanitize_matrix_html(first) + "</strong>"
    if rest:
        formatted += "<br>" + "<br>".join(_sanitize_matrix_html(line) for line in rest)
    return formatted


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

    raw_body = _truncate("\n".join(lines))
    body = _strip_matrix_formatting(raw_body)
    formatted = _format_matrix_html(raw_body) if raw_body else ""
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
