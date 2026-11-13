"""Infrastructure contract and reliability regression tests."""

import re
import unittest
from pathlib import Path

import hcl2


ROOT = Path(__file__).resolve().parents[2]

MODULES = {
    "networking": {
        "inputs": {
            "resource_group_name",
            "location",
            "vnet_name",
            "address_space",
            "subnets",
            "tags",
            "security_rules",
            "management_sources",
        },
        "outputs": {"vnet_id", "subnet_ids"},
    },
    "identity": {
        "inputs": {
            "name",
            "location",
            "resource_group_name",
            "role_assignments",
            "tags",
        },
        "outputs": {"identity_id", "principal_id", "client_id"},
    },
    "keyvault": {
        "inputs": {
            "name",
            "location",
            "resource_group_name",
            "tenant_id",
            "reader_principal_ids",
            "tags",
            "private_endpoint_subnet_id",
            "virtual_network_id",
        },
        "outputs": {
            "key_vault_id",
            "key_vault_name",
            "key_vault_uri",
            "private_endpoint_id",
        },
    },
    "monitoring": {
        "inputs": {
            "workspace_name",
            "location",
            "resource_group_name",
            "diagnostic_target_id",
            "diagnostic_name",
            "log_categories",
            "metric_categories",
            "retention_days",
            "tags",
            "action_group_name",
            "action_group_short_name",
            "alert_name",
            "alert_target_id",
            "metric_namespace",
            "metric_name",
            "alert_threshold",
            "alert_severity",
            "private_link_scope_name",
            "private_endpoint_name",
            "private_endpoint_subnet_id",
            "virtual_network_id",
            "alert_email_receivers",
        },
        "outputs": {
            "workspace_id",
            "workspace_name",
            "diagnostic_setting_id",
            "action_group_id",
            "metric_alert_id",
            "private_link_scope_id",
            "monitoring_private_endpoint_id",
        },
    },
}



def read_declarations(directory, kind):
    """Extract Terraform variable and output declarations."""
    filename = {
        "variable": "variables.tf",
        "output": "outputs.tf",
    }[kind]

    content = (directory / filename).read_text(encoding="utf-8")

    pattern = (
        r'^\s*'
        + re.escape(kind)
        + r'\s+"([A-Za-z_][A-Za-z0-9_]*)"\s*\{'
    )

    return set(re.findall(pattern, content, flags=re.MULTILINE))


def load_integrated_configuration():
    """Parse the integrated example without contacting Azure."""
    documents = []

    directory = ROOT / "examples/integrated"

    for path in sorted(directory.glob("*.tf")):
        with path.open(encoding="utf-8") as handle:
            documents.append(hcl2.load(handle))

    return documents


def collect_blocks(documents, block_type):
    """Collect named Terraform blocks."""
    result = {}

    for document in documents:
        for block in document.get(block_type, []):
            result.update(block)

    return result


class InfrastructureContractTests(unittest.TestCase):

    def test_module_directories_exist(self):
        for module_name in MODULES:
            with self.subTest(module=module_name):
                self.assertTrue(
                    (ROOT / "modules" / module_name).is_dir()
                )

    def test_module_inputs_match_contract(self):
        for module_name, contract in MODULES.items():
            with self.subTest(module=module_name):
                actual = read_declarations(
                    ROOT / "modules" / module_name,
                    "variable",
                )
                self.assertEqual(actual, contract["inputs"])

    def test_module_outputs_match_contract(self):
        for module_name, contract in MODULES.items():
            with self.subTest(module=module_name):
                actual = read_declarations(
                    ROOT / "modules" / module_name,
                    "output",
                )
                self.assertEqual(actual, contract["outputs"])

    def test_all_modules_have_provider_constraints(self):
        for module_name in MODULES:
            with self.subTest(module=module_name):
                path = ROOT / "modules" / module_name / "versions.tf"
                self.assertTrue(path.is_file())

                content = path.read_text(encoding="utf-8")
                self.assertRegex(content, r"required_providers\s*\{")
                self.assertRegex(content, r"azurerm\s*=\s*\{")

    def test_integrated_example_uses_all_modules(self):
        modules = collect_blocks(
            load_integrated_configuration(), "module"
        )
        self.assertEqual(set(modules), set(MODULES))

    def test_integrated_module_sources_are_local(self):
        modules = collect_blocks(
            load_integrated_configuration(), "module"
        )

        for name, configuration in modules.items():
            with self.subTest(module=name):
                self.assertEqual(
                    configuration["source"],
                    f"../../modules/{name}",
                )

    def test_integrated_module_arguments_exist_in_contract(self):
        modules = collect_blocks(
            load_integrated_configuration(), "module"
        )

        reserved = {
            "source", "version", "providers",
            "depends_on", "count", "for_each",
        }

        for name, configuration in modules.items():
            with self.subTest(module=name):
                supplied = set(configuration) - reserved
                unexpected = supplied - MODULES[name]["inputs"]

                self.assertFalse(
                    unexpected,
                    f"Unexpected arguments for {name}: {unexpected}",
                )

    def test_integrated_example_has_no_backend_configuration(self):
        for document in load_integrated_configuration():
            for block in document.get("terraform", []):
                self.assertNotIn("backend", block)

    def test_integrated_example_does_not_create_resources_directly(self):
        for document in load_integrated_configuration():
            self.assertFalse(document.get("resource"))

    def test_module_outputs_are_not_empty(self):
        for module_name in MODULES:
            with self.subTest(module=module_name):
                content = (
                    ROOT / "modules" / module_name / "outputs.tf"
                ).read_text(encoding="utf-8")

                self.assertIn("value", content)

                self.assertEqual(
                    read_declarations(
                        ROOT / "modules" / module_name, "output"
                    ),
                    MODULES[module_name]["outputs"],
                )


if __name__ == "__main__":
    unittest.main()
