package main

import rego.v1

# NET-001: SSH must not be exposed to the public Internet.
deny contains message if {
    rule := input.security_rules[_]
    rule.direction == "Inbound"
    rule.access == "Allow"
    rule.protocol in {"Tcp", "*"}
    rule.destination_port_range in {"22", "*"}
    rule.source_address_prefix in {"0.0.0.0/0", "*", "Internet"}
    message := sprintf("NET-001: Public SSH access is prohibited: %s", [rule.name])
}

# NET-002: RDP must not be exposed to the public Internet.
deny contains message if {
    rule := input.security_rules[_]
    rule.direction == "Inbound"
    rule.access == "Allow"
    rule.protocol in {"Tcp", "*"}
    rule.destination_port_range in {"3389", "*"}
    rule.source_address_prefix in {"0.0.0.0/0", "*", "Internet"}
    message := sprintf("NET-002: Public RDP access is prohibited: %s", [rule.name])
}
