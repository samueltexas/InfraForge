output "workspace_id" {
  description = "Azure resource ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Name of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "diagnostic_setting_id" {
  description = "Azure resource ID of the diagnostic setting."
  value       = azurerm_monitor_diagnostic_setting.this.id
}

output "action_group_id" {
  description = "Azure Monitor Action Group resource ID."
  value       = azurerm_monitor_action_group.this.id
}

output "metric_alert_id" {
  description = "Azure Monitor Metric Alert resource ID."
  value       = azurerm_monitor_metric_alert.this.id
}

output "private_link_scope_id" {
  description = "Azure Monitor Private Link Scope resource ID."
  value       = azurerm_monitor_private_link_scope.this.id
}

output "monitoring_private_endpoint_id" {
  description = "Azure Monitor private endpoint resource ID."
  value       = azurerm_private_endpoint.monitoring.id
}
