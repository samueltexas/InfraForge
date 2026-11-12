terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  # Placeholder only. No Azure deployment is performed.
  subscription_id = "00000000-0000-0000-0000-000000000000"
}


module "networking" {
  source = "../../modules/networking"

  resource_group_name = "rg-infraforge-dev"
  location            = "westeurope"
  vnet_name           = "vnet-infraforge-dev"
  address_space       = ["10.10.0.0/16"]

  subnets = {
    application       = ["10.10.1.0/24"]
    database          = ["10.10.2.0/24"]
    management        = ["10.10.3.0/24"]
    private-endpoints = ["10.10.4.0/24"]
  }

  tags = {
    project     = "InfraForge"
    environment = "dev"
    managed_by  = "terraform"
  }
}

module "monitoring" {
  virtual_network_id         = module.networking.vnet_id
  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]

  source = "../../modules/monitoring"

  workspace_name      = "law-infraforge-dev"
  location            = "westeurope"
  resource_group_name = "rg-infraforge-dev"

  diagnostic_target_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.KeyVault/vaults/kv-infraforge-dev-001"

  log_categories    = ["AuditEvent"]
  metric_categories = ["AllMetrics"]
  retention_days    = 30

  tags = {
    project     = "InfraForge"
    environment = "development"
    managed_by  = "terraform"
  }

  alert_target_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.KeyVault/vaults/kv-infraforge-dev-001"
  metric_namespace = "Microsoft.KeyVault/vaults"
  metric_name      = "Availability"
  alert_threshold  = 80
}
