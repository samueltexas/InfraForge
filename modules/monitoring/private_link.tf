resource "azurerm_monitor_private_link_scope" "this" {
  name                = var.private_link_scope_name
  resource_group_name = var.resource_group_name

  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"

  tags = var.tags
}

resource "azurerm_monitor_private_link_scoped_service" "workspace" {
  name                = "ampls-${var.workspace_name}"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_private_endpoint" "monitoring" {
  name                = var.private_endpoint_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.private_endpoint_name}"
    private_connection_resource_id = azurerm_monitor_private_link_scope.this.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "monitoring-dns"
    private_dns_zone_ids = values(azurerm_private_dns_zone.monitoring)[*].id
  }

  tags = var.tags
}

locals {
  monitoring_private_dns_zones = toset([
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.blob.core.windows.net"
  ])
}

resource "azurerm_private_dns_zone" "monitoring" {
  for_each = local.monitoring_private_dns_zones

  name                = each.value
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitoring" {
  for_each = azurerm_private_dns_zone.monitoring

  name                  = "link-${replace(each.key, ".", "-")}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = var.virtual_network_id

  registration_enabled = false

  tags = var.tags
}
