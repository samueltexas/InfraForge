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
