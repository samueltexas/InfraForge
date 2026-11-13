#!/usr/bin/env python3
"""Validate InfraForge Terraform network configuration without Azure access."""

import ipaddress
import json
import sys
from pathlib import Path

import hcl2


ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = ROOT / "examples/networking/main.tf"
MODULE = ROOT / "modules/networking/security_rules.tf"
OUTPUT = ROOT / "tests/policies/network/terraform-generated.json"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load_hcl(path):
    with path.open(encoding="utf-8") as stream:
        return hcl2.load(stream)


def get_networking_module(configuration):
    modules = [
        block["networking"]
        for block in configuration.get("module", [])
        if "networking" in block
    ]

    require(len(modules) == 1, "Expected exactly one networking module.")
    return modules[0]


def get_resource(configuration, resource_name):
    matches = []

    for block in configuration.get("resource", []):
        instances = block.get("azurerm_network_security_rule", {})
        if resource_name in instances:
            matches.append(instances[resource_name])

    require(
        len(matches) == 1,
        f"Expected exactly one {resource_name} security resource.",
    )
    return matches[0]


def validate_module_template():
    configuration = load_hcl(MODULE)

    allowed = get_resource(configuration, "allow_inbound")
    denied = get_resource(configuration, "deny_inbound")
    management = get_resource(configuration, "allow_management_ssh")

    expected_allowed = {
        "for_each": "${var.security_rules}",
        "name": "${each.key}",
        "direction": "Inbound",
        "access": "Allow",
        "protocol": "Tcp",
        "source_address_prefix": "${each.value.source_prefix}",
        "destination_port_range": "${each.value.destination_port}",
        "network_security_group_name": (
            "${azurerm_network_security_group.subnet"
            "[each.value.destination_subnet].name}"
        ),
    }

    expected_denied = {
        "for_each": "${var.subnets}",
        "direction": "Inbound",
        "access": "Deny",
        "protocol": "*",
        "source_address_prefix": "*",
        "destination_port_range": "*",
        "priority": 4000,
        "network_security_group_name": (
            "${azurerm_network_security_group.subnet[each.key].name}"
        ),
    }

    for attribute, expected in expected_allowed.items():
        require(
            allowed.get(attribute) == expected,
            f"Unexpected allow_inbound.{attribute}: "
            f"{allowed.get(attribute)!r}",
        )

    for attribute, expected in expected_denied.items():
        require(
            denied.get(attribute) == expected,
            f"Unexpected deny_inbound.{attribute}: "
            f"{denied.get(attribute)!r}",
        )

    require(
        allowed.get("priority") == "${each.value.priority}",
        "Allow rule priority must come from the validated rule input.",
    )

    require(
        allowed.get("resource_group_name") == "${var.resource_group_name}"
        and denied.get("resource_group_name") == "${var.resource_group_name}",
        "Unexpected resource group mapping.",
    )

    require(
        allowed.get("source_port_range") == "*"
        and allowed.get("destination_address_prefix") == "*",
        "Unexpected allow rule port or destination mapping.",
    )

    require(
        denied.get("source_port_range") == "*"
        and denied.get("destination_address_prefix") == "*",
        "Unexpected deny rule port or destination mapping.",
    )

    expected_management = {
        "for_each": "${var.management_sources}",
        "direction": "Inbound",
        "access": "Allow",
        "protocol": "Tcp",
        "source_address_prefix": "${each.value.source_prefix}",
        "destination_port_range": "22",
        "priority": "${each.value.priority}",
        "network_security_group_name": (
            "${azurerm_network_security_group.subnet"
            '["application"].name}'
        ),
    }

    for attribute, expected in expected_management.items():
        require(
            management.get(attribute) == expected,
            f"Unexpected allow_management_ssh.{attribute}: "
            f"{management.get(attribute)!r}",
        )

    require(
        management.get("resource_group_name")
        == "${var.resource_group_name}",
        "Unexpected management SSH resource group mapping.",
    )

    require(
        management.get("source_port_range") == "*"
        and management.get("destination_address_prefix") == "*",
        "Unexpected management SSH port or destination mapping.",
    )

    print("PASS: Terraform security resource mappings")
    print("PASS: Terraform management SSH resource mappings")




def validate_management_sources(sources, subnets, security_rules):
    """Validate external administrator and private VPN SSH sources."""

    require(isinstance(sources, dict), "Management sources must be a map.")

    reserved_ranges = [
        ipaddress.ip_network("10.0.0.0/8"),
        ipaddress.ip_network("172.16.0.0/12"),
        ipaddress.ip_network("192.168.0.0/16"),
    ]

    used_priorities = {
        (rule["destination_subnet"], rule["priority"])
        for rule in security_rules.values()
    }

    for name, source in sources.items():
        require(isinstance(source, dict), f"Invalid management source: {name}")

        required_fields = {
            "source_type",
            "source_prefix",
            "destination_subnet",
            "priority",
        }

        require(
            set(source) == required_fields,
            f"Unexpected management source fields: {name}",
        )

        require(
            source["destination_subnet"] == "application"
            and "application" in subnets,
            f"Management SSH must target the application subnet: {name}",
        )

        require(
            source["source_type"] in {"public_ipv4", "private_vpn"},
            f"Unsupported management source type: {name}",
        )

        network = ipaddress.ip_network(
            source["source_prefix"],
            strict=True,
        )

        require(network.version == 4, f"IPv4 is required: {name}")

        priority = source["priority"]

        require(
            type(priority) is int and 100 <= priority < 4000,
            f"Invalid management priority: {name}",
        )

        priority_key = (source["destination_subnet"], priority)

        require(
            priority_key not in used_priorities,
            f"Duplicate NSG priority: {name}",
        )

        used_priorities.add(priority_key)

        if source["source_type"] == "public_ipv4":
            require(
                network.prefixlen == 32,
                f"Public management sources must use /32: {name}",
            )

            require(
                network.network_address.is_global,
                f"Public management source must be globally routable: {name}",
            )

        else:
            require(
                any(
                    network.subnet_of(private_range)
                    for private_range in reserved_ranges
                ),
                f"VPN source must belong to an RFC1918 range: {name}",
            )

    print(f"PASS: {len(sources)} management sources validated")


def validate_example():
    configuration = load_hcl(EXAMPLE)
    networking = get_networking_module(configuration)

    require(
        networking.get("source") == "../../modules/networking",
        "Networking module source has changed.",
    )

    address_space = networking.get("address_space")
    subnets = networking.get("subnets")
    rules = networking.get("security_rules")

    require(isinstance(address_space, list) and address_space, "Invalid VNet.")
    require(isinstance(subnets, dict) and subnets, "Invalid subnets.")
    require(isinstance(rules, dict), "Security rules must be a literal map.")

    vnet_networks = [
        ipaddress.ip_network(value, strict=True)
        for value in address_space
    ]

    require(
        all(network.version == 4 for network in vnet_networks),
        "Only IPv4 networks are supported.",
    )

    subnet_networks = {}

    for name, prefixes in subnets.items():
        require(
            isinstance(prefixes, list) and prefixes,
            f"Invalid subnet prefixes: {name}",
        )

        parsed = [
            ipaddress.ip_network(prefix, strict=True)
            for prefix in prefixes
        ]

        require(
            all(
                network.version == 4
                and any(network.subnet_of(vnet) for vnet in vnet_networks)
                for network in parsed
            ),
            f"Subnet outside the VNet: {name}",
        )

        subnet_networks[name] = parsed

    normalized = []

    for name, rule in rules.items():
        require(isinstance(rule, dict), f"Invalid rule: {name}")

        require(
            set(rule) == {
                "destination_subnet",
                "source_prefix",
                "destination_port",
                "priority",
            },
            f"Unexpected rule fields: {name}",
        )

        require(
            rule["destination_subnet"] in subnet_networks,
            f"Unknown destination subnet: {name}",
        )

        source = ipaddress.ip_network(rule["source_prefix"], strict=True)

        require(
            source.version == 4
            and any(
                source.subnet_of(subnet)
                for networks in subnet_networks.values()
                for subnet in networks
            ),
            f"Source must belong to a managed subnet: {name}",
        )

        port_text = rule["destination_port"]

        require(
            isinstance(port_text, str)
            and port_text.isdecimal()
            and 1 <= int(port_text) <= 65535,
            f"Invalid TCP port: {name}",
        )

        priority = rule["priority"]

        require(
            type(priority) is int and 100 <= priority < 4000,
            f"Invalid rule priority: {name}",
        )

        normalized.append({
            "name": name,
            "direction": "Inbound",
            "access": "Allow",
            "protocol": "Tcp",
            "destination_port_range": port_text,
            "source_address_prefix": str(source),
        })

    management_sources = networking.get("management_sources")

    if isinstance(management_sources, dict):
        validate_management_sources(
            management_sources,
            subnets,
            rules,
        )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps({"security_rules": normalized}, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"PASS: {len(normalized)} Terraform network rules validated")
    print(f"GENERATED: {OUTPUT.relative_to(ROOT)}")


def main():
    validate_module_template()
    validate_example()
    print("TERRAFORM NETWORK VALIDATION PASSED")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
