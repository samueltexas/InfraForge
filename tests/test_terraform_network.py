#!/usr/bin/env python3
"""Regression tests for Terraform network security validation."""

import shutil
import subprocess
import sys
import tempfile
import unittest

from scripts.validate_terraform_network import validate_management_sources
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

    def test_public_admin_ipv4_is_accepted(self):
        validate_management_sources(
            {
                "public_admin": {
                    "source_type": "public_ipv4",
                    "source_prefix": "8.8.8.8/32",
                    "destination_subnet": "application",
                    "priority": 110,
                }
            },
            {"application": [], "database": []},
            {},
        )

    def test_private_vpn_source_is_accepted(self):
        validate_management_sources(
            {
                "corporate_vpn": {
                    "source_type": "private_vpn",
                    "source_prefix": "10.20.0.0/24",
                    "destination_subnet": "application",
                    "priority": 120,
                }
            },
            {"application": [], "database": []},
            {},
        )

    def test_management_ssh_cannot_target_database_subnet(self):
        with self.assertRaisesRegex(ValueError, "application subnet"):
            validate_management_sources(
                {
                    "public_admin": {
                        "source_type": "public_ipv4",
                        "source_prefix": "8.8.8.8/32",
                        "destination_subnet": "database",
                        "priority": 110,
                    }
                },
                {"application": [], "database": []},
                {},
            )

    def test_public_ssh_cidr_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "/32"):
            validate_management_sources(
                {
                    "public_admin": {
                        "source_type": "public_ipv4",
                        "source_prefix": "8.8.8.0/24",
                        "destination_subnet": "application",
                        "priority": 110,
                    }
                },
                {"application": []},
                {},
            )

    def test_unrestricted_ssh_source_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "/32"):
            validate_management_sources(
                {
                    "public_admin": {
                        "source_type": "public_ipv4",
                        "source_prefix": "0.0.0.0/0",
                        "destination_subnet": "application",
                        "priority": 110,
                    }
                },
                {"application": []},
                {},
            )

    def test_public_address_cannot_be_declared_as_vpn(self):
        with self.assertRaisesRegex(ValueError, "RFC1918"):
            validate_management_sources(
                {
                    "corporate_vpn": {
                        "source_type": "private_vpn",
                        "source_prefix": "8.8.8.0/24",
                        "destination_subnet": "application",
                        "priority": 120,
                    }
                },
                {"application": []},
                {},
            )

    def test_management_priority_must_be_unique(self):
        with self.assertRaisesRegex(ValueError, "Duplicate NSG priority"):
            validate_management_sources(
                {
                    "public_admin": {
                        "source_type": "public_ipv4",
                        "source_prefix": "8.8.8.8/32",
                        "destination_subnet": "application",
                        "priority": 100,
                    }
                },
                {"application": []},
                {
                    "AllowApplicationPostgres": {
                        "destination_subnet": "application",
                        "priority": 100,
                    }
                },
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


    def test_modified_management_ssh_port_is_rejected(self):
        self.replace(
            "modules/networking/security_rules.tf",
            'destination_port_range      = "22"',
            'destination_port_range      = "2222"',
        )

        result = self.validate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Unexpected allow_management_ssh.destination_port_range",
            result.stderr,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
