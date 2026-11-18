import unittest
from pathlib import Path

import hcl2


ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = ROOT / "examples" / "integrated" / "main.tf"


def load_configuration():
    with EXAMPLE.open(encoding="utf-8") as file:
        return hcl2.load(file)


def get_modules(configuration):
    modules = {}

    for block in configuration.get("module", []):
        for name, settings in block.items():
            modules[name] = settings

    return modules


class IntegratedArchitectureTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.configuration = load_configuration()
        cls.modules = get_modules(cls.configuration)

    def test_required_modules_exist(self):
        self.assertEqual(
            set(self.modules),
            {"keyvault", "monitoring", "storage"},
        )

    def test_modules_use_local_sources(self):
        for name in self.modules:
            self.assertEqual(
                self.modules[name]["source"],
                f"../../modules/{name.replace('_', '-')}",
            )

    def test_keyvault_uses_networking_outputs(self):
        keyvault = self.modules["keyvault"]

        self.assertEqual(
            keyvault["virtual_network_id"],
            "${data.azurerm_virtual_network.foundation.id}",
        )

        self.assertEqual(
            keyvault["private_endpoint_subnet_id"],
            '${data.azurerm_subnet.private_endpoints.id}',
        )

    def test_keyvault_uses_managed_identity(self):
        keyvault = self.modules["keyvault"]

        self.assertEqual(
            keyvault["reader_principal_ids"],
            ["${data.azurerm_user_assigned_identity.foundation.principal_id}"],
        )

    def test_monitoring_uses_keyvault_resource_id(self):
        monitoring = self.modules["monitoring"]

        self.assertEqual(
            monitoring["diagnostic_target_id"],
            "${module.keyvault.key_vault_id}",
        )

        self.assertEqual(
            monitoring["alert_target_id"],
            "${module.keyvault.key_vault_id}",
        )

    def test_monitoring_uses_networking_outputs(self):
        monitoring = self.modules["monitoring"]

        self.assertEqual(
            monitoring["virtual_network_id"],
            "${data.azurerm_virtual_network.foundation.id}",
        )

        self.assertEqual(
            monitoring["private_endpoint_subnet_id"],
            '${data.azurerm_subnet.private_endpoints.id}',
        )

    def test_foundation_is_referenced_without_recreation(self):
        data = {}
        for block in self.configuration.get("data", []):
            data.update(block)
        self.assertEqual(data["azurerm_subnet"]["private_endpoints"]["name"], "private-endpoints")
        self.assertIn("azurerm_virtual_network", data)
        self.assertIn("azurerm_user_assigned_identity", data)
        self.assertIn("azurerm_resource_group", data)

    def test_no_static_keyvault_reader_identity(self):
        keyvault = self.modules["keyvault"]

        self.assertNotIn(
            "11111111-1111-1111-1111-111111111111",
            str(keyvault["reader_principal_ids"]),
        )


if __name__ == "__main__":
    unittest.main()
