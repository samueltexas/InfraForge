mock_provider "azurerm" {}

override_resource {
  target          = azurerm_log_analytics_workspace.this
  override_during = plan

  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.OperationalInsights/workspaces/law-infraforge-dev"
  }
}

variables {
  virtual_network_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Network/virtualNetworks/vnet-infraforge-dev"
  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Network/virtualNetworks/vnet-infraforge-dev/subnets/snet-private-endpoints"

  workspace_name      = "law-infraforge-dev"
  location            = "westeurope"
  resource_group_name = "rg-infraforge-dev"

  alert_target_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.KeyVault/vaults/kv-infraforge-dev-001"
  diagnostic_target_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.KeyVault/vaults/kv-infraforge-dev-001"
}

run "secure_workspace_configuration" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.this.sku == "PerGB2018"
    error_message = "Log Analytics must use the expected SKU."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days >= 30
    error_message = "Log retention must be at least 30 days."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.internet_ingestion_enabled == false
    error_message = "Public ingestion must be disabled."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.internet_query_enabled == false
    error_message = "Public query access must be disabled."
  }
}

run "diagnostic_settings_configuration" {
  command = plan

  assert {
    condition = (
      azurerm_monitor_diagnostic_setting.this.log_analytics_workspace_id ==
      azurerm_log_analytics_workspace.this.id
    )
    error_message = "Diagnostics must reference the managed workspace."
  }

  assert {
    condition = (
      azurerm_monitor_diagnostic_setting.this.target_resource_id ==
      var.diagnostic_target_id
    )
    error_message = "Diagnostics must reference the explicit target."
  }
}

run "reject_short_retention" {
  command = plan

  variables {
    retention_days = 7
  }

  expect_failures = [
    var.retention_days
  ]
}

run "reject_invalid_workspace_name" {
  command = plan

  variables {
    workspace_name = "a"
  }

  expect_failures = [
    var.workspace_name
  ]
}
