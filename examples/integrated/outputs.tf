output "virtual_network_id" {
  description = "Resource ID of the shared virtual network."
  value       = module.networking.vnet_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the managed identity."
  value       = module.identity.principal_id
}

output "key_vault_id" {
  description = "Resource ID of the private Key Vault."
  value       = module.keyvault.key_vault_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
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
