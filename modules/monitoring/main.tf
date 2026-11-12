resource "azurerm_log_analytics_workspace" "this" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku               = "PerGB2018"
  retention_in_days = var.retention_days

  internet_ingestion_enabled = false
  internet_query_enabled     = false

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = var.diagnostic_name
  target_resource_id         = var.diagnostic_target_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = var.log_categories

    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = var.metric_categories

    content {
      category = enabled_metric.value
    }
  }
}
