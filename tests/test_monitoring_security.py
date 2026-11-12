"""Static regression tests for Azure monitoring infrastructure."""

import unittest
from pathlib import Path

import hcl2


ROOT = Path(__file__).resolve().parents[1]


def load_hcl(relative_path):
    with (ROOT / relative_path).open(encoding="utf-8") as file:
        return hcl2.load(file)


class MonitoringSecurityTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        module = load_hcl("modules/monitoring/main.tf")
        cls.resources = {
            resource_type: configuration
            for resource in module["resource"]
            for resource_type, configuration in resource.items()
        }
        cls.example = load_hcl("examples/monitoring/main.tf")

    def test_log_analytics_workspace_exists(self):
        self.assertIn(
            "azurerm_log_analytics_workspace",
            self.resources,
        )

    def test_workspace_uses_supported_sku(self):
        workspace = self.resources[
            "azurerm_log_analytics_workspace"
        ]["this"]
        self.assertEqual(workspace["sku"], "PerGB2018")

    def test_workspace_retention_is_configurable(self):
        workspace = self.resources[
            "azurerm_log_analytics_workspace"
        ]["this"]
        self.assertEqual(
            workspace["retention_in_days"],
            "${var.retention_days}",
        )

    def test_public_ingestion_is_disabled(self):
        workspace = self.resources[
            "azurerm_log_analytics_workspace"
        ]["this"]
        self.assertFalse(workspace["internet_ingestion_enabled"])

    def test_public_query_is_disabled(self):
        workspace = self.resources[
            "azurerm_log_analytics_workspace"
        ]["this"]
        self.assertFalse(workspace["internet_query_enabled"])

    def test_diagnostic_setting_uses_workspace(self):
        diagnostics = self.resources[
            "azurerm_monitor_diagnostic_setting"
        ]["this"]
        self.assertEqual(
            diagnostics["log_analytics_workspace_id"],
            "${azurerm_log_analytics_workspace.this.id}",
        )

    def test_diagnostic_target_is_explicit(self):
        diagnostics = self.resources[
            "azurerm_monitor_diagnostic_setting"
        ]["this"]
        self.assertEqual(
            diagnostics["target_resource_id"],
            "${var.diagnostic_target_id}",
        )

    def test_example_uses_keyvault_audit_logs(self):
        monitoring = next(
            item["monitoring"]
            for item in self.example["module"]
            if "monitoring" in item
        )
        self.assertEqual(
            monitoring["log_categories"],
            ["AuditEvent"],
        )
        self.assertEqual(
            monitoring["metric_categories"],
            ["AllMetrics"],
        )


if __name__ == "__main__":
    unittest.main()
