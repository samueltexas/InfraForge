# InfraForge — Architecture

## Overview

InfraForge is a modular Infrastructure as Code reference project for
Microsoft Azure.

The integrated example composes four Terraform modules:

- Networking
- Identity
- Key Vault
- Monitoring

The infrastructure is validated locally without deploying Azure resources.

## Architecture Diagram

    GitHub Repository
            |
            v
    GitHub Actions CI/CD
            |
            +-- Terraform Validation
            +-- Checkov Security Scan
            +-- TFLint Static Analysis
            +-- OPA Network Policy Tests
            +-- Terraform Security Tests
            +-- IAM Security Tests
            +-- Key Vault Security Tests
            +-- Monitoring Security Tests

    Azure Infrastructure — Terraform Design

    Networking
        |
        +-- Virtual Network
        +-- Application Subnet
        +-- Database Subnet
        +-- Management Subnet
        +-- Private Endpoint Subnet
                    |
                    +-- Key Vault Private Endpoint
                    +-- Monitoring Private Endpoint

    Managed Identity
        |
        +-- Key Vault Secrets User RBAC
                    |
                    v
                Key Vault
                    |
                    +-- Diagnostic Settings
                    +-- Metric Alert
                    |
                    v
             Azure Monitoring
                    |
                    +-- Log Analytics
                    +-- Private Link Scope
                    +-- Private DNS

This diagram represents Terraform configuration relationships.
It does not represent deployed infrastructure or verified network traffic.

## Module Responsibilities

### Networking

Defines Azure Virtual Networks, subnets, Network Security Groups,
explicit inbound rules, and default-deny inbound security rules.

### Identity

Creates a user-assigned managed identity.

Optional role assignments are limited to approved read-only roles
with explicit Azure resource scopes.

The integrated example uses its principal ID for Key Vault RBAC.

No application workload is attached to this identity.

### Key Vault

Configures Azure Key Vault with:

- RBAC authorization
- Disabled public network access
- Soft delete
- Purge protection
- Private endpoint
- Private DNS integration
- Key Vault Secrets User role assignments

No secret values are managed by this project.

### Monitoring

Configures:

- Log Analytics Workspace
- Diagnostic settings
- Metric alerts
- Azure Monitor Action Group
- Azure Monitor Private Link Scope
- Private endpoint
- Private DNS integration

The integrated example references the Key Vault resource ID for
diagnostics and metric alerts.

## Module Integration

| Source | Destination | Terraform Reference |
| --- | --- | --- |
| Networking | Key Vault | `module.networking.vnet_id` |
| Networking | Key Vault | `module.networking.subnet_ids["private-endpoints"]` |
| Networking | Monitoring | `module.networking.vnet_id` |
| Networking | Monitoring | `module.networking.subnet_ids["private-endpoints"]` |
| Identity | Key Vault | `module.identity.principal_id` |
| Key Vault | Monitoring | `module.keyvault.key_vault_id` |

## Security Controls

The architecture emphasizes:

- Explicit inbound permissions
- Default-deny inbound NSG rules
- Private service connectivity configuration
- Managed identities instead of embedded credentials
- Scoped RBAC assignments
- Restricted public access
- Automated infrastructure security validation

## Validation Boundaries

Terraform configuration validation does not prove that Azure
resources can be successfully deployed.

Static security checks do not prove runtime security.

Private endpoint connectivity, DNS resolution, operational
monitoring, and alert delivery have not been verified in Azure.

## Known Limitations

### Private Endpoint Networking

The Networking module applies restrictive inbound NSG rules.

Private endpoint network policies and connectivity require
additional verification before deployment.

### Private DNS

Private DNS zone ownership and reuse must be coordinated
in shared Azure environments.

### Monitoring

Diagnostic settings and alerts are defined, but ingestion,
alert evaluation, and notification delivery have not been
verified against live Azure resources.

### Resource Lifecycle

Azure deployment, replacement, destruction, permissions,
and service-specific constraints have not been tested live.

### Future Architecture

Hub-and-spoke networking, AKS, hybrid connectivity,
disaster recovery, and broader governance capabilities
are not implemented in the current project.

## Cost Policy

Local validation must remain free.

Azure deployment is optional and requires explicit approval,
valid credentials, connectivity review, and cost assessment.

Do not run `terraform apply` without reviewing expected costs.

## Author

Samuel Texa
