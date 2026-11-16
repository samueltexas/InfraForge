variable "name" {
  description = "Globally unique Azure Key Vault name."
  type        = string

  validation {
    condition = (
      length(var.name) >= 3 &&
      length(var.name) <= 24 &&
      can(regex("^[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.name))
    )
    error_message = "Key Vault name must be 3-24 characters, start with a letter, and end with a letter or number."
  }
}

variable "location" {
  description = "Azure region for the Key Vault."
  type        = string
}

variable "resource_group_name" {
  description = "Existing Azure resource group."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string

  validation {
    condition = can(regex(
      "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
      var.tenant_id
    ))
    error_message = "tenant_id must be a valid UUID."
  }
}

variable "reader_principal_ids" {
  description = "Managed identity principal IDs authorized to read Key Vault secrets."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.reader_principal_ids :
      can(regex(
        "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
        id
      ))
    ])
    error_message = "Every reader principal ID must be a valid UUID."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "private_endpoint_subnet_id" {
  description = "Azure subnet resource ID for the Key Vault private endpoint."
  type        = string

  validation {
    condition = can(regex(
      "^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$",
      var.private_endpoint_subnet_id
    ))
    error_message = "Provide a valid Azure subnet resource ID."
  }
}

variable "virtual_network_id" {
  description = "Azure virtual network resource ID for private DNS resolution."
  type        = string

  validation {
    condition = can(regex(
      "^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$",
      var.virtual_network_id
    ))
    error_message = "Provide a valid Azure virtual network resource ID."
  }
}


variable "create_storage_encryption_key" {
  description = "Create an RSA key for Azure Storage customer-managed encryption."
  type        = bool
  default     = false
}


variable "storage_encryption_key_name" {
  description = "Name of the optional Storage customer-managed encryption key."
  type        = string
  default     = "infraforge-storage-cmk"

  validation {
    condition = (
      length(var.storage_encryption_key_name) >= 1 &&
      length(var.storage_encryption_key_name) <= 127 &&
      can(regex("^[A-Za-z0-9-]+$", var.storage_encryption_key_name))
    )
    error_message = "Key name must contain 1-127 letters, numbers, or hyphens."
  }
}

variable "key_encryption_principal_ids" {
  description = "Managed identity principal IDs allowed to use the Storage encryption key."
  type        = set(string)
  default     = []

  validation {
    condition = (
      alltrue([
        for id in var.key_encryption_principal_ids :
        can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))
      ]) &&
      (
        (var.create_storage_encryption_key && length(var.key_encryption_principal_ids) > 0) ||
        (!var.create_storage_encryption_key && length(var.key_encryption_principal_ids) == 0)
      )
    )
    error_message = "Every key encryption principal must be a valid UUID."
  }
}

variable "allow_trusted_services" {
  description = "Allow trusted Azure services through the Key Vault firewall for supported integrations such as Storage CMK."
  type        = bool
  default     = false

  validation {
    condition     = !var.create_storage_encryption_key || var.allow_trusted_services
    error_message = "Trusted Azure services must be allowed when the Storage CMK is enabled."
  }
}
