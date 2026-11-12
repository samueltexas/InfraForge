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
