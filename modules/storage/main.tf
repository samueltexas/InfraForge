locals {
  blob_private_dns_zone_name = "privatelink.blob.core.windows.net"

  blob_private_dns_zone_id = (
    var.create_blob_private_dns_zone
    ? azurerm_private_dns_zone.blob[0].id
    : var.existing_blob_private_dns_zone_id
  )
}

resource "azurerm_storage_account" "this" {
  #checkov:skip=CKV_AZURE_33: Queue audit logging uses legacy analytics or Azure Monitor diagnostics, selected by enable_legacy_queue_logging.
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.account_replication_type
  access_tier              = "Hot"

  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = false
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  local_user_enabled                = false
  infrastructure_encryption_enabled = true

  # Customer-managed encryption is optional.
  dynamic "identity" {
    for_each = var.storage_encryption_identity_id == null ? [] : [var.storage_encryption_identity_id]

    content {
      type         = "UserAssigned"
      identity_ids = [identity.value]
    }
  }

  dynamic "customer_managed_key" {
    for_each = var.key_vault_key_id == null ? [] : [var.key_vault_key_id]

    content {
      key_vault_key_id          = customer_managed_key.value
      user_assigned_identity_id = var.storage_encryption_identity_id
    }
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.container_soft_delete_retention_days
    }
  }

  tags = var.tags
}

# Assign data-plane permissions to the workload identity, not to account keys.
locals {
  blob_container_role_assignments = {
    for pair in setproduct(var.blob_data_contributor_principal_ids, var.containers) :
    "${pair[0]}:${pair[1]}" => {
      principal_id  = pair[0]
      container_key = pair[1]
    }
  }
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  for_each = local.blob_container_role_assignments

  scope                = azurerm_storage_container.this[each.value.container_key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
}

# Queue logging uses the dedicated resource supported by current AzureRM 4.x.
resource "azurerm_storage_account_queue_properties" "this" {
  count = var.enable_legacy_queue_logging ? 1 : 0

  storage_account_id = azurerm_storage_account.this.id

  logging {
    version               = "1.0"
    read                  = true
    write                 = true
    delete                = true
    retention_policy_days = var.queue_log_retention_days
  }
}

resource "azurerm_storage_container" "this" {
  #checkov:skip=CKV2_AZURE_21: Checkov evaluates Blob read logging through the legacy Storage Insights association. This module uses Azure Monitor diagnostic settings on blobServices/default instead. StorageRead, StorageWrite and StorageDelete are explicitly required and regression-tested. Blob containers remain private and Shared Key authentication remains disabled.
  for_each = var.containers

  name                  = each.value
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# Create a DNS zone only when the caller has not supplied a shared zone.
resource "azurerm_private_dns_zone" "blob" {
  count = var.create_blob_private_dns_zone ? 1 : 0

  name                = local.blob_private_dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  count = var.create_blob_private_dns_zone ? 1 : 0

  name                  = "link-${var.storage_account_name}-blob"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob[0].name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.storage_account_name}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.storage_account_name}-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [local.blob_private_dns_zone_id]
  }

  tags = var.tags
}

# Send data-plane audit events to the existing Log Analytics workspace.
resource "azurerm_monitor_diagnostic_setting" "blob" {
  name                       = "${var.storage_account_name}-blob-diagnostics"
  target_resource_id         = "${azurerm_storage_account.this.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = var.blob_log_categories
    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "Transaction"
  }
}

# Preserve the address of legacy logging for existing module consumers.
moved {
  from = azurerm_storage_account_queue_properties.this
  to   = azurerm_storage_account_queue_properties.this[0]
}

# ARM-managed diagnostics work without exposing the private Queue data plane.
resource "azurerm_monitor_diagnostic_setting" "queue" {
  count = var.enable_legacy_queue_logging ? 0 : 1

  name                       = "${var.storage_account_name}-queue-diagnostics"
  target_resource_id         = "${azurerm_storage_account.this.id}/queueServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = toset(["StorageRead", "StorageWrite", "StorageDelete"])
    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "Transaction"
  }
}
