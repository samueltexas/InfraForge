# Remote state and OIDC operations

Author: Samuel Texa

## Implemented development backend — 2026-11-19

Foundation and Integrated now use an independent Azure Blob backend, with separate
keys and preserved state identities. [ADR 0004](../architecture/decisions/0004-remote-state-migration.md)
records the migration, network tradeoff and security boundaries.

The account has Entra-only authorization, infrastructure encryption, versioning,
30-day Blob/container soft deletion and a deletion lock. State operations use
Blob leases. The application's private Storage Account is not the backend.

## Bootstrap a separate environment

An Azure administrator can run the reviewed `bootstrap/state_backend.py` with
`--subscription`, a globally unique `--account` and the exact GitHub subject prefix
reported by `gh api repos/<owner>/<repo>/actions/oidc/customization/sub`.
Defaults target this project's development demonstration; review all group,
container and identity names before reuse. The script refuses a subscription
without a spending limit and does not migrate states itself.

Use independent identities and containers/accounts for production. The plan
identity has Reader on the workload RG and Blob Data Contributor on only the
state container for state reads and locking. It has no workload-write permission.
These backend data permissions can modify state: protect the workflow and trusted
contributors, not just the Azure resource role.

## Initialize an authorized workstation

The committed roots contain a partial backend with `use_azuread_auth = true`.
Obtain backend identifiers from the environment administrator; do not commit them
or credentials. Log in with Azure CLI and select the intended subscription:

```bash
export ARM_SUBSCRIPTION_ID="<subscription>"
export ARM_USE_CLI=true
export ARM_USE_OIDC=false
terraform -chdir=examples/foundation init \
  -backend-config="storage_account_name=<backend-account>" \
  -backend-config="container_name=<development-container>" \
  -backend-config="key=foundation.tfstate"
# Repeat for examples/integrated using key=integrated.tfstate.
```

For an existing local state, first make protected backups, verify the remote key
is empty and add `-migrate-state`. Review the prompt and compare lineage, resources
and outputs after copying. Never use `-force-copy` or start with an empty state to
bypass a conflict. For a new checkout with no local state, ordinary init connects
to the existing backend. Do not migrate stale archived local states into live keys.

## GitHub OIDC

The workflow uses ephemeral OIDC tokens with `ARM_USE_OIDC=true` and
`ARM_USE_AZUREAD=true`. Environment secrets hold masked client/tenant/subscription
IDs, backend location and expected state lineage; they are identifiers, not
long-lived credentials. No access key or client secret is stored.

The Azure federated subjects use GitHub's current immutable repository prefix,
not a guessed legacy `repo:owner/name` string. The two environments restrict
allowed refs. Fork and Dependabot PRs run static CI but never authenticated plans.
Only trusted same-repository code receives access to sensitive state.

Scheduled drift runs from main daily at 06:17 UTC. Workflow dispatch can validate
both states on demand. PR comments contain only status, commit and action counts;
raw provider output, state and full plan JSON are not uploaded. Redacted summaries
expire after 30 days; milestone evidence is separately exported into Git.

## Apply and recovery

The GitHub development-apply environment is configured with required owner review
and administrator bypass disabled. No resource-write identity or apply workflow
is connected to it yet. Application changes continue to require an authorized
operator, a fresh reviewed plan and manual apply under the deployment runbook.

A later deployment workflow needs a separately scoped write identity, reviewed
RBAC-management permissions and protection against applying a stale/untrusted plan.
Do not reuse the plan identity for deployments or grant it Contributor to fix a
read-permission error.

Preserve versioned state backups, freeze writers before recovery, verify lineage
and resource addresses, and require a fresh no-change or explicitly reviewed plan.
See [HashiCorp backend documentation](https://developer.hashicorp.com/terraform/language/backend/azurerm).
