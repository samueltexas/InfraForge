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
      contains(flatten(values(var.subnets)), rule.source_prefix) &&
      rule.priority >= 100 &&
      rule.priority < 4000 &&
      can(tonumber(rule.destination_port)) &&
      tonumber(rule.destination_port) >= 1 &&
      tonumber(rule.destination_port) <= 65535 &&
      !contains([22, 3389], tonumber(rule.destination_port))
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
      source.destination_subnet == "management" &&
      contains(keys(var.subnets), source.destination_subnet) &&
      contains(["public_ipv4", "private_vpn"], source.source_type) &&
      can(cidrnetmask(source.source_prefix)) &&
      try(
        cidrsubnet(source.source_prefix, 0, 0) == source.source_prefix,
        false
      ) &&
      source.priority >= 100 &&
      source.priority < 4000 &&
      (
        source.source_type == "public_ipv4" ?
        try(
          tonumber(split("/", source.source_prefix)[1]) == 32,
          false
        ) &&
        !can(regex(
          "^(0[.]|10[.]|100[.](6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])[.]|127[.]|169[.]254[.]|172[.](1[6-9]|2[0-9]|3[01])[.]|192[.](0[.](0|2)[.]|88[.]99[.]|168[.])|198[.](18|19)[.]|198[.]51[.]100[.]|203[.]0[.]113[.]|22[4-9][.]|23[0-9][.]|24[0-9][.]|25[0-5][.])",
          split("/", source.source_prefix)[0]
        )) :
        (
          can(regex(
            "^(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[0-1])\\.)",
            split("/", source.source_prefix)[0]
          )) &&
          (
            startswith(source.source_prefix, "10.") ?
            try(tonumber(split("/", source.source_prefix)[1]) >= 8, false) :
            startswith(source.source_prefix, "192.168.") ?
            try(tonumber(split("/", source.source_prefix)[1]) >= 16, false) :
            try(tonumber(split("/", source.source_prefix)[1]) >= 12, false)
          )
        )
      )
    ])

    error_message = "Management sources must use canonical IPv4 CIDRs. Public sources must use /32 and must not belong to RFC1918 ranges. VPN sources must be contained within RFC1918 ranges. All sources must target the management subnet."
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


# Explicit outbound exceptions to the default-deny egress policy.
variable "outbound_rules" {
  description = "Allowlisted outbound connections from managed subnets to specific IPv4 destinations."

  type = map(object({
    source_subnet      = string
    destination_prefix = string
    destination_port   = string
    protocol           = string
    priority           = number
  }))

  default = {}

  validation {
    condition = alltrue([
      for name, rule in var.outbound_rules :
      contains(keys(var.subnets), rule.source_subnet) &&
      can(cidrnetmask(rule.destination_prefix)) &&
      try(tonumber(split("/", rule.destination_prefix)[1]) >= 24, false) &&
      contains(["Tcp", "Udp"], rule.protocol) &&
      can(tonumber(rule.destination_port)) &&
      tonumber(rule.destination_port) >= 1 &&
      tonumber(rule.destination_port) <= 65535 &&
      rule.priority >= 100 &&
      rule.priority < 4000
    ])

    error_message = "Outbound rules must target an existing source subnet, an IPv4 CIDR with prefix /24 through /32, TCP or UDP port 1-65535, and priority 100-3999."
  }

  validation {
    condition = alltrue([
      for name, rule in var.outbound_rules :
      length([
        for other_name, other_rule in var.outbound_rules :
        other_name
        if other_rule.source_subnet == rule.source_subnet &&
        other_rule.priority == rule.priority
      ]) == 1
    ])

    error_message = "Outbound rule priorities must be unique within each source subnet."
  }
}
