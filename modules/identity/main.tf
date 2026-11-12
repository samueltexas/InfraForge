# Use a user-assigned identity to avoid application-managed credentials.
resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Grant only explicitly approved read-only permissions.
resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role_name
  principal_id         = azurerm_user_assigned_identity.this.principal_id

  principal_type = "ServicePrincipal"
}
