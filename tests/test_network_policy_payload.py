#!/usr/bin/env python3
"""Regression tests for Terraform-derived network policy input."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "scripts/validate_terraform_network.py"


class NetworkPolicyPayloadTests(unittest.TestCase):
    def test_validator_supports_external_output_path(self):
        with tempfile.TemporaryDirectory(prefix="infraforge-policy-") as temp:
            output = Path(temp) / "terraform-generated.json"

            result = subprocess.run(
                [
                    sys.executable,
                    str(VALIDATOR),
                    "--output",
                    str(output),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(
                result.returncode,
                0,
                msg=result.stdout + result.stderr,
            )
            self.assertTrue(output.is_file())

            payload = json.loads(output.read_text(encoding="utf-8"))

            self.assertEqual(
                set(payload),
                {
                    "security_rules",
                    "outbound_rules",
                    "management_sources",
                },
            )
            self.assertIsInstance(payload["security_rules"], list)
            self.assertIsInstance(payload["outbound_rules"], list)
            self.assertIsInstance(payload["management_sources"], list)

    def test_variable_driven_management_sources_are_not_fabricated(self):
        with tempfile.TemporaryDirectory(prefix="infraforge-policy-") as temp:
            output = Path(temp) / "terraform-generated.json"

            subprocess.run(
                [
                    sys.executable,
                    str(VALIDATOR),
                    "--output",
                    str(output),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=True,
            )

            payload = json.loads(output.read_text(encoding="utf-8"))

            # The example uses var.management_sources. Its runtime values
            # must not be invented by a static source-code validator.
            self.assertEqual(payload["management_sources"], [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
