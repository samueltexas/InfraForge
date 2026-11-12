#!/usr/bin/env python3
"""Validate InfraForge network policies using Conftest."""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CASES = [
    ("secure.json", None),
    ("insecure-ssh.json", "NET-001:"),
    ("insecure-rdp.json", "NET-002:"),
]


def run_case(filename, expected_violation):
    command = [
        "docker",
        "run",
        "--rm",
        "-v",
        f"{ROOT}:/project:ro",
        "-w",
        "/project",
        "openpolicyagent/conftest:v0.59.0",
        "test",
        f"tests/policies/network/{filename}",
        "--policy",
        "policies/network",
        "--output",
        "json",
    ]

    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode not in (0, 1):
        raise RuntimeError(
            f"Conftest execution error for {filename}: "
            f"{result.stderr or result.stdout}"
        )

    try:
        reports = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"Invalid Conftest JSON for {filename}: "
            f"{result.stdout} {result.stderr}"
        ) from exc

    if not isinstance(reports, list) or len(reports) != 1:
        raise RuntimeError(f"Unexpected report structure: {filename}")

    report = reports[0]

    if report.get("exceptions") or report.get("warnings"):
        raise RuntimeError(f"Unexpected policy diagnostics: {filename}")

    failures = report.get("failures", [])
    if not isinstance(failures, list):
        raise RuntimeError(f"Invalid failures field: {filename}")

    messages = [item.get("msg", "") for item in failures]

    if expected_violation is None:
        if result.returncode != 0 or messages:
            raise RuntimeError(f"Secure fixture rejected: {messages}")
    else:
        if result.returncode != 1:
            raise RuntimeError(
                f"Insecure fixture did not produce policy failure: {filename}"
            )

        if len(messages) != 1:
            raise RuntimeError(
                f"Expected exactly one policy violation: {messages}"
            )

        if not messages[0].startswith(expected_violation):
            raise RuntimeError(
                f"Unexpected policy violation: {messages}"
            )

    print(f"PASS: {filename}")


def main():
    for filename, expected_violation in CASES:
        run_case(filename, expected_violation)

    print("ALL NETWORK POLICY TESTS PASSED")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
