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

output "application_subnet_id" {
  description = "Subnet available for a future application workload."
  value       = module.networking.subnet_ids["application"]
}

output "managed_identity_client_id" {
  description = "Client ID for a future application workload."
  value       = module.identity.client_id
}

output "key_vault_uri" {
  description = "Key Vault URI for application configuration."
  value       = module.keyvault.key_vault_uri
}

output "virtual_machine_id" {
  description = "Resource ID of the application virtual machine."
  value       = module.compute.id
}

output "virtual_machine_name" {
  description = "Name of the application virtual machine."
  value       = module.compute.name
}

output "virtual_machine_private_ip" {
  description = "Private IP address of the application virtual machine."
  value       = module.compute.private_ip_address
}

output "virtual_machine_network_interface_id" {
  description = "Resource ID of the VM network interface."
  value       = module.compute.network_interface_id
}
