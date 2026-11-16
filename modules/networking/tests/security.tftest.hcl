mock_provider "azurerm" {}

run "enforces_default_deny_in_both_directions" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      database    = ["10.40.2.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules     = {}
    management_sources = {}
    outbound_rules     = {}
  }

  assert {
    condition     = length(azurerm_network_security_rule.deny_inbound) == length(var.subnets)
    error_message = "Every subnet must have an explicit inbound deny rule."
  }

  assert {
    condition     = length(azurerm_network_security_rule.deny_outbound) == length(var.subnets)
    error_message = "Every subnet must have an explicit outbound deny rule."
  }

  assert {
    condition     = azurerm_network_security_rule.deny_outbound["application"].access == "Deny"
    error_message = "Unapproved outbound traffic must be denied."
  }
}

run "creates_scoped_outbound_allowlist" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      database    = ["10.40.2.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules = {
      AllowApplicationPostgres = {
        destination_subnet = "database"
        source_prefix      = "10.40.1.0/24"
        destination_port   = "5432"
        priority           = 100
      }
    }

    management_sources = {}

    outbound_rules = {
      AllowApplicationToPostgres = {
        source_subnet      = "application"
        destination_prefix = "10.40.2.0/24"
        destination_port   = "5432"
        protocol           = "Tcp"
        priority           = 100
      }
    }
  }

  assert {
    condition     = azurerm_network_security_rule.allow_outbound["AllowApplicationToPostgres"].access == "Allow"
    error_message = "The explicit application-to-database outbound rule must be allowed."
  }

  assert {
    condition     = azurerm_network_security_rule.allow_outbound["AllowApplicationToPostgres"].destination_address_prefix == "10.40.2.0/24"
    error_message = "Outbound access must be limited to the declared destination CIDR."
  }

  assert {
    condition     = azurerm_network_security_rule.deny_outbound["application"].priority > azurerm_network_security_rule.allow_outbound["AllowApplicationToPostgres"].priority
    error_message = "The default-deny rule must be evaluated after explicit allowlist rules."
  }
}

run "administrative_ssh_targets_management_subnet" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      database    = ["10.40.2.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules = {}

    management_sources = {
      trusted_admin = {
        source_type        = "public_ipv4"
        source_prefix      = "8.8.8.8/32"
        destination_subnet = "management"
        priority           = 110
      }
    }

    outbound_rules = {}
  }

  assert {
    condition = (
      azurerm_network_security_rule.allow_management_ssh["trusted_admin"].network_security_group_name ==
      azurerm_network_security_group.subnet["management"].name
    )
    error_message = "Administrative SSH must terminate on the dedicated management subnet."
  }
}

run "rejects_unrestricted_outbound_destination" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules     = {}
    management_sources = {}

    outbound_rules = {
      AllowAllInternet = {
        source_subnet      = "application"
        destination_prefix = "0.0.0.0/0"
        destination_port   = "443"
        protocol           = "Tcp"
        priority           = 100
      }
    }
  }

  expect_failures = [var.outbound_rules]
}


run "rejects_outbound_prefix_23" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules     = {}
    management_sources = {}

    outbound_rules = {
      AllowTooBroad = {
        source_subnet      = "application"
        destination_prefix = "10.40.2.0/23"
        destination_port   = "443"
        protocol           = "Tcp"
        priority           = 100
      }
    }
  }

  expect_failures = [var.outbound_rules]
}

run "accepts_outbound_prefix_32" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules     = {}
    management_sources = {}

    outbound_rules = {
      AllowSpecificHost = {
        source_subnet      = "application"
        destination_prefix = "8.8.8.8/32"
        destination_port   = "443"
        protocol           = "Tcp"
        priority           = 100
      }
    }
  }

  assert {
    condition = (
      azurerm_network_security_rule.allow_outbound["AllowSpecificHost"].destination_address_prefix
      == "8.8.8.8/32"
    )
    error_message = "A specific IPv4 /32 destination must be accepted."
  }
}


run "accepts_private_rfc1918_vpn_source" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules = {}

    management_sources = {
      corporate_vpn = {
        source_type        = "private_vpn"
        source_prefix      = "10.20.0.0/24"
        destination_subnet = "management"
        priority           = 120
      }
    }

    outbound_rules = {}
  }

  assert {
    condition     = azurerm_network_security_rule.allow_management_ssh["corporate_vpn"].destination_port_range == "22"
    error_message = "Private VPN management access must use SSH."
  }
}

run "rejects_public_private_ipv4_source" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules = {}

    management_sources = {
      invalid_admin = {
        source_type        = "public_ipv4"
        source_prefix      = "10.20.0.1/32"
        destination_subnet = "management"
        priority           = 120
      }
    }

    outbound_rules = {}
  }

  expect_failures = [var.management_sources]
}

run "rejects_non_rfc1918_vpn_source" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules = {}

    management_sources = {
      invalid_vpn = {
        source_type        = "private_vpn"
        source_prefix      = "8.8.8.0/24"
        destination_subnet = "management"
        priority           = 120
      }
    }

    outbound_rules = {}
  }

  expect_failures = [var.management_sources]
}

run "rejects_vpn_prefix_outside_rfc1918_boundary" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules = {}

    management_sources = {
      invalid_vpn = {
        source_type        = "private_vpn"
        source_prefix      = "10.0.0.0/7"
        destination_subnet = "management"
        priority           = 120
      }
    }

    outbound_rules = {}
  }

  expect_failures = [var.management_sources]
}


run "rejects_non_global_public_management_sources" {
  command = plan

  variables {
    resource_group_name = "rg-infraforge-test"
    location            = "westeurope"
    vnet_name           = "vnet-infraforge-test"
    address_space       = ["10.40.0.0/16"]

    subnets = {
      application = ["10.40.1.0/24"]
      management  = ["10.40.3.0/24"]
    }

    security_rules = {}

    management_sources = {
      invalid_0 = {
        source_type        = "public_ipv4"
        source_prefix      = "0.1.2.3/32"
        destination_subnet = "management"
        priority           = 120
      }
      invalid_1 = {
        source_type        = "public_ipv4"
        source_prefix      = "100.64.0.1/32"
        destination_subnet = "management"
        priority           = 121
      }
      invalid_2 = {
        source_type        = "public_ipv4"
        source_prefix      = "127.0.0.1/32"
        destination_subnet = "management"
        priority           = 122
      }
      invalid_3 = {
        source_type        = "public_ipv4"
        source_prefix      = "169.254.1.1/32"
        destination_subnet = "management"
        priority           = 123
      }
      invalid_4 = {
        source_type        = "public_ipv4"
        source_prefix      = "192.0.2.1/32"
        destination_subnet = "management"
        priority           = 124
      }
      invalid_5 = {
        source_type        = "public_ipv4"
        source_prefix      = "192.88.99.1/32"
        destination_subnet = "management"
        priority           = 125
      }
      invalid_6 = {
        source_type        = "public_ipv4"
        source_prefix      = "192.168.1.1/32"
        destination_subnet = "management"
        priority           = 126
      }
      invalid_7 = {
        source_type        = "public_ipv4"
        source_prefix      = "198.18.0.1/32"
        destination_subnet = "management"
        priority           = 127
      }
      invalid_8 = {
        source_type        = "public_ipv4"
        source_prefix      = "198.51.100.1/32"
        destination_subnet = "management"
        priority           = 128
      }
      invalid_9 = {
        source_type        = "public_ipv4"
        source_prefix      = "203.0.113.1/32"
        destination_subnet = "management"
        priority           = 129
      }
      invalid_10 = {
        source_type        = "public_ipv4"
        source_prefix      = "224.0.0.1/32"
        destination_subnet = "management"
        priority           = 130
      }
      invalid_11 = {
        source_type        = "public_ipv4"
        source_prefix      = "240.0.0.1/32"
        destination_subnet = "management"
        priority           = 131
      }
    }

    outbound_rules = {}
  }

  expect_failures = [var.management_sources]
}
