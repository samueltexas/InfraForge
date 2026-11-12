resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space

  tags = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value
}


# Create a dedicated NSG for each subnet.
# Traffic restrictions will be defined in a separate security phase.
resource "azurerm_network_security_group" "subnet" {
  for_each = var.subnets

  name                = "nsg-${var.vnet_name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Associate each subnet with its corresponding NSG.
resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.subnet[each.key].id
}
