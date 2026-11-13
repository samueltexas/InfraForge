output "id" {
  description = "Azure Resource Group resource ID."
  value       = azurerm_resource_group.this.id
}

output "name" {
  description = "Azure Resource Group name."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure Resource Group location."
  value       = azurerm_resource_group.this.location
}
