output "vnet_id" {
  description = "Azure resource ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  description = "Azure resource IDs of the created subnets."
  value = {
    for name, subnet in azurerm_subnet.this :
    name => subnet.id
  }
}
