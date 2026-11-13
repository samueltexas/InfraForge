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
    for name, container in azurerm_storage_container.this :
    name => container.id
  }
}

output "private_endpoint_id" {
  description = "Azure resource ID of the Blob Private Endpoint."
  value       = azurerm_private_endpoint.blob.id
}

output "private_dns_zone_id" {
  description = "Azure resource ID of the Blob Private DNS Zone."
  value       = azurerm_private_dns_zone.blob.id
}

output "private_dns_zone_name" {
  description = "Private DNS Zone domain name."
  value       = azurerm_private_dns_zone.blob.name
}
