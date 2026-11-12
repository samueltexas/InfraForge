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

module "keyvault" {
  source = "../../modules/keyvault"

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
