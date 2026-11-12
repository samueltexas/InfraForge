# Store secrets in Azure Key Vault without embedding secret values in Terraform.
resource "azurerm_key_vault" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id

  sku_name = "standard"

  # Use Azure RBAC instead of legacy Key Vault access policies.
  rbac_authorization_enabled = true

  # Deny public network access by default.
  # Private connectivity must be configured separately.
  public_network_access_enabled = false

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
