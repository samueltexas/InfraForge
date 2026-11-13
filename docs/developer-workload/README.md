# Developer Workload Example

This example demonstrates how application teams can compose
InfraForge's reusable Terraform modules.

## Included modules

- Resource Group: shared Azure resource lifecycle.
- Resource Group: shared Azure resource lifecycle.
- Networking: virtual network and application subnets.
- Identity: user-assigned managed identity.
- Key Vault: private secrets infrastructure.
- Monitoring: diagnostics, Log Analytics and Azure Monitor connectivity.

## Module composition

The example uses local Terraform module sources:

- `../../modules/resource-group`
- `../../modules/resource-group`
- `../../modules/networking`
- `../../modules/identity`
- `../../modules/keyvault`
- `../../modules/monitoring`

The complete configuration is available in
`examples/developer-workload/main.tf`.

## Application integration

A downstream deployment pipeline can consume Terraform outputs:

```bash
terraform output -raw application_subnet_id
terraform output -raw managed_identity_client_id
terraform output -raw key_vault_uri
```

These values can be used to configure application infrastructure.

Applications should use managed identity authentication rather
than embedding credentials or secrets in source code.

## Validation

From the repository root:

```bash
./scripts/validate.sh full
```

This validates the Terraform configuration without provisioning
Azure resources.

## Deployment boundary

The example uses placeholder subscription and tenant identifiers.
It is intended for offline validation and architecture demonstration.

Real deployment requires approved Azure credentials,
authorization, network review and cost assessment.

No Azure resources are deployed by the validation workflow.
