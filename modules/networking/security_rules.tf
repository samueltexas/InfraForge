# Explicitly permitted inbound traffic.
resource "azurerm_network_security_rule" "allow_inbound" {
  for_each = var.security_rules

  name                        = each.key
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value.destination_port
  source_address_prefix       = each.value.source_prefix
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnet[each.value.destination_subnet].name
}

# Override Azure's default AllowVNetInBound rule.
# Exceptions must have a lower priority number.
resource "azurerm_network_security_rule" "deny_inbound" {
  for_each = var.subnets

  name                        = "DenyUnapprovedInbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnet[each.key].name
}
