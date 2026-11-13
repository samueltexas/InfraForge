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

  default = ["application-data"]

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

    error_message = "Container names must contain 3-63 lowercase letters, numbers, or single hyphens. They cannot start or end with a hyphen."
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

variable "tags" {
  description = "Resource tags for governance and cost management."
  type        = map(string)
  default     = {}
}
