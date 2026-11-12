import unittest
from pathlib import Path

import hcl2


ROOT = Path(__file__).resolve().parents[1]


def load_hcl(relative_path):
    with (ROOT / relative_path).open(encoding="utf-8") as file:
        return hcl2.load(file)


def resources(document, resource_type):
    result = []

    for resource in document.get("resource", []):
        result.extend(resource.get(resource_type, {}).values())

    return result


class MonitoringPrivateLinkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.private_link = load_hcl("modules/monitoring/private_link.tf")
        cls.monitoring = load_hcl("modules/monitoring/main.tf")
        cls.example = load_hcl("examples/monitoring/main.tf")

    def test_private_link_scope_exists(self):
        self.assertEqual(
            len(resources(self.private_link, "azurerm_monitor_private_link_scope")),
            1,
        )

    def test_private_link_scope_restricts_public_access(self):
        scope = resources(
            self.private_link,
            "azurerm_monitor_private_link_scope",
        )[0]

        self.assertEqual(scope["ingestion_access_mode"], "PrivateOnly")
        self.assertEqual(scope["query_access_mode"], "PrivateOnly")

    def test_workspace_is_linked_to_private_link_scope(self):
        scoped_services = resources(
            self.private_link,
            "azurerm_monitor_private_link_scoped_service",
        )

        self.assertEqual(len(scoped_services), 1)
        self.assertIn(
            "azurerm_log_analytics_workspace.this.id",
            str(scoped_services[0]["linked_resource_id"]),
        )

    def test_private_endpoint_exists(self):
        endpoints = resources(
            self.private_link,
            "azurerm_private_endpoint",
        )

        self.assertEqual(len(endpoints), 1)
        self.assertIn(
            "var.private_endpoint_subnet_id",
            str(endpoints[0]["subnet_id"]),
        )

    def test_private_endpoint_uses_azure_monitor(self):
        endpoint = resources(
            self.private_link,
            "azurerm_private_endpoint",
        )[0]

        connection = endpoint["private_service_connection"][0]

        self.assertEqual(connection["subresource_names"], ["azuremonitor"])

    def test_private_dns_zones_exist(self):
        zones = resources(
            self.private_link,
            "azurerm_private_dns_zone",
        )

        self.assertEqual(len(zones), 1)

        source = (ROOT / "modules/monitoring/private_link.tf").read_text(
            encoding="utf-8"
        )

        self.assertIn("privatelink.monitor.azure.com", source)
        self.assertIn("privatelink.oms.opinsights.azure.com", source)
        self.assertIn("privatelink.ods.opinsights.azure.com", source)

    def test_dns_links_use_explicit_virtual_network(self):
        links = resources(
            self.private_link,
            "azurerm_private_dns_zone_virtual_network_link",
        )

        self.assertEqual(len(links), 1)
        self.assertIn(
            "var.virtual_network_id",
            str(links[0]["virtual_network_id"]),
        )

    def test_example_uses_networking_outputs(self):
        modules = self.example["module"]

        monitoring = next(
            module["monitoring"]
            for module in modules
            if "monitoring" in module
        )

        self.assertIn(
            "module.networking.vnet_id",
            str(monitoring["virtual_network_id"]),
        )

        self.assertIn(
            "module.networking.subnet_ids",
            str(monitoring["private_endpoint_subnet_id"]),
        )


if __name__ == "__main__":
    unittest.main()
