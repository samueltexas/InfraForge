terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Developer workload infrastructure reference.
# Placeholder identifiers are used for offline validation only.
# This example must not be deployed without an approved Azure configuration.
provider "azurerm" {
  features {}

  subscription_id = "00000000-0000-0000-0000-000000000000"
}

locals {
  location = "westeurope"

  tags = {
    project     = "InfraForge"
    environment = "development"
    managed_by  = "terraform"
  }
}

# Create the shared Azure Resource Group.
module "resource_group" {
  source   = "../../modules/resource-group"
  name     = "rg-infraforge-dev"
  location = local.location
  tags     = local.tags
}

# Provide a shared network for private Azure service connectivity.
module "networking" {
  source = "../../modules/networking"

  resource_group_name = module.resource_group.name
  location            = local.location
  vnet_name           = "vnet-infraforge-workload-dev"

  address_space = ["10.30.0.0/16"]

  subnets = {
    application       = ["10.30.1.0/24"]
    database          = ["10.30.2.0/24"]
    management        = ["10.30.3.0/24"]
    private-endpoints = ["10.30.4.0/24"]
  }

  security_rules = {}

  tags = local.tags
}

# Create a user-assigned identity without embedded credentials.
module "identity" {
  source = "../../modules/identity"

  name                = "id-infraforge-workload-dev"
  location            = local.location
  resource_group_name = module.resource_group.name

  role_assignments = {}

  tags = local.tags
}

# Grant the managed identity permission to read Key Vault secrets.
module "keyvault" {
  source = "../../modules/keyvault"

  name                = "kv-infraforge-workload"
  location            = local.location
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

  workspace_name      = "law-infraforge-workload-dev"
  location            = local.location
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

# Deploy a private Linux application virtual machine.
module "compute" {
  source = "../../modules/compute"

  vm_name             = "vm-infraforge-workload-dev"
  location            = local.location
  resource_group_name = module.resource_group.name

  subnet_id           = module.networking.subnet_ids["application"]
  managed_identity_id = module.identity.identity_id

  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key

  vm_size         = "Standard_B2s"
  os_disk_size_gb = 64

  tags = local.tags
}


# Store application data using private Blob Storage.
module "storage" {
  source = "../../modules/storage"

  storage_account_name = "stinfraforgedev01"
  resource_group_name  = module.resource_group.name
  location             = local.location

  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]
  virtual_network_id         = module.networking.vnet_id

  containers = [
    "application-data",
    "backup-data",
    "audit-logs"
  ]

  blob_soft_delete_retention_days      = 14
  container_soft_delete_retention_days = 14

  tags = local.tags
}
