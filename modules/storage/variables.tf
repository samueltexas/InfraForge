variable "storage_account_name" {
  description = "Globally unique Azure Storage Account name."
  type        = string

  validation {
    condition = (
      length(var.storage_account_name) >= 3 &&
      length(var.storage_account_name) <= 24 &&
      can(regex("^[a-z0-9]+$", var.storage_account_name))
    )
    error_message = "Storage Account names must contain 3-24 lowercase letters and numbers."
  }
}

variable "resource_group_name" {
  description = "Existing Azure resource group name."
  type        = string
}

variable "location" {
  description = "Azure region for the Storage Account and Private Endpoint."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Resource ID of the dedicated Private Endpoint subnet."
  type        = string

  validation {
    condition = can(regex(
      "^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$",
      var.private_endpoint_subnet_id
    ))
    error_message = "A valid Azure subnet resource ID is required."
  }
}

variable "virtual_network_id" {
  description = "Resource ID of the Virtual Network hosting the private endpoint."
  type        = string

  validation {
    condition = can(regex(
      "^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$",
      var.virtual_network_id
    ))
    error_message = "A valid Azure Virtual Network resource ID is required."
  }
}

variable "containers" {
  description = "Names of private Blob Storage containers."
  type        = set(string)
  default     = ["application-data"]

  validation {
    condition = (
      length(var.containers) > 0 &&
      alltrue([
        for name in var.containers :
        length(name) >= 3 &&
        length(name) <= 63 &&
        can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", name))
      ])
    )
    error_message = "Container names must contain 3-63 lowercase letters, numbers, or single hyphens."
  }
}

variable "account_replication_type" {
  description = "Azure Storage redundancy. GRS is the hardened default; select a region-supported SKU."
  type        = string
  default     = "GRS"

  validation {
    condition = contains(
      ["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"],
      var.account_replication_type
    )
    error_message = "Unsupported Storage replication type."
  }
}

variable "blob_soft_delete_retention_days" {
  description = "Number of days deleted blobs remain recoverable."
  type        = number
  default     = 14

  validation {
    condition = (
      var.blob_soft_delete_retention_days >= 1 &&
      var.blob_soft_delete_retention_days <= 365 &&
      floor(var.blob_soft_delete_retention_days) == var.blob_soft_delete_retention_days
    )
    error_message = "Blob soft delete retention must be a whole number between 1 and 365 days."
  }
}

variable "container_soft_delete_retention_days" {
  description = "Number of days deleted containers remain recoverable."
  type        = number
  default     = 14

  validation {
    condition = (
      var.container_soft_delete_retention_days >= 1 &&
      var.container_soft_delete_retention_days <= 365 &&
      floor(var.container_soft_delete_retention_days) == var.container_soft_delete_retention_days
    )
    error_message = "Container soft delete retention must be a whole number between 1 and 365 days."
  }
}

variable "key_vault_key_id" {
  description = "Optional versionless Key Vault key ID used for Storage CMK."
  type        = string
  default     = null

  validation {
    condition = (
      (var.key_vault_key_id == null && var.storage_encryption_identity_id == null) ||
      (var.key_vault_key_id != null && var.storage_encryption_identity_id != null)
    )
    error_message = "Storage CMK key ID and encryption identity must either both be configured or both be null."
  }
}

variable "storage_encryption_identity_id" {
  description = "Optional user-assigned managed identity resource ID used by Storage CMK."
  type        = string
  default     = null
}

variable "blob_data_contributor_principal_ids" {
  description = "Managed identity principal IDs allowed to manage Blob data in this Storage Account."
  type        = set(string)

  validation {
    condition = (
      length(var.blob_data_contributor_principal_ids) > 0 &&
      alltrue([
        for id in var.blob_data_contributor_principal_ids :
        can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))
      ])
    )
    error_message = "At least one valid managed identity principal UUID is required."
  }
}

variable "log_analytics_workspace_id" {
  description = "Existing Log Analytics Workspace resource ID receiving Blob diagnostics."
  type        = string
}

variable "blob_log_categories" {
  description = "Blob service diagnostic log categories sent to Log Analytics."
  type        = set(string)
  default     = ["StorageRead", "StorageWrite", "StorageDelete"]

  validation {
    condition = alltrue([
      for required_category in [
        "StorageRead",
        "StorageWrite",
        "StorageDelete"
      ] : contains(var.blob_log_categories, required_category)
    ])
    error_message = "Blob logging must include StorageRead, StorageWrite and StorageDelete."
  }
}

variable "create_blob_private_dns_zone" {
  description = "Whether this module owns and creates the Blob Private DNS Zone."
  type        = bool
  default     = true
}

variable "existing_blob_private_dns_zone_id" {
  description = "Optional existing Blob Private DNS Zone ID. Supply this when a shared DNS zone is already managed by another module."
  type        = string
  default     = null
}

variable "queue_log_retention_days" {
  description = "Retention for legacy Queue service analytics logs."
  type        = number
  default     = 7

  validation {
    condition = (
      var.queue_log_retention_days >= 1 &&
      var.queue_log_retention_days <= 365 &&
      floor(var.queue_log_retention_days) == var.queue_log_retention_days
    )
    error_message = "Queue log retention must be a whole number between 1 and 365 days."
  }
}

variable "tags" {
  description = "Resource tags for governance and cost management."
  type        = map(string)
  default     = {}
}

variable "enable_legacy_queue_logging" {
  description = "Use legacy Queue analytics (requires private Queue connectivity); false uses Azure Monitor diagnostics with workspace retention."
  type        = bool
  default     = true
}
