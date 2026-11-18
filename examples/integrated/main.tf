terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {
    storage {
      data_plane_available = false
    }
  }
  storage_use_azuread = true
}

data "azurerm_client_config" "current" {}

locals {
  location = "polandcentral"

  tags = {
    project     = "InfraForge"
    environment = "development"
    managed_by  = "terraform"
  }
}

# Reuse the deployed foundation infrastructure.
data "azurerm_resource_group" "foundation" {
  name = "rg-infraforge-dev"
}

data "azurerm_virtual_network" "foundation" {
  name                = "vnet-infraforge-foundation-dev"
  resource_group_name = data.azurerm_resource_group.foundation.name
}

data "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints"
  virtual_network_name = data.azurerm_virtual_network.foundation.name
  resource_group_name  = data.azurerm_resource_group.foundation.name
}

data "azurerm_user_assigned_identity" "foundation" {
  name                = "id-infraforge-foundation-dev"
  resource_group_name = data.azurerm_resource_group.foundation.name
}

# Private secrets management.
module "keyvault" {
  source = "../../modules/keyvault"

  name                = "kv-infraforge-int-dev"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.foundation.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  reader_principal_ids = [
    data.azurerm_user_assigned_identity.foundation.principal_id
  ]

  private_endpoint_subnet_id = data.azurerm_subnet.private_endpoints.id
  virtual_network_id         = data.azurerm_virtual_network.foundation.id

  tags = local.tags
}

# Centralized monitoring and private connectivity.
module "monitoring" {
  source = "../../modules/monitoring"

  workspace_name      = "law-infraforge-integrated-dev"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.foundation.name

  diagnostic_target_id = module.keyvault.key_vault_id

  log_categories    = ["AuditEvent"]
  metric_categories = ["AllMetrics"]
  retention_days    = 30

  alert_target_id  = module.keyvault.key_vault_id
  metric_namespace = "Microsoft.KeyVault/vaults"
  metric_name      = "Availability"
  alert_threshold  = 80

  private_endpoint_subnet_id = data.azurerm_subnet.private_endpoints.id
  virtual_network_id         = data.azurerm_virtual_network.foundation.id

  tags = local.tags
}

# Private application data storage.
module "storage" {
  source = "../../modules/storage"

  storage_account_name = "stinfraforgeint01"
  resource_group_name  = data.azurerm_resource_group.foundation.name
  location             = local.location

  private_endpoint_subnet_id = data.azurerm_subnet.private_endpoints.id
  virtual_network_id         = data.azurerm_virtual_network.foundation.id

  existing_blob_private_dns_zone_id = module.monitoring.blob_private_dns_zone_id
  create_blob_private_dns_zone      = false

  blob_data_contributor_principal_ids = [
    data.azurerm_user_assigned_identity.foundation.principal_id
  ]

  log_analytics_workspace_id = module.monitoring.workspace_id

  # Poland Central supports LRS; use it for this credit-funded demonstration.
  account_replication_type    = "LRS"
  enable_legacy_queue_logging = false

  containers = [
    "application-data",
    "backup-data",
    "audit-logs"
  ]

  blob_soft_delete_retention_days      = 14
  container_soft_delete_retention_days = 14

  tags = local.tags

  depends_on = [
    module.keyvault,
    module.monitoring
  ]
}
