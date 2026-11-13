output "id" {
  description = "Azure resource ID of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "name" {
  description = "Name of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Private IP address assigned to the virtual machine."
  value       = azurerm_network_interface.this.ip_configuration[0].private_ip_address
}

output "network_interface_id" {
  description = "Azure resource ID of the network interface."
  value       = azurerm_network_interface.this.id
}

output "managed_identity_id" {
  description = "Resource ID of the attached managed identity."
  value       = var.managed_identity_id
}
