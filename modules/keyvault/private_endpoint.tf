# Resolve Key Vault hostnames to private IP addresses inside the VNet.
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "${var.name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = var.virtual_network_id

  registration_enabled = false

  tags = var.tags
}

# Connect the vault to a dedicated subnet without exposing its public endpoint.
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name}-connection"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }

  tags = var.tags
}
