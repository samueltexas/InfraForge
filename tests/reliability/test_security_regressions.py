"""Infrastructure security regression and negative tests."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read_source(*parts):
    """Read Terraform configuration without cloud access."""
    return ROOT.joinpath(*parts).read_text(encoding="utf-8")


def has_assignment(source, name, value):
    """Check whether a literal Terraform assignment exists."""
    pattern = (
        r"(?m)^\s*"
        + re.escape(name)
        + r"\s*=\s*"
        + re.escape(value)
        + r"\s*(?:#.*)?$"
    )
    return re.search(pattern, source) is not None


def is_public_cidr(value):
    """Identify unrestricted IPv4 or IPv6 CIDR ranges."""
    return value.strip() in {"0.0.0.0/0", "::/0"}


def is_privileged_port(value):
    """Identify common remote administration ports."""
    return int(value) in {22, 3389}


class InfrastructureSecurityRegressionTests(unittest.TestCase):

    def test_keyvault_public_network_access_remains_disabled(self):
        source = read_source("modules", "keyvault", "main.tf")
        self.assertTrue(
            has_assignment(source, "public_network_access_enabled", "false")
        )

    def test_keyvault_purge_protection_remains_enabled(self):
        source = read_source("modules", "keyvault", "main.tf")
        self.assertTrue(
            has_assignment(source, "purge_protection_enabled", "true")
        )

    def test_keyvault_rbac_remains_enabled(self):
        """Ensure Key Vault explicitly enables Azure RBAC."""
        module_directory = ROOT / "modules" / "keyvault"

        source = "\n".join(
            path.read_text(encoding="utf-8")
            for path in sorted(module_directory.glob("*.tf"))
        )

        self.assertTrue(
            has_assignment(source, "enable_rbac_authorization", "true")
            or has_assignment(source, "rbac_authorization_enabled", "true"),
            "Key Vault must explicitly enable RBAC authorization.",
        )

    def test_monitoring_public_ingestion_remains_disabled(self):
        source = read_source("modules", "monitoring", "main.tf")
        self.assertTrue(
            has_assignment(source, "internet_ingestion_enabled", "false")
        )

    def test_monitoring_public_query_remains_disabled(self):
        source = read_source("modules", "monitoring", "main.tf")
        self.assertTrue(
            has_assignment(source, "internet_query_enabled", "false")
        )

    def test_integrated_example_has_no_hardcoded_credentials(self):
        source = read_source("examples", "integrated", "main.tf")
        self.assertNotRegex(
            source,
            r'(?im)^\s*(?:client_secret|client_password|password)\s*=',
        )

    def test_integrated_example_does_not_manage_secrets(self):
        source = read_source("examples", "integrated", "main.tf")
        self.assertNotIn(
            'resource "azurerm_key_vault_secret"',
            source,
        )

    def test_private_endpoint_networking_is_integrated(self):
        source = read_source("examples", "integrated", "main.tf")
        self.assertIn(
            'module.networking.subnet_ids["private-endpoints"]',
            source,
        )

    def test_keyvault_monitoring_dependency_is_integrated(self):
        source = read_source("examples", "integrated", "main.tf")
        self.assertIn("module.keyvault.key_vault_id", source)


    def test_networking_rejects_unrestricted_ssh_and_rdp(self):
        source = read_source("modules", "networking", "variables.tf")

        self.assertIn('contains(["22", "3389"], rule.destination_port)', source)
        self.assertIn('!contains(["22", "3389"], rule.destination_port)', source)

    def test_networking_enforces_unique_priorities_per_subnet(self):
        source = read_source("modules", "networking", "variables.tf")

        self.assertIn(
            "other_rule.destination_subnet == rule.destination_subnet",
            source,
        )
        self.assertIn(
            "other_rule.priority == rule.priority",
            source,
        )


class InfrastructureNegativeTests(unittest.TestCase):

    def test_public_ipv4_cidr_is_rejected(self):
        self.assertTrue(is_public_cidr("0.0.0.0/0"))

    def test_public_ipv6_cidr_is_rejected(self):
        self.assertTrue(is_public_cidr("::/0"))

    def test_private_cidr_is_not_public(self):
        self.assertFalse(is_public_cidr("10.20.0.0/16"))

    def test_ssh_port_is_privileged(self):
        self.assertTrue(is_privileged_port(22))

    def test_rdp_port_is_privileged(self):
        self.assertTrue(is_privileged_port(3389))

    def test_https_port_is_not_administrative(self):
        self.assertFalse(is_privileged_port(443))

    def test_public_access_regression_is_detected(self):
        insecure = "public_network_access_enabled = true"
        self.assertFalse(
            has_assignment(
                insecure,
                "public_network_access_enabled",
                "false",
            )
        )

    def test_disabled_public_access_is_accepted(self):
        secure = "public_network_access_enabled = false"
        self.assertTrue(
            has_assignment(
                secure,
                "public_network_access_enabled",
                "false",
            )
        )

    def test_missing_purge_protection_is_detected(self):
        insecure = 'name = "example-vault"'
        self.assertFalse(
            has_assignment(
                insecure,
                "purge_protection_enabled",
                "true",
            )
        )


if __name__ == "__main__":
    unittest.main()
