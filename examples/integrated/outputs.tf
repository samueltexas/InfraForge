output "resource_group_name" {
  description = "Name of the shared Foundation Resource Group."
  value       = data.azurerm_resource_group.foundation.name
}

output "virtual_network_id" {
  description = "Resource ID of the shared Foundation Virtual Network."
  value       = data.azurerm_virtual_network.foundation.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the shared Foundation managed identity."
  value       = data.azurerm_user_assigned_identity.foundation.principal_id
}

output "key_vault_id" {
  description = "Resource ID of the private Key Vault."
  value       = module.keyvault.key_vault_id
}

output "key_vault_name" {
  description = "Name of the private Key Vault."
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "URI used by applications to access Key Vault."
  value       = module.keyvault.key_vault_uri
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace."
  value       = module.monitoring.workspace_id
}

output "monitoring_private_link_scope_id" {
  description = "Resource ID of the Azure Monitor Private Link Scope."
  value       = module.monitoring.private_link_scope_id
}

output "storage_account_id" {
  description = "Resource ID of the application Storage Account."
  value       = module.storage.storage_account_id
}

output "storage_account_name" {
  description = "Name of the application Storage Account."
  value       = module.storage.storage_account_name
}

output "storage_primary_blob_endpoint" {
  description = "Primary Blob Storage endpoint."
  value       = module.storage.primary_blob_endpoint
}

output "storage_container_ids" {
  description = "Resource IDs of application Blob containers."
  value       = module.storage.container_ids
}

output "storage_private_endpoint_id" {
  description = "Resource ID of the Storage Private Endpoint."
  value       = module.storage.private_endpoint_id
}

output "storage_private_dns_zone_id" {
  description = "Resource ID of the Blob Private DNS Zone."
  value       = module.storage.private_dns_zone_id
}

output "storage_private_dns_zone_name" {
  description = "Domain name of the Blob Private DNS Zone."
  value       = module.storage.private_dns_zone_name
}

output "storage_blob_diagnostic_setting_id" {
  description = "Resource ID of Blob service diagnostics."
  value       = module.storage.blob_diagnostic_setting_id
}

output "storage_queue_properties_id" {
  description = "Resource ID of Queue service logging configuration."
  value       = module.storage.queue_properties_id
}

output "storage_queue_diagnostic_setting_id" {
  description = "Resource ID of Queue Azure Monitor diagnostics."
  value       = module.storage.queue_diagnostic_setting_id
}
