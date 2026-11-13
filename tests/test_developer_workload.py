import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = ROOT / "examples/developer-workload"


class DeveloperWorkloadTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.main = (EXAMPLE / "main.tf").read_text(encoding="utf-8")
        cls.outputs = (EXAMPLE / "outputs.tf").read_text(encoding="utf-8")
        cls.variables = (EXAMPLE / "variables.tf").read_text(encoding="utf-8")

    def test_all_seven_reusable_modules_are_consumed(self):
        modules = {
            "resource_group": "resource-group",
            "networking": "networking",
            "identity": "identity",
            "keyvault": "keyvault",
            "monitoring": "monitoring",
            "compute": "compute",
            "storage": "storage",
        }

        for name, directory in modules.items():
            with self.subTest(module=name):
                self.assertIn(f'module "{name}"', self.main)
                self.assertIn(f"../../modules/{directory}", self.main)

    def test_workload_modules_use_shared_resource_group(self):
        references = re.findall(
            r"resource_group_name\s*=\s*module\.resource_group\.name",
            self.main
        )
        self.assertEqual(len(references), 6)

    def test_compute_uses_application_subnet(self):
        self.assertIn(
            'module.networking.subnet_ids["application"]',
            self.main,
        )

    def test_compute_uses_existing_managed_identity(self):
        self.assertIn(
            "module.identity.identity_id",
            self.main,
        )

    def test_compute_uses_ssh_public_key_variable(self):
        self.assertIn(
            "admin_ssh_public_key = var.admin_ssh_public_key",
            self.main,
        )
        self.assertIn(
            'variable "admin_ssh_public_key"',
            self.variables,
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

    def test_compute_outputs_are_exposed(self):
        expected_outputs = [
            "virtual_machine_id",
            "virtual_machine_name",
            "virtual_machine_private_ip",
            "virtual_machine_network_interface_id",
        ]

        for output in expected_outputs:
            with self.subTest(output=output):
                self.assertIn(f'output "{output}"', self.outputs)

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


    def test_storage_uses_private_endpoint_subnet(self):
        self.assertIn(
            'private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]',
            self.main,
        )

    def test_storage_uses_existing_virtual_network(self):
        self.assertRegex(
            self.main,
            r"virtual_network_id\s*=\s*module\.networking\.vnet_id"
        )

    def test_storage_uses_existing_resource_group(self):
        self.assertIn(
            'module "storage"',
            self.main,
        )
        self.assertIn(
            "resource_group_name  = module.resource_group.name",
            self.main,
        )

    def test_storage_outputs_are_exposed(self):
        expected_outputs = [
            "storage_account_id",
            "storage_account_name",
            "storage_primary_blob_endpoint",
            "storage_container_ids",
            "storage_private_endpoint_id",
            "storage_private_dns_zone_id",
            "storage_private_dns_zone_name",
        ]

        for output in expected_outputs:
            with self.subTest(output=output):
                self.assertIn(f'output "{output}"', self.outputs)


if __name__ == "__main__":
    unittest.main()
