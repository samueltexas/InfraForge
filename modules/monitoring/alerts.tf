resource "azurerm_monitor_action_group" "this" {
  name                = var.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = var.action_group_short_name

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers

    content {
      name                    = email_receiver.key
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "this" {
  name                = var.alert_name
  resource_group_name = var.resource_group_name
  scopes              = [var.alert_target_id]

  description = "InfraForge infrastructure monitoring alert."

  severity    = var.alert_severity
  enabled     = true
  frequency   = "PT5M"
  window_size = "PT15M"

  criteria {
    metric_namespace = var.metric_namespace
    metric_name      = var.metric_name
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = var.alert_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }

  tags = var.tags
}
