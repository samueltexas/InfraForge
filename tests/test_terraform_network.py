#!/usr/bin/env python3
"""Regression tests for Terraform network security validation."""

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class TerraformNetworkSecurityTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)

        self.root = Path(self.workspace.name)

        for relative_path in [
            "examples/networking/main.tf",
            "modules/networking/security_rules.tf",
            "scripts/validate_terraform_network.py",
        ]:
            source = ROOT / relative_path
            destination = self.root / relative_path

            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

    def replace(self, relative_path, original, replacement):
        path = self.root / relative_path
        content = path.read_text(encoding="utf-8")

        self.assertIn(original, content)

        path.write_text(
            content.replace(original, replacement, 1),
            encoding="utf-8",
        )

    def validate(self):
        return subprocess.run(
            [
                sys.executable,
                str(self.root / "scripts/validate_terraform_network.py"),
            ],
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_secure_configuration_passes(self):
        result = self.validate()

        self.assertEqual(
            result.returncode,
            0,
            result.stdout + result.stderr,
        )

    def test_public_ssh_is_rejected(self):
        self.replace(
            "examples/networking/main.tf",
            'source_prefix      = "10.10.3.0/24"',
            'source_prefix      = "0.0.0.0/0"',
        )

        result = self.validate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Source must belong to a managed subnet",
            result.stderr,
        )

    def test_modified_allow_rule_mapping_is_rejected(self):
        self.replace(
            "modules/networking/security_rules.tf",
            'source_address_prefix       = each.value.source_prefix',
            'source_address_prefix       = "*"',
        )

        result = self.validate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Unexpected allow_inbound.source_address_prefix",
            result.stderr,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
