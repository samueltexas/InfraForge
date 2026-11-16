# Inbound traffic is permitted only through explicit, validated allowlist entries.
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

# Administrative SSH terminates on the dedicated management subnet, never on application subnets.
resource "azurerm_network_security_rule" "allow_management_ssh" {
  for_each = var.management_sources

  name                        = "AllowManagementSSH-${each.key}"
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = each.value.source_prefix
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnet["management"].name
}

# Outbound traffic is permitted only through explicit, validated allowlist entries.
resource "azurerm_network_security_rule" "allow_outbound" {
  for_each = var.outbound_rules

  name                        = each.key
  priority                    = each.value.priority
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = each.value.protocol
  source_port_range           = "*"
  destination_port_range      = each.value.destination_port
  source_address_prefix       = "*"
  destination_address_prefix  = each.value.destination_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnet[each.value.source_subnet].name
}

# Explicit deny rules override Azure's default AllowVNetInBound and AllowVNetOutBound rules.
# All approved allowlist entries must use a lower priority number (100-3999).
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

resource "azurerm_network_security_rule" "deny_outbound" {
  for_each = var.subnets

  name                        = "DenyUnapprovedOutbound"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnet[each.key].name
}
