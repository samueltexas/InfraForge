package main

import rego.v1

# Extract CIDR prefix length using standard Rego built-ins.
# The calling rules separately validate the CIDR address.
cidr_prefix_length(prefix) := result if {
    parts := split(prefix, "/")
    count(parts) == 2
    result := to_number(parts[1])
}


# NET-001: SSH is exclusively managed through management_sources.
deny contains message if {
    rule := input.security_rules[_]
    rule.direction == "Inbound"
    rule.access == "Allow"
    rule.protocol in {"Tcp", "*"}
    rule.destination_port_range == "22"
    message := sprintf(
        "NET-001: Generic SSH authorization is prohibited: %s",
        [rule.name],
    )
}

# NET-002: RDP is not an approved inbound management protocol.
deny contains message if {
    rule := input.security_rules[_]
    rule.direction == "Inbound"
    rule.access == "Allow"
    rule.protocol in {"Tcp", "*"}
    rule.destination_port_range == "3389"
    message := sprintf(
        "NET-002: RDP inbound access is prohibited: %s",
        [rule.name],
    )
}

# NET-003: Explicit outbound IPv4 destinations must be /24 through /32.
deny contains message if {
    rule := input.outbound_rules[_]
    rule.direction == "Outbound"
    rule.access == "Allow"
    destination := rule.destination_address_prefix
    not valid_outbound_destination(destination)
    message := sprintf(
        "NET-003: Outbound destination is unrestricted, invalid or too broad: %s",
        [rule.name],
    )
}

valid_outbound_destination(destination) if {
    regex.match(
        "^[0-9]{1,3}(\\.[0-9]{1,3}){3}/([0-9]|[12][0-9]|3[0-2])$",
        destination,
    )
    net.cidr_is_valid(destination)
    cidr_prefix_length(destination) >= 24
}

# NET-004: Public administration requires a globally routable IPv4 /32.
deny contains message if {
    source := input.management_sources[_]
    source.source_type == "public_ipv4"
    not valid_public_management_source(source.source_prefix)
    message := sprintf(
        "NET-004: Invalid public management IPv4 /32: %s",
        [source.name],
    )
}

valid_public_management_source(prefix) if {
    regex.match(
        "^[0-9]{1,3}(\\.[0-9]{1,3}){3}/32$",
        prefix,
    )
    net.cidr_is_valid(prefix)
    cidr_prefix_length(prefix) == 32
    not non_global_ipv4(prefix)
}

# NET-005: All administrative sources target the management subnet.
deny contains message if {
    source := input.management_sources[_]
    object.get(source, "destination_subnet", "") != "management"
    message := sprintf(
        "NET-005: Management SSH must target the management subnet: %s",
        [source.name],
    )
}

# NET-006: VPN sources must use valid RFC1918 IPv4 networks.
deny contains message if {
    source := input.management_sources[_]
    source.source_type == "private_vpn"
    not valid_private_vpn_source(source.source_prefix)
    message := sprintf(
        "NET-006: Invalid private VPN source: %s",
        [source.name],
    )
}

# NET-007: Management source types must be explicitly supported.
deny contains message if {
    source := input.management_sources[_]
    not source.source_type in {"public_ipv4", "private_vpn"}
    message := sprintf(
        "NET-007: Unsupported management source type: %s",
        [source.name],
    )
}

valid_private_vpn_source(prefix) if {
    net.cidr_is_valid(prefix)
    cidr_prefix_length(prefix) >= 8
    regex.match("^10\\.", prefix)
}

valid_private_vpn_source(prefix) if {
    net.cidr_is_valid(prefix)
    cidr_prefix_length(prefix) >= 12
    regex.match("^172\\.(1[6-9]|2[0-9]|3[01])\\.", prefix)
}

valid_private_vpn_source(prefix) if {
    net.cidr_is_valid(prefix)
    cidr_prefix_length(prefix) >= 16
    regex.match("^192\\.168\\.", prefix)
}

# Reserved, private, documentation and non-routable IPv4 ranges.
non_global_ipv4(prefix) if { startswith(prefix, "0.") }
non_global_ipv4(prefix) if { startswith(prefix, "10.") }
non_global_ipv4(prefix) if { startswith(prefix, "127.") }
non_global_ipv4(prefix) if { startswith(prefix, "169.254.") }
non_global_ipv4(prefix) if { startswith(prefix, "192.0.0.") }
non_global_ipv4(prefix) if { startswith(prefix, "192.0.2.") }
non_global_ipv4(prefix) if { startswith(prefix, "192.88.99.") }
non_global_ipv4(prefix) if { startswith(prefix, "192.168.") }
non_global_ipv4(prefix) if { startswith(prefix, "198.18.") }
non_global_ipv4(prefix) if { startswith(prefix, "198.19.") }
non_global_ipv4(prefix) if { startswith(prefix, "198.51.100.") }
non_global_ipv4(prefix) if { startswith(prefix, "203.0.113.") }

non_global_ipv4(prefix) if {
    regex.match(
        "^100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.",
        prefix,
    )
}

non_global_ipv4(prefix) if {
    regex.match(
        "^172\\.(1[6-9]|2[0-9]|3[01])\\.",
        prefix,
    )
}

non_global_ipv4(prefix) if {
    regex.match(
        "^(22[4-9]|23[0-9]|24[0-9]|25[0-5])\\.",
        prefix,
    )
}
