mock_provider "azurerm" {}

override_resource {
  target          = azurerm_monitor_action_group.this
  override_during = plan

  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Insights/actionGroups/ag-infraforge-dev"
  }
}

variables {
  virtual_network_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Network/virtualNetworks/vnet-infraforge-dev"
  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Network/virtualNetworks/vnet-infraforge-dev/subnets/snet-private-endpoints"

  workspace_name       = "law-infraforge-dev"
  location             = "westeurope"
  resource_group_name  = "rg-infraforge-dev"
  diagnostic_target_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.KeyVault/vaults/kv-infraforge-dev-001"
  alert_target_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.KeyVault/vaults/kv-infraforge-dev-001"
}

run "metric_alert_configuration" {
  command = plan

  assert {
    condition     = azurerm_monitor_metric_alert.this.enabled == true
    error_message = "Metric alert must be enabled."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.this.severity == 2
    error_message = "Metric alert must use the configured severity."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.this.criteria[0].threshold == 80
    error_message = "Metric alert must use the configured threshold."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.this.criteria[0].operator == "LessThan"
    error_message = "Availability alert must trigger below its threshold."
  }
}

run "action_group_association" {
  command = plan

  assert {
    condition = (
      one(azurerm_monitor_metric_alert.this.action).action_group_id ==
      azurerm_monitor_action_group.this.id
    )
    error_message = "Metric alert must reference its action group."
  }
}

run "reject_invalid_severity" {
  command = plan

  variables {
    alert_severity = 5
  }

  expect_failures = [
    var.alert_severity
  ]
}

run "reject_invalid_threshold" {
  command = plan

  variables {
    alert_threshold = 120
  }

  expect_failures = [
    var.alert_threshold
  ]
}
