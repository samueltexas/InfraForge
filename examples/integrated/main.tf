terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Placeholder identifiers are used for offline validation only.
# This example must not be deployed without an approved Azure configuration.
provider "azurerm" {
  features {}

  subscription_id = "00000000-0000-0000-0000-000000000000"
}

locals {
  resource_group_name = "rg-infraforge-dev"
  location            = "westeurope"

  tags = {
    project     = "InfraForge"
    environment = "development"
    managed_by  = "terraform"
  }
}

# Provide a shared network for private Azure service connectivity.
# Create the shared Azure Resource Group.
module "resource_group" {
  source   = "../../modules/resource-group"
  name     = local.resource_group_name
  location = local.location
  tags     = local.tags
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  vnet_name           = "vnet-infraforge-integrated-dev"

  address_space = ["10.20.0.0/16"]

  subnets = {
    application       = ["10.20.1.0/24"]
    database          = ["10.20.2.0/24"]
    management        = ["10.20.3.0/24"]
    private-endpoints = ["10.20.4.0/24"]
  }

  security_rules = {}

  tags = local.tags
}

# Create a user-assigned identity without embedded credentials.
module "identity" {
  source = "../../modules/identity"

  name                = "id-infraforge-integrated-dev"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name

  role_assignments = {}

  tags = local.tags
}

# Grant the managed identity permission to read Key Vault secrets.
module "keyvault" {
  source = "../../modules/keyvault"

  name                = "kv-infraforge-int-dev"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name

  # Placeholder tenant ID for local validation only.
  tenant_id = "00000000-0000-0000-0000-000000000000"

  reader_principal_ids = [
    module.identity.principal_id
  ]

  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]
  virtual_network_id         = module.networking.vnet_id

  tags = local.tags
}

# Collect Key Vault diagnostics and configure private monitoring access.
module "monitoring" {
  source = "../../modules/monitoring"

  workspace_name      = "law-infraforge-integrated-dev"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name

  diagnostic_target_id = module.keyvault.key_vault_id

  log_categories    = ["AuditEvent"]
  metric_categories = ["AllMetrics"]
  retention_days    = 30

  alert_target_id  = module.keyvault.key_vault_id
  metric_namespace = "Microsoft.KeyVault/vaults"
  metric_name      = "Availability"
  alert_threshold  = 80

  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]
  virtual_network_id         = module.networking.vnet_id

  tags = local.tags
}
