variable "name" {
  description = "Name of the Azure Resource Group."
  type        = string

  validation {
    condition = (
      length(var.name) >= 1 &&
      length(var.name) <= 90 &&
      can(regex("^[A-Za-z0-9._()-]+$", var.name)) &&
      !endswith(var.name, ".")
    )

    error_message = "Resource Group names must contain 1-90 valid characters and cannot end with a period."
  }
}

variable "location" {
  description = "Azure region where the Resource Group will be created."
  type        = string

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "Azure location cannot be empty."
  }
}

variable "tags" {
  description = "Tags applied to the Resource Group."
  type        = map(string)
  default     = {}
}
