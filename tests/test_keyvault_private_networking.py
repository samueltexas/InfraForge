"""Regression tests for Azure Key Vault private networking controls."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_terraform(relative_path):
    return (ROOT / relative_path).read_text(encoding="utf-8")


class KeyVaultPrivateNetworkingTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.vault = read_terraform("modules/keyvault/main.tf")
        cls.private = read_terraform("modules/keyvault/private_endpoint.tf")
        cls.example = read_terraform("examples/keyvault/main.tf")

    def test_public_network_access_is_disabled(self):
        self.assertRegex(
            self.vault,
            r"public_network_access_enabled\s*=\s*false\b",
        )

    def test_firewall_denies_traffic_by_default(self):
        self.assertRegex(
            self.vault,
            r'network_acls\s*\{\s*'
            r'default_action\s*=\s*"Deny"\s*'
            r'bypass\s*=\s*"None"',
        )

    def test_private_endpoint_references_key_vault(self):
        self.assertIn(
            'resource "azurerm_private_endpoint" "keyvault"',
            self.private,
        )
        self.assertRegex(
            self.private,
            r"private_connection_resource_id\s*="
            r"\s*azurerm_key_vault\.this\.id",
        )
        self.assertRegex(
            self.private,
            r'subresource_names\s*=\s*\["vault"\]',
        )

    def test_private_endpoint_uses_explicit_subnet(self):
        self.assertRegex(
            self.private,
            r"subnet_id\s*=\s*var\.private_endpoint_subnet_id",
        )

    def test_private_dns_is_configured(self):
        self.assertIn(
            '"privatelink.vaultcore.azure.net"',
            self.private,
        )
        self.assertIn(
            'resource "azurerm_private_dns_zone_virtual_network_link"',
            self.private,
        )
        self.assertRegex(
            self.private,
            r"private_dns_zone_ids\s*=\s*"
            r"\[azurerm_private_dns_zone\.keyvault\.id\]",
        )

    def test_example_connects_networking_to_key_vault(self):
        self.assertIn('module "networking"', self.example)
        self.assertIn('module "keyvault"', self.example)
        self.assertRegex(
            self.example,
            r"private_endpoint_subnet_id\s*=\s*"
            r'module\.networking\.subnet_ids\["private_endpoints"\]',
        )
        self.assertRegex(
            self.example,
            r"virtual_network_id\s*=\s*module\.networking\.vnet_id",
        )


if __name__ == "__main__":
    unittest.main()
