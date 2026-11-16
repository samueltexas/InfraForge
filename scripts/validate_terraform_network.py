#!/usr/bin/env python3
"""Validate InfraForge Terraform network configuration without Azure access."""

import argparse
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
    outbound = get_resource(configuration, "allow_outbound")
    denied_outbound = get_resource(configuration, "deny_outbound")

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

    expected_outbound = {
        "for_each": "${var.outbound_rules}",
        "direction": "Outbound",
        "access": "Allow",
        "protocol": "${each.value.protocol}",
        "destination_address_prefix": "${each.value.destination_prefix}",
        "destination_port_range": "${each.value.destination_port}",
        "priority": "${each.value.priority}",
        "network_security_group_name": (
            "${azurerm_network_security_group.subnet"
            "[each.value.source_subnet].name}"
        ),
    }

    for attribute, expected in expected_outbound.items():
        require(
            outbound.get(attribute) == expected,
            f"Unexpected allow_outbound.{attribute}: "
            f"{outbound.get(attribute)!r}",
        )

    require(
        outbound.get("resource_group_name") == "${var.resource_group_name}"
        and outbound.get("source_port_range") == "*"
        and outbound.get("source_address_prefix") == "*",
        "Unexpected outbound rule resource group or source mapping.",
    )

    expected_denied_outbound = {
        "for_each": "${var.subnets}",
        "direction": "Outbound",
        "access": "Deny",
        "protocol": "*",
        "destination_address_prefix": "*",
        "destination_port_range": "*",
        "priority": 4000,
        "network_security_group_name": (
            "${azurerm_network_security_group.subnet[each.key].name}"
        ),
    }

    for attribute, expected in expected_denied_outbound.items():
        require(
            denied_outbound.get(attribute) == expected,
            f"Unexpected deny_outbound.{attribute}: "
            f"{denied_outbound.get(attribute)!r}",
        )

    require(
        denied_outbound.get("resource_group_name") == "${var.resource_group_name}"
        and denied_outbound.get("source_address_prefix") == "*"
        and denied_outbound.get("source_port_range") == "*",
        "Unexpected outbound deny resource group or source mapping.",
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
            '["management"].name}'
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
    print("PASS: Terraform outbound allowlist and default-deny mappings")




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
            source["destination_subnet"] == "management"
            and "management" in subnets,
            f"Management SSH must target the dedicated management subnet: {name}",
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

            non_public_ranges = [
                ipaddress.ip_network("0.0.0.0/8"),
                ipaddress.ip_network("10.0.0.0/8"),
                ipaddress.ip_network("100.64.0.0/10"),
                ipaddress.ip_network("127.0.0.0/8"),
                ipaddress.ip_network("169.254.0.0/16"),
                ipaddress.ip_network("172.16.0.0/12"),
                ipaddress.ip_network("192.0.0.0/24"),
                ipaddress.ip_network("192.0.2.0/24"),
                ipaddress.ip_network("192.88.99.0/24"),
                ipaddress.ip_network("192.168.0.0/16"),
                ipaddress.ip_network("198.18.0.0/15"),
                ipaddress.ip_network("198.51.100.0/24"),
                ipaddress.ip_network("203.0.113.0/24"),
                ipaddress.ip_network("224.0.0.0/4"),
                ipaddress.ip_network("240.0.0.0/4"),
            ]

            require(
                network.network_address.is_global
                and not any(
                    network.network_address in reserved
                    for reserved in non_public_ranges
                ),
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


def validate_example(output_path=OUTPUT):
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
    used_inbound_priorities = set()

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
            and 1 <= int(port_text) <= 65535
            and int(port_text) not in {22, 3389},
            f"Invalid or administrative TCP port: {name}",
        )

        priority = rule["priority"]

        require(
            type(priority) is int and 100 <= priority < 4000,
            f"Invalid rule priority: {name}",
        )
        priority_key = (rule["destination_subnet"], priority)
        require(
            priority_key not in used_inbound_priorities,
            f"Duplicate inbound NSG priority: {name}",
        )
        used_inbound_priorities.add(priority_key)

        normalized.append({
            "name": name,
            "direction": "Inbound",
            "access": "Allow",
            "protocol": "Tcp",
            "destination_port_range": port_text,
            "source_address_prefix": str(source),
        })

    management_sources = networking.get("management_sources", {})
    normalized_management = []

    if isinstance(management_sources, dict):
        validate_management_sources(management_sources, subnets, rules)

        for name, source in management_sources.items():
            normalized_management.append({
                "name": name,
                "source_type": source["source_type"],
                "source_prefix": source["source_prefix"],
                "destination_subnet": source["destination_subnet"],
                "priority": source["priority"],
            })
    else:
        require(
            management_sources == "${var.management_sources}",
            "Management sources must be an explicit map or the approved input variable.",
        )

    outbound_rules = networking.get("outbound_rules", {})
    require(isinstance(outbound_rules, dict), "Outbound rules must be a literal map.")

    normalized_outbound = []
    used_outbound_priorities = set()

    for name, rule in outbound_rules.items():
        require(isinstance(rule, dict), f"Invalid outbound rule: {name}")
        require(
            set(rule) == {
                "source_subnet",
                "destination_prefix",
                "destination_port",
                "protocol",
                "priority",
            },
            f"Unexpected outbound rule fields: {name}",
        )
        require(
            rule["source_subnet"] in subnet_networks,
            f"Unknown outbound source subnet: {name}",
        )

        destination = ipaddress.ip_network(
            rule["destination_prefix"], strict=True
        )
        require(
            destination.version == 4 and destination.prefixlen >= 24,
            f"Outbound destination must be an IPv4 CIDR with prefix /24 through /32: {name}",
        )
        require(
            rule["protocol"] in {"Tcp", "Udp"},
            f"Unsupported outbound protocol: {name}",
        )

        port_text = rule["destination_port"]
        require(
            isinstance(port_text, str)
            and port_text.isdecimal()
            and 1 <= int(port_text) <= 65535,
            f"Invalid outbound destination port: {name}",
        )

        priority = rule["priority"]
        require(
            type(priority) is int and 100 <= priority < 4000,
            f"Invalid outbound priority: {name}",
        )
        priority_key = (rule["source_subnet"], priority)
        require(
            priority_key not in used_outbound_priorities,
            f"Duplicate outbound NSG priority: {name}",
        )
        used_outbound_priorities.add(priority_key)

        normalized_outbound.append({
            "name": name,
            "direction": "Outbound",
            "access": "Allow",
            "protocol": rule["protocol"],
            "destination_port_range": port_text,
            "destination_address_prefix": str(destination),
        })

    output_path = Path(output_path).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    OUTPUT_PAYLOAD = {
        "security_rules": normalized,
        "outbound_rules": normalized_outbound,
        "management_sources": normalized_management,
    }

    output_path.write_text(
        json.dumps(OUTPUT_PAYLOAD, indent=2) + "\n",
        encoding="utf-8",
    )

    print(
        f"PASS: {len(normalized)} inbound and "
        f"{len(normalized_outbound)} outbound allowlist rules validated"
    )
    try:
        display_path = output_path.relative_to(ROOT)
    except ValueError:
        display_path = output_path

    print(f"GENERATED: {display_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Validate InfraForge Terraform network configuration."
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=OUTPUT,
        help="Destination for the Terraform-derived OPA JSON input.",
    )
    args = parser.parse_args()

    validate_module_template()
    validate_example(output_path=args.output)
    print("TERRAFORM NETWORK VALIDATION PASSED")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
