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
