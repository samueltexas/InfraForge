import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = ROOT / "examples/developer-workload"


class DeveloperWorkloadTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.main = (EXAMPLE / "main.tf").read_text()
        cls.outputs = (EXAMPLE / "outputs.tf").read_text()

    def test_all_five_reusable_modules_are_consumed(self):
        modules = {
            "resource_group": "resource-group",
            "networking": "networking",
            "identity": "identity",
            "keyvault": "keyvault",
            "monitoring": "monitoring",
        }

        for name, directory in modules.items():
            with self.subTest(module=name):
                self.assertIn(f'module "{name}"', self.main)
                self.assertIn(
                    f"../../modules/{directory}",
                    self.main,
                )

    def test_workload_modules_use_resource_group_output(self):
        self.assertEqual(
            self.main.count(
                "resource_group_name = module.resource_group.name"
            ),
            4,
        )


    def test_application_subnet_is_exposed(self):
        self.assertIn('output "application_subnet_id"', self.outputs)
        self.assertIn(
            'module.networking.subnet_ids["application"]',
            self.outputs,
        )

    def test_managed_identity_outputs_are_exposed(self):
        self.assertIn(
            'output "managed_identity_client_id"',
            self.outputs,
        )
        self.assertIn(
            'output "managed_identity_principal_id"',
            self.outputs,
        )

    def test_key_vault_uri_is_exposed(self):
        self.assertIn('output "key_vault_uri"', self.outputs)
        self.assertIn("module.keyvault.key_vault_uri", self.outputs)

    def test_monitoring_outputs_are_exposed(self):
        self.assertIn(
            'output "log_analytics_workspace_id"',
            self.outputs,
        )
        self.assertIn(
            'output "monitoring_private_link_scope_id"',
            self.outputs,
        )

    def test_private_endpoint_subnet_is_connected(self):
        self.assertIn(
            'module.networking.subnet_ids["private-endpoints"]',
            self.main,
        )

    def test_managed_identity_is_connected_to_key_vault(self):
        self.assertIn("module.identity.principal_id", self.main)

    def test_placeholder_subscription_is_used(self):
        self.assertIn(
            "00000000-0000-0000-0000-000000000000",
            self.main,
        )


if __name__ == "__main__":
    unittest.main()
