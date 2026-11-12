variable "name" {
  description = "Name of the user-assigned managed identity."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{2,127}$", var.name))
    error_message = "Identity name must contain 3-128 valid characters."
  }
}

variable "location" {
  description = "Azure region for the managed identity."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group for the managed identity."
  type        = string
}

variable "role_assignments" {
  description = "Approved RBAC role assignments with explicit resource scopes."

  type = map(object({
    scope     = string
    role_name = string
  }))

  default = {}

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) :
      contains([
        "Reader",
        "Monitoring Reader",
        "Storage Blob Data Reader"
      ], assignment.role_name)
    ])

    error_message = "Only approved read-only roles are permitted."
  }

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) :
      can(regex(
        "^/subscriptions/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/resourceGroups/[A-Za-z0-9_.()-]+/providers/[A-Za-z][A-Za-z0-9.]*/[A-Za-z][A-Za-z0-9]*/[A-Za-z0-9_.()-]+(/[A-Za-z][A-Za-z0-9]*/[A-Za-z0-9_.()-]+)*$",
        assignment.scope
      ))
    ])

    error_message = "Assignments require an explicit Azure resource scope."
  }
}

variable "tags" {
  description = "Tags applied to the managed identity."
  type        = map(string)
  default     = {}
}
