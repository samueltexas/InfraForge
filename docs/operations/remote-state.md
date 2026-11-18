# Remote state and identity runbook

Author: Samuel Texa

## Current status

The demonstration still uses separate local Foundation and Integrated states.
It is not yet configured for concurrent team operation. The steps below are a
migration design, not evidence that remote state or OIDC is active.

## Target design

Use a dedicated Azure Storage Account for state, separate from application data
and from the lifecycle of either stack. Disable Shared Key and public Blob access;
enable versioning and soft delete. For private networking, run Terraform on a
runner that can resolve and reach the backend private endpoint. A GitHub-hosted
runner does not automatically reach this VNet. Do not open the account publicly
just to make CI work.

Use separate subscriptions/accounts or containers and identities for development
and production. Different Blob keys alone are organizational separation, not an
RBAC security boundary. Within each environment use distinct keys:
`foundation.tfstate` and `integrated.tfstate`. No production environment exists yet.

The [azurerm backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)
uses Blob leases for state locking. Do not disable locking. A deployment identity
needs Storage Blob Data Contributor scoped to its state container; resource
permissions are separately scoped to its target environment. The drift identity
needs resource Reader plus the minimum backend permissions needed to read and lock
state; it must not have resource write permissions.

## Secretless authentication

Use Entra workload identity federation for GitHub Actions, with issuer
`https://token.actions.githubusercontent.com`, audience `api://AzureADTokenExchange`
and an exact subject such as `repo:samueltexas/InfraForge:environment:development`.
Use a protected GitHub environment and restrict its deployment branches. Production
must use a different identity and approvals. Do not use client secrets or storage
keys. GitHub job permissions should be `contents: read` and `id-token: write`.

An opt-in root backend block would be:

```hcl
terraform {
  backend "azurerm" {}
}
```

Example partial backend configuration (replace all placeholders):

```hcl
storage_account_name = "<dedicated-state-account>"
container_name       = "<environment-container>"
key                  = "integrated.tfstate"
use_azuread_auth     = true
use_oidc             = true
```

Supply `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`,
`ARM_USE_OIDC=true` and `ARM_USE_AZUREAD=true` through the protected job environment.
GitHub's OIDC request variables are available to Terraform in an authorized job.
Do not commit tokens, keys, state files or generated plans. For an interactive
migration using Azure CLI, use the backend's CLI authentication instead of OIDC;
do not combine an unavailable GitHub token flow with the local migration.

## Migration procedure — not executed

1. Provision and verify the dedicated backend, identity permissions, private DNS
   and runner reachability separately; review costs under the existing constraint.
2. Freeze writers. Back up both local states securely; record lineage, serial and
   resource count. Verify the destination Blob is absent or explicitly reconciled.
3. Add the backend block to one root and run `terraform init -migrate-state` with
   that environment's configuration. Review Terraform's migration prompt. Never
   use `-force-copy`, automatic approval or `state push` as a shortcut.
4. Pull the remote state and verify lineage, resource addresses/count and outputs
   match the source. Generate a fresh plan and require no unintended actions.
5. Repeat for the other root with a different key. Test a controlled lease
   contention: a second writer must wait or fail, not proceed concurrently.
6. Enable team workflows only after validation; retain protected backups according
   to the recovery policy. Do not delete the only known-good state copy.

If migration fails, stop writers and compare both states before reconfiguration.
Never blindly copy an older state over newer remote state or force-unlock a live
operation. Backend creation and migration have not been authorized by this review.
