output "identity_id" {
  description = "Azure resource ID of the managed identity."
  value       = azurerm_user_assigned_identity.this.id
}

output "principal_id" {
  description = "Principal ID used for Azure RBAC."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "client_id" {
  description = "Client ID used by workloads to reference this identity."
  value       = azurerm_user_assigned_identity.this.client_id
}
