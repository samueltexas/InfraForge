variable "resource_group_name" {
  description = "Existing Azure resource group name."
  type        = string
}

variable "location" {
  description = "Azure region for network resources."
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network."
  type        = string
}

variable "address_space" {
  description = "CIDR address spaces assigned to the VNet."
  type        = list(string)

  validation {
    condition = (
      length(var.address_space) > 0 &&
      alltrue([
        for cidr in var.address_space : can(cidrnetmask(cidr))
      ])
    )
    error_message = "Provide at least one valid IPv4 CIDR."
  }
}

variable "subnets" {
  description = "Map of subnet names to IPv4 CIDR prefixes."
  type        = map(list(string))
  default     = {}
}

variable "tags" {
  description = "Resource tags used for governance."
  type        = map(string)
  default     = {}
}

# Explicit inbound exceptions to the default-deny policy.
variable "security_rules" {
  description = "Allowed inbound connections between managed subnets."

  type = map(object({
    destination_subnet = string
    source_prefix      = string
    destination_port   = string
    priority           = number
  }))

  default = {}

  validation {
    condition = alltrue([
      for name, rule in var.security_rules :
      contains(keys(var.subnets), rule.destination_subnet)
      && can(cidrnetmask(rule.source_prefix))
      && rule.priority >= 100
      && rule.priority < 4000
      && can(tonumber(rule.destination_port))
      && tonumber(rule.destination_port) >= 1
      && tonumber(rule.destination_port) <= 65535
    ])
    error_message = "Security rules must target existing subnets, use IPv4 CIDRs, TCP ports 1-65535, and priorities 100-3999."
  }
}
