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

  storage_use_azuread             = true
  resource_provider_registrations = "none"
}

locals {
  resource_group_name = "rg-infraforge-dev"
  location            = "westeurope"

  tags = {
    project     = "InfraForge"
    environment = "development"
    managed_by  = "terraform"
    deployment  = "zero-cost-foundation"
  }
}

module "resource_group" {
  source = "../../modules/resource-group"

  name     = local.resource_group_name
  location = local.location
  tags     = local.tags
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = module.resource_group.name
  location            = "polandcentral"
  vnet_name           = "vnet-infraforge-foundation-dev"

  address_space = ["10.20.0.0/16"]

  subnets = {
    application       = ["10.20.1.0/24"]
    database          = ["10.20.2.0/24"]
    management        = ["10.20.3.0/24"]
    private-endpoints = ["10.20.4.0/24"]
  }

  security_rules     = {}
  management_sources = {}
  outbound_rules     = {}

  tags = local.tags
}

module "identity" {
  source = "../../modules/identity"

  name                = "id-infraforge-foundation-dev"
  location            = "polandcentral"
  resource_group_name = module.resource_group.name

  role_assignments = {}

  tags = local.tags
}
