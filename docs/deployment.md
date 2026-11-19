# Integrated Azure deployment

Author: Samuel Texa

## Scope and state ownership

`examples/foundation` owns the resource group, VNet, four subnets, NSGs,
network rules and managed identity. `examples/integrated` references those
resources and owns Key Vault, monitoring, DNS and Storage. Both states now use
separate Azure Blob keys; keep protected recovery backups. Neither state nor
saved plans belong in Git. Never recreate the Foundation from the integrated configuration.

## Storage configuration

- Region: Poland Central; account: `stinfraforgeint01`.
- Standard LRS is supported by the subscription's regional SKU inventory.
  Standard GRS was rejected by Azure. LRS does not provide zone or regional
  disaster recovery; ZRS is also listed as available but is not selected for
  this cost-conscious demonstration.
- Entra ID is the portal authorization default. Shared Key, local users and
  public network access are disabled. HTTPS and TLS 1.2 are required.
- Microsoft-managed keys and infrastructure encryption are enabled. CMK is an
  optional module capability, not enabled in this deployment.
- Three private containers: `application-data`, `backup-data`, `audit-logs`.
  The Foundation identity receives Storage Blob Data Contributor per container.
- Blob versioning, change feed and 14-day blob/container soft deletion are on.
- The Blob endpoint reuses the monitoring-owned private DNS zone and VNet link.
- Blob and Queue read/write/delete logs and transaction metrics are sent to
  the existing Log Analytics workspace, with its 30-day retention.
- AzureRM 4.81+ management-plane provisioning avoids opening public access.
  Legacy Queue analytics remain supported for existing consumers; the integrated
  example disables them in favor of Azure Monitor diagnostics. Its legacy
  `storage_queue_properties_id` output is null; use
  `storage_queue_diagnostic_setting_id` instead.

## Trial spending protection

The subscription was verified on 2026-11-18 as `FreeTrial_2014-09-01` with
`spendingLimit = On`. This deployment consumes trial credits: it is not an
always-free architecture. Private Endpoints, DNS, Key Vault, monitoring and
storage can consume credits. Do not remove the spending limit or upgrade the
subscription without explicit authorization. Exhausted credits or trial expiry
can disable the deployment. No Marketplace products are required.

The remaining credit balance was not verified. Usage and billing may be delayed.
See [Azure spending limits](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/spending-limit).

## Safe deployment procedure

1. Authenticate to the intended Azure tenant and select the subscription.
2. Back up both state files to a private, ignored location.
3. Run `terraform fmt -check -recursive` and integrated `terraform validate`.
4. Set `ARM_SUBSCRIPTION_ID` explicitly and generate a fresh saved plan from
   `examples/integrated` using `terraform plan -input=false -out=<new-plan>`.
5. Inspect every resource action. Stop on unplanned deletion or replacement.
6. Recheck the Free Trial spending limit before applying the reviewed plan.
7. Verify resources, DNS zone groups, RBAC, encryption and diagnostic settings;
   run a fresh plan to confirm convergence. Never apply an old failed plan.

Application-level private DNS resolution, Blob read/write and alert delivery
require a client inside the connected VNet. Management-plane validation alone
does not prove those runtime paths. No VM or paid connectivity service is added
solely for verification.

See the [remote backend runbook](operations/remote-state.md) for initialization
and the migration completed on 2026-11-19. Existing local consumers must migrate
with comparison and backup, not start with empty state.

## Deployment evidence — 2026-11-18

The reviewed fresh plan contained 10 creates, zero updates and zero deletions.
Apply completed successfully with exactly those actions. The integrated state
now manages 32 resources; the Foundation state retains its 23 resources.
The monitoring endpoint was preserved, not replaced. Pre-apply state copies
are retained in the local ignored `.backups` directory.

Azure reports Standard LRS, public access disabled, Shared Key disabled,
local users disabled, OAuth default enabled and infrastructure encryption on.
The Blob private DNS record is `10.20.4.16`. Three private containers and their
container-scoped managed-identity role assignments are present.

The existing action group has no email receivers. The metric alert exists,
but notification delivery is not configured or claimed as verified.
No recipients were added and no messages were sent.

A fresh post-apply plan returned exit code 0: no changes. Essential checks
passed: recursive formatting, Terraform validation, eight Storage module tests,
126 Python regression tests and TFLint for Storage and Integrated.
