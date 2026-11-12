terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Placeholder subscription ID; this example must never be applied as-is.
provider "azurerm" {
  features {}

  subscription_id = "00000000-0000-0000-0000-000000000000"
}

module "identity" {
  source = "../../modules/identity"

  name                = "id-infraforge-dev"
  location            = "westeurope"
  resource_group_name = "rg-infraforge-dev"

  role_assignments = {
    resource_reader = {
      scope     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Storage/storageAccounts/stinfraforgedev"
      role_name = "Reader"
    }
  }

  tags = {
    project     = "InfraForge"
    environment = "dev"
    managed_by  = "terraform"
  }
}
