output "storage_account_id" {
  description = "Azure resource ID of the Storage Account."
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the Storage Account."
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "Primary Blob Storage endpoint."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "container_ids" {
  description = "Azure resource IDs of the created Blob containers."
  value = {
    for name, container in azurerm_storage_container.this : name => container.id
  }
}

output "private_endpoint_id" {
  description = "Azure resource ID of the Blob Private Endpoint."
  value       = azurerm_private_endpoint.blob.id
}

output "private_dns_zone_id" {
  description = "Azure resource ID of the shared Blob Private DNS Zone."
  value       = local.blob_private_dns_zone_id
}

output "private_dns_zone_name" {
  description = "Private DNS Zone domain name."
  value       = local.blob_private_dns_zone_name
}

output "blob_diagnostic_setting_id" {
  description = "Azure resource ID of the Blob service diagnostic setting."
  value       = azurerm_monitor_diagnostic_setting.blob.id
}

output "queue_properties_id" {
  description = "Azure resource ID of the Queue service logging configuration."
  value       = try(azurerm_storage_account_queue_properties.this[0].id, null)
}

output "blob_data_role_assignment_ids" {
  description = "Azure RBAC assignment IDs granting Blob data access to workload identities."
  value       = [for assignment in azurerm_role_assignment.blob_data_contributor : assignment.id]
}

output "queue_diagnostic_setting_id" {
  description = "Queue Azure Monitor diagnostic setting ID, or null when legacy analytics is used."
  value       = try(azurerm_monitor_diagnostic_setting.queue[0].id, null)
}
