"""Security regression tests for the Azure Key Vault Terraform module."""

import unittest
from pathlib import Path

import hcl2


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules" / "keyvault"
EXAMPLE = ROOT / "examples" / "keyvault"


def load_hcl(path):
    """Parse Terraform configuration instead of relying on text matching."""
    with path.open(encoding="utf-8") as file:
        return hcl2.load(file)


def find_resource(configuration, resource_type, resource_name):
    """Find a named Terraform resource in parsed HCL."""
    for entry in configuration.get("resource", []):
        if resource_type in entry:
            resources = entry[resource_type]
            if resource_name in resources:
                return resources[resource_name]

    raise AssertionError(
        f"Missing Terraform resource: {resource_type}.{resource_name}"
    )


class KeyVaultSecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.main = load_hcl(MODULE / "main.tf")
        cls.variables = load_hcl(MODULE / "variables.tf")
        cls.example = load_hcl(EXAMPLE / "main.tf")

        cls.vault = find_resource(
            cls.main, "azurerm_key_vault", "this"
        )
        cls.assignment = find_resource(
            cls.main, "azurerm_role_assignment", "secrets_reader"
        )

    def test_rbac_authorization_is_enabled(self):
        self.assertIs(
            self.vault["rbac_authorization_enabled"], True
        )

    def test_public_network_access_is_disabled(self):
        self.assertIs(
            self.vault["public_network_access_enabled"], False
        )

    def test_purge_protection_is_enabled(self):
        self.assertIs(
            self.vault["purge_protection_enabled"], True
        )

    def test_soft_delete_retention_is_configured(self):
        self.assertEqual(
            self.vault["soft_delete_retention_days"], 90
        )

    def test_standard_sku_is_used(self):
        self.assertEqual(self.vault["sku_name"], "standard")

    def test_only_secrets_user_role_is_assigned(self):
        self.assertEqual(
            self.assignment["role_definition_name"],
            "Key Vault Secrets User",
        )

    def test_role_assignment_uses_vault_scope(self):
        self.assertEqual(
            self.assignment["scope"],
            "${azurerm_key_vault.this.id}",
        )

    def test_role_assignment_uses_explicit_principals(self):
        self.assertEqual(
            self.assignment["for_each"],
            "${var.reader_principal_ids}",
        )
        self.assertEqual(
            self.assignment["principal_id"],
            "${each.value}",
        )

    def test_no_secret_values_are_managed(self):
        forbidden = {
            "azurerm_key_vault_secret",
            "azurerm_key_vault_key",
            "azurerm_key_vault_certificate",
        }

        resource_types = {
            resource_type
            for entry in self.main.get("resource", [])
            for resource_type in entry
        }

        self.assertTrue(forbidden.isdisjoint(resource_types))

    def test_example_uses_placeholder_subscription(self):
        provider = self.example["provider"][0]["azurerm"]

        self.assertEqual(
            provider["subscription_id"],
            "00000000-0000-0000-0000-000000000000",
        )

    def test_example_uses_placeholder_tenant(self):
        module = self.example["module"][0]["keyvault"]

        self.assertEqual(
            module["tenant_id"],
            "00000000-0000-0000-0000-000000000000",
        )

    def test_example_references_reusable_module(self):
        module = self.example["module"][0]["keyvault"]

        self.assertEqual(
            module["source"],
            "../../modules/keyvault",
        )


if __name__ == "__main__":
    unittest.main()
