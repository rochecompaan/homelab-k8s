#!/usr/bin/env python3
"""Regression tests for Just recipes that shell out to nested Just targets."""

from __future__ import annotations

import subprocess
from pathlib import Path


JUSTFILE = Path("Justfile")


def test_setup_grafana_matrix_alerts_uses_positional_recipe_arguments() -> None:
    result = subprocess.run(
        ["just", "--dry-run", "setup-grafana-matrix-alerts", "dummy-password"],
        check=True,
        capture_output=True,
        text=True,
    )
    output = result.stdout + result.stderr

    assert 'matrix_access_token="$(just matrix-create-access-token "$username" "$password" "$device")"' in output
    assert (
        'room_id="$(just matrix-create-room "$matrix_access_token" "$room_name" '
        "'Grafana alerts for the homelab Kubernetes cluster' \"$invite\")\""
    ) in output
    assert 'matrix-create-access-token "$username" "$password" device="$device"' not in output
    assert 'matrix-create-room "$matrix_access_token" name="$room_name"' not in output
    assert "just --quiet" not in output


def test_seal_openclaw_matrix_token_uses_positional_device_argument() -> None:
    result = subprocess.run(
        ["just", "--dry-run", "seal-openclaw-matrix-token", "user", "password", "device-name"],
        check=True,
        capture_output=True,
        text=True,
    )
    output = result.stdout + result.stderr

    assert "matrix-create-access-token 'user' 'password' 'device-name'" in output
    assert "just --quiet matrix-create-access-token" not in output
    assert "device='device-name'" not in output


def test_sensitive_matrix_recipes_do_not_echo_commands() -> None:
    lines = JUSTFILE.read_text(encoding="utf-8").splitlines()
    sensitive_recipes = {
        "matrix-create-user",
        "matrix-create-access-token",
        "matrix-accept-invite",
        "matrix-create-room",
        "seal-grafana-matrix-webhook-secret",
        "setup-grafana-matrix-alerts",
        "seal-openclaw-matrix-token",
    }

    for index, line in enumerate(lines):
        recipe_name = line.split(" ", 1)[0]
        if recipe_name not in sensitive_recipes:
            continue
        for body_line in lines[index + 1 :]:
            if not body_line.startswith("  "):
                raise AssertionError(f"{recipe_name} has no recipe body")
            if body_line.strip() == "":
                continue
            assert body_line.startswith("  @"), f"{recipe_name} echoes a sensitive command"
            break


def main() -> None:
    tests = [
        test_setup_grafana_matrix_alerts_uses_positional_recipe_arguments,
        test_seal_openclaw_matrix_token_uses_positional_device_argument,
        test_sensitive_matrix_recipes_do_not_echo_commands,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")


if __name__ == "__main__":
    main()
