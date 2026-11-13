mock_provider "azurerm" {}

variables {
  storage_account_name = "stinfraforgetest001"
  resource_group_name  = "rg-infraforge-test"
  location             = "westeurope"

  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/private-endpoints"

  virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.Network/virtualNetworks/vnet-test"

  containers = [
    "application-data",
    "backup-data",
    "audit-logs"
  ]

  blob_soft_delete_retention_days      = 14
  container_soft_delete_retention_days = 14

  tags = {
    environment = "test"
    managed_by  = "terraform"
    project     = "infraforge"
  }
}

run "creates_hardened_storage_account" {
  command = plan

  assert {
    condition = (
      azurerm_storage_account.this.account_kind == "StorageV2"
    )
    error_message = "Storage Account must use StorageV2."
  }

  assert {
    condition = (
      azurerm_storage_account.this.public_network_access_enabled == false
    )
    error_message = "Public network access must be disabled."
  }

  assert {
    condition = (
      azurerm_storage_account.this.https_traffic_only_enabled == true
    )
    error_message = "HTTPS traffic must be enforced."
  }

  assert {
    condition = (
      azurerm_storage_account.this.min_tls_version == "TLS1_2"
    )
    error_message = "Minimum TLS version must be TLS 1.2."
  }

  assert {
    condition = (
      azurerm_storage_account.this.shared_access_key_enabled == false
    )
    error_message = "Shared Key authentication must be disabled."
  }

  assert {
    condition = (
      azurerm_storage_account.this.infrastructure_encryption_enabled == true
    )
    error_message = "Infrastructure encryption must be enabled."
  }

  assert {
    condition = (
      azurerm_storage_account.this.allow_nested_items_to_be_public == false
    )
    error_message = "Anonymous public container access must be disabled."
  }

  assert {
    condition = (
      azurerm_storage_account.this.blob_properties[0].versioning_enabled == true
    )
    error_message = "Blob versioning must be enabled."
  }

  assert {
    condition = (
      length(azurerm_storage_container.this) == 3
    )
    error_message = "All three private containers must be created."
  }

  assert {
    condition = (
      azurerm_private_endpoint.blob.private_service_connection[0].subresource_names[0] == "blob"
    )
    error_message = "Private Endpoint must target the Blob subresource."
  }

  assert {
    condition = (
      azurerm_private_dns_zone.blob.name == "privatelink.blob.core.windows.net"
    )
    error_message = "Incorrect Blob Private DNS Zone."
  }
}

run "rejects_invalid_storage_account_name" {
  command = plan

  variables {
    storage_account_name = "Invalid_Storage_Name"
  }

  expect_failures = [
    var.storage_account_name
  ]
}

run "rejects_invalid_blob_retention_period" {
  command = plan

  variables {
    blob_soft_delete_retention_days = 0
  }

  expect_failures = [
    var.blob_soft_delete_retention_days
  ]
}

run "rejects_invalid_container_retention_period" {
  command = plan

  variables {
    container_soft_delete_retention_days = 500
  }

  expect_failures = [
    var.container_soft_delete_retention_days
  ]
}

run "rejects_invalid_container_name" {
  command = plan

  variables {
    containers = ["Invalid_Container"]
  }

  expect_failures = [
    var.containers
  ]
}

run "rejects_invalid_private_endpoint_subnet_id" {
  command = plan

  variables {
    private_endpoint_subnet_id = "/subscriptions/test/subnets/application"
  }

  expect_failures = [
    var.private_endpoint_subnet_id
  ]
}
