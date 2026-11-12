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
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = "rg-infraforge-dev"
  location            = "westeurope"
  vnet_name           = "vnet-infraforge-dev"

  address_space = ["10.10.0.0/16"]


  # Explicit inbound exceptions; all other inbound traffic is denied.
  security_rules = {
    AllowManagementSSH = {
      destination_subnet = "application"
      source_prefix      = "10.10.3.0/24"
      destination_port   = "22"
      priority           = 100
    }

    AllowApplicationPostgres = {
      destination_subnet = "database"
      source_prefix      = "10.10.1.0/24"
      destination_port   = "5432"
      priority           = 100
    }
  }

  subnets = {
    application = ["10.10.1.0/24"]
    database    = ["10.10.2.0/24"]
    management  = ["10.10.3.0/24"]
  }

  tags = {
    project     = "InfraForge"
    environment = "dev"
    managed_by  = "terraform"
  }
}
