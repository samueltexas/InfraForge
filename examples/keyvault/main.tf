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

  # Placeholder subscription; no Azure deployment is performed.
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

# Isolated example network with a dedicated private endpoint subnet.
module "networking" {
  source = "../../modules/networking"

  resource_group_name = "rg-infraforge-dev"
  location            = "westeurope"
  vnet_name           = "vnet-infraforge-keyvault-dev"

  address_space = ["10.10.0.0/16"]

  subnets = {
    private_endpoints = ["10.10.4.0/24"]
  }

  security_rules = {}

  tags = {
    project     = "InfraForge"
    environment = "development"
    managed_by  = "terraform"
  }
}

module "keyvault" {
  source = "../../modules/keyvault"

  private_endpoint_subnet_id = module.networking.subnet_ids["private_endpoints"]
  virtual_network_id         = module.networking.vnet_id

  name                = "kv-infraforge-dev-001"
  location            = "westeurope"
  resource_group_name = "rg-infraforge-dev"

  # Placeholder tenant; replace only in an authorized deployment environment.
  tenant_id = "00000000-0000-0000-0000-000000000000"

  # In a real composition, pass module.identity.principal_id here.
  reader_principal_ids = [
    "11111111-1111-1111-1111-111111111111"
  ]

  tags = {
    project     = "InfraForge"
    environment = "development"
    managed_by  = "terraform"
  }
}
