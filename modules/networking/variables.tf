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
      contains(keys(var.subnets), rule.destination_subnet) &&
      can(cidrnetmask(rule.source_prefix)) &&
      rule.priority >= 100 &&
      rule.priority < 4000 &&
      can(tonumber(rule.destination_port)) &&
      tonumber(rule.destination_port) >= 1 &&
      tonumber(rule.destination_port) <= 65535 &&
      !contains(["22", "3389"], rule.destination_port)
    ])

    error_message = "Generic rules must target existing subnets, use valid IPv4 CIDRs, TCP ports 1-65535, priorities 100-3999, and must not use SSH or RDP ports."
  }

  validation {
    condition = alltrue([
      for name, rule in var.security_rules :
      length([
        for other_name, other_rule in var.security_rules :
        other_name
        if other_rule.destination_subnet == rule.destination_subnet &&
        other_rule.priority == rule.priority
      ]) == 1
    ])

    error_message = "Security rule priorities must be unique within each destination subnet."
  }
}


variable "management_sources" {
  description = "Authorized public IPv4 and private VPN sources for administrative SSH."

  type = map(object({
    source_type        = string
    source_prefix      = string
    destination_subnet = string
    priority           = number
  }))

  default = {}

  validation {
    condition = alltrue([
      for name, source in var.management_sources :
      source.destination_subnet == "application" &&
      contains(keys(var.subnets), source.destination_subnet) &&
      contains(["public_ipv4", "private_vpn"], source.source_type) &&
      can(cidrnetmask(source.source_prefix)) &&
      source.priority >= 100 &&
      source.priority < 4000 &&
      (
        source.source_type == "public_ipv4" ?
        try(
          tonumber(split("/", source.source_prefix)[1]) == 32 &&
          alltrue([
            for reserved in [
              "0.0.0.0/8",
              "10.0.0.0/8",
              "100.64.0.0/10",
              "127.0.0.0/8",
              "169.254.0.0/16",
              "172.16.0.0/12",
              "192.0.0.0/24",
              "192.0.2.0/24",
              "192.88.99.0/24",
              "192.168.0.0/16",
              "198.18.0.0/15",
              "198.51.100.0/24",
              "203.0.113.0/24",
              "224.0.0.0/4",
              "240.0.0.0/4"
            ] :
            !cidrcontains(reserved, cidrhost(source.source_prefix, 0))
          ]),
          false
        ) :
        try(
          anytrue([
            for private_range in [
              "10.0.0.0/8",
              "172.16.0.0/12",
              "192.168.0.0/16"
            ] :
            cidrcontains(private_range, cidrhost(source.source_prefix, 0)) &&
            cidrcontains(private_range, cidrhost(source.source_prefix, -1))
          ]),
          false
        )
      )
    ])

    error_message = "Public management sources must be globally routable IPv4 /32 addresses. VPN sources must be valid RFC1918 CIDRs. All sources must target an existing subnet."
  }

  validation {
    condition = alltrue([
      for name, source in var.management_sources :
      length([
        for other_name, other_source in var.management_sources :
        other_name
        if other_source.destination_subnet == source.destination_subnet &&
        other_source.priority == source.priority
      ]) +
      length([
        for other_name, other_rule in var.security_rules :
        other_name
        if other_rule.destination_subnet == source.destination_subnet &&
        other_rule.priority == source.priority
      ]) == 1
    ])

    error_message = "Management and security rule priorities must be unique within each destination subnet."
  }
}
