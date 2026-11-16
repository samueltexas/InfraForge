mock_provider "azurerm" {}

variables {
  name                = "kv-infraforge-test-001"
  location            = "westeurope"
  resource_group_name = "rg-infraforge-test"
  tenant_id           = "00000000-0000-0000-0000-000000000000"

  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Network/virtualNetworks/vnet-infraforge-dev/subnets/private_endpoints"
  virtual_network_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Network/virtualNetworks/vnet-infraforge-dev"
}

run "secure_keyvault_configuration" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled == true
    error_message = "Key Vault must use Azure RBAC."
  }

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == false
    error_message = "Public network access must be disabled."
  }

  assert {
    condition     = azurerm_key_vault.this.purge_protection_enabled == true
    error_message = "Purge protection must be enabled."
  }

  assert {
    condition     = azurerm_key_vault.this.soft_delete_retention_days == 90
    error_message = "Soft delete retention must be 90 days."
  }
}

run "read_only_secret_access" {
  command = plan

  variables {
    reader_principal_ids = [
      "11111111-1111-1111-1111-111111111111"
    ]
  }

  assert {
    condition = alltrue([
      for assignment in azurerm_role_assignment.secrets_reader :
      assignment.role_definition_name == "Key Vault Secrets User"
    ])
    error_message = "Only the approved Key Vault Secrets User role is allowed."
  }

  assert {
    condition     = length(azurerm_role_assignment.secrets_reader) == 1
    error_message = "Exactly one reader assignment is expected."
  }
}

run "reject_invalid_principal_id" {
  command = plan

  variables {
    reader_principal_ids = ["invalid-principal"]
  }

  expect_failures = [
    var.reader_principal_ids
  ]
}

run "reject_invalid_vault_name" {
  command = plan

  variables {
    name = "invalid_keyvault_name"
  }

  expect_failures = [
    var.name
  ]
}


run "storage_customer_managed_key" {
  command = plan

  variables {
    create_storage_encryption_key = true
    allow_trusted_services        = true
    key_encryption_principal_ids  = ["22222222-2222-2222-2222-222222222222"]
  }

  assert {
    condition = (
      azurerm_key_vault_key.storage_encryption[0].key_type == "RSA" &&
      azurerm_key_vault_key.storage_encryption[0].key_size == 2048
    )
    error_message = "Standard CMK must use RSA 2048."
  }

  assert {
    condition = (
      azurerm_key_vault_key.storage_encryption[0].rotation_policy[0].expire_after
      == "P2Y"
    )
    error_message = "Storage encryption key lifetime must be two years."
  }

  assert {
    condition     = azurerm_role_assignment.storage_key_crypto["22222222-2222-2222-2222-222222222222"].role_definition_name == "Key Vault Crypto Service Encryption User"
    error_message = "Storage identity must receive the dedicated CMK role."
  }

  assert {
    condition     = azurerm_key_vault.this.sku_name == "standard"
    error_message = "Storage CMK must use the Standard Key Vault SKU."
  }
}
