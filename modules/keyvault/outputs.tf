output "key_vault_id" {
  description = "Azure resource ID of the Key Vault."
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "URI used by applications to access Key Vault."
  value       = azurerm_key_vault.this.vault_uri
}

output "private_endpoint_id" {
  description = "Azure resource ID of the Key Vault private endpoint."
  value       = azurerm_private_endpoint.keyvault.id
}


output "storage_encryption_key_id" {
  description = "Versionless Key Vault key ID for Azure Storage CMK, or null when not enabled."
  value       = try(azurerm_key_vault_key.storage_encryption[0].versionless_id, null)
}
