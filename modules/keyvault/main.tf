# Store secrets in Azure Key Vault without embedding secret values in Terraform.
resource "azurerm_key_vault" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id

  # Standard SKU avoids Premium HSM costs.
  sku_name = "standard"

  # Use Azure RBAC instead of legacy Key Vault access policies.
  rbac_authorization_enabled = true

  # Deny public network access by default.
  # Private connectivity must be configured separately.
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = var.allow_trusted_services ? "AzureServices" : "None"
  }

  # Protect the vault from accidental deletion and premature purging.
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  tags = var.tags
}

# Grant managed identities only the permissions required to read secrets.
resource "azurerm_role_assignment" "secrets_reader" {
  for_each = var.reader_principal_ids

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}


# Create a dedicated RSA key only when Storage CMK integration is requested.
resource "azurerm_key_vault_key" "storage_encryption" {
  count = var.create_storage_encryption_key ? 1 : 0

  name         = var.storage_encryption_key_name
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["unwrapKey", "wrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P2Y"
    notify_before_expiry = "P30D"
  }
}

# Grant only the Storage encryption identity the required cryptographic operations.
resource "azurerm_role_assignment" "storage_key_crypto" {
  for_each = var.create_storage_encryption_key ? var.key_encryption_principal_ids : toset([])

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}
