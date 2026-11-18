mock_provider "azurerm" {}

variables {
  storage_account_name = "stinfraforgetest001"
  resource_group_name  = "rg-infraforge-test"
  location             = "westeurope"

  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/private-endpoints"
  virtual_network_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.Network/virtualNetworks/vnet-test"

  containers                           = ["application-data", "backup-data", "audit-logs"]
  blob_soft_delete_retention_days      = 14
  container_soft_delete_retention_days = 14

  blob_data_contributor_principal_ids = ["11111111-1111-1111-1111-111111111111"]
  log_analytics_workspace_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.OperationalInsights/workspaces/law-test"

  tags = {
    environment = "test"
    managed_by  = "terraform"
    project     = "infraforge"
  }
}

run "creates_hardened_storage_account" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.account_kind == "StorageV2"
    error_message = "Storage Account must use StorageV2."
  }
  assert {
    condition     = azurerm_storage_account.this.account_replication_type == "GRS"
    error_message = "Storage Account must use geo-redundant replication by default."
  }
  assert {
    condition     = azurerm_storage_account.this.public_network_access_enabled == false
    error_message = "Public network access must be disabled."
  }
  assert {
    condition     = azurerm_storage_account.this.https_traffic_only_enabled == true
    error_message = "HTTPS traffic must be enforced."
  }
  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2"
    error_message = "Minimum TLS version must be TLS 1.2."
  }
  assert {
    condition     = azurerm_storage_account.this.shared_access_key_enabled == false
    error_message = "Shared Key authentication must be disabled."
  }
  assert {
    condition     = azurerm_storage_account.this.infrastructure_encryption_enabled == true
    error_message = "Infrastructure encryption must be enabled."
  }
  assert {
    condition     = length(azurerm_storage_account.this.customer_managed_key) == 0
    error_message = "Customer-managed encryption must be disabled by default."
  }
  assert {
    condition     = length(azurerm_storage_account.this.identity) == 0
    error_message = "A user-assigned encryption identity must not be created by default."
  }
  assert {
    condition     = azurerm_storage_container.this["application-data"].container_access_type == "private"
    error_message = "Blob containers must remain private."
  }
  assert {
    condition     = azurerm_private_endpoint.blob.private_service_connection[0].subresource_names[0] == "blob"
    error_message = "Private Endpoint must target the Blob subresource."
  }
  assert {
    condition = (
      azurerm_monitor_diagnostic_setting.blob.log_analytics_workspace_id
      == var.log_analytics_workspace_id
    )
    error_message = "Blob diagnostics must use the approved Log Analytics workspace."
  }

  assert {
    condition = alltrue([
      for required_category in [
        "StorageRead",
        "StorageWrite",
        "StorageDelete"
        ] : contains(
        [
          for log in azurerm_monitor_diagnostic_setting.blob.enabled_log :
          log.category
        ],
        required_category
      )
    ])
    error_message = "Blob Read, Write and Delete audit logging must remain enabled."
  }

  assert {
    condition     = azurerm_storage_account_queue_properties.this[0].logging[0].read && azurerm_storage_account_queue_properties.this[0].logging[0].write && azurerm_storage_account_queue_properties.this[0].logging[0].delete
    error_message = "Queue service read, write and delete logging must be enabled."
  }
  assert {
    condition     = length(azurerm_role_assignment.blob_data_contributor) == 3
    error_message = "The workload identity must receive Blob data access on each of the three containers."
  }
}

run "rejects_invalid_storage_account_name" {
  command = plan
  variables { storage_account_name = "Invalid_Storage_Name" }
  expect_failures = [var.storage_account_name]
}

run "rejects_invalid_blob_retention_period" {
  command = plan
  variables { blob_soft_delete_retention_days = 0 }
  expect_failures = [var.blob_soft_delete_retention_days]
}

run "rejects_invalid_container_retention_period" {
  command = plan
  variables { container_soft_delete_retention_days = 500 }
  expect_failures = [var.container_soft_delete_retention_days]
}

run "rejects_invalid_container_name" {
  command = plan
  variables { containers = ["Invalid_Container"] }
  expect_failures = [var.containers]
}

run "rejects_invalid_private_endpoint_subnet_id" {
  command = plan
  variables { private_endpoint_subnet_id = "/subscriptions/test/subnets/application" }
  expect_failures = [var.private_endpoint_subnet_id]
}


run "enables_customer_managed_encryption_when_configured" {
  command = plan

  variables {
    key_vault_key_id               = "https://kv-infraforge-test.vault.azure.net/keys/storage-cmk"
    storage_encryption_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-storage-test"
  }

  assert {
    condition = (
      azurerm_storage_account.this.customer_managed_key[0].key_vault_key_id
      == var.key_vault_key_id
    )
    error_message = "CMK must use the explicitly supplied Key Vault key."
  }

  assert {
    condition = contains(
      azurerm_storage_account.this.identity[0].identity_ids,
      var.storage_encryption_identity_id
    )
    error_message = "CMK must use the explicitly supplied encryption identity."
  }
}

run "private_arm_deployment_preserves_security_and_auditing" {
  command = plan
  variables {
    account_replication_type          = "LRS"
    enable_legacy_queue_logging       = false
    create_blob_private_dns_zone      = false
    existing_blob_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
  }
  assert {
    condition = (
      azurerm_storage_account.this.default_to_oauth_authentication &&
      !azurerm_storage_account.this.local_user_enabled &&
      !azurerm_storage_account.this.shared_access_key_enabled &&
      !azurerm_storage_account.this.public_network_access_enabled
    )
    error_message = "ARM deployment must retain Entra authentication and private-only access."
  }
  assert {
    condition = (
      length(azurerm_storage_account_queue_properties.this) == 0 &&
      length(azurerm_monitor_diagnostic_setting.queue[0].enabled_log) == 3 &&
      azurerm_monitor_diagnostic_setting.queue[0].log_analytics_workspace_id == var.log_analytics_workspace_id
    )
    error_message = "Queue auditing must use the existing workspace without legacy data-plane operations."
  }
  assert {
    condition = (
      length(azurerm_private_dns_zone.blob) == 0 &&
      length(azurerm_private_dns_zone_virtual_network_link.blob) == 0 &&
      azurerm_private_endpoint.blob.private_dns_zone_group[0].private_dns_zone_ids[0] == var.existing_blob_private_dns_zone_id
    )
    error_message = "The endpoint must reuse the shared DNS zone without creating duplicate zones or links."
  }
}
