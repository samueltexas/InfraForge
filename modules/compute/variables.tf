variable "vm_name" {
  description = "Name of the Azure Linux virtual machine."
  type        = string

  validation {
    condition = (
      length(var.vm_name) >= 1 &&
      length(var.vm_name) <= 64 &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$|^[A-Za-z0-9]$", var.vm_name))
    )

    error_message = "VM name must contain 1-64 alphanumeric characters or hyphens and cannot start or end with a hyphen."
  }
}

variable "location" {
  description = "Azure region for the virtual machine."
  type        = string

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "Azure location cannot be empty."
  }
}

variable "resource_group_name" {
  description = "Existing Azure Resource Group name."
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the existing application subnet."
  type        = string
}

variable "managed_identity_id" {
  description = "Resource ID of the existing user-assigned managed identity."
  type        = string
}

variable "admin_username" {
  description = "Linux administrator username."
  type        = string

  validation {
    condition = (
      can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.admin_username)) &&
      !contains(["root", "administrator"], var.admin_username)
    )

    error_message = "Provide a valid non-privileged Linux administrator username."
  }
}

variable "admin_ssh_public_key" {
  description = "Public SSH key used for administrator authentication."
  type        = string

  validation {
    condition = can(regex(
      "^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp[0-9]+) ",
      trimspace(var.admin_ssh_public_key)
    ))

    error_message = "Provide a valid OpenSSH public key."
  }
}

variable "vm_size" {
  description = "Azure virtual machine size."
  type        = string
  default     = "Standard_B2s"

  validation {
    condition     = length(trimspace(var.vm_size)) > 0
    error_message = "VM size cannot be empty."
  }
}

variable "os_disk_size_gb" {
  description = "Operating system disk size in GB."
  type        = number
  default     = 64

  validation {
    condition = (
      var.os_disk_size_gb >= 30 &&
      var.os_disk_size_gb <= 4095 &&
      floor(var.os_disk_size_gb) == var.os_disk_size_gb
    )

    error_message = "OS disk size must be a whole number between 30 and 4095 GB."
  }
}

variable "tags" {
  description = "Resource tags for governance."
  type        = map(string)
  default     = {}
}
