# Operations

Author: Samuel Texa

## Status

Azure provisioning and management-plane controls have recorded evidence.
The remote backend and OIDC plan identity are configured. The Azure Plan and Drift
workflow runs for trusted same-repository PRs, workflow dispatch and daily at 06:17
UTC. Automatic cost estimates and cloud apply automation remain disabled.

## Drift

Run `python3 scripts/check_drift.py examples/integrated` from the original checkout
with its initialized backend and authenticated Azure session. Set
`ARM_SUBSCRIPTION_ID` explicitly. Repeat for Foundation. The command first checks
that state exists and contains managed resources, then runs a refresh-only plan
with locking. It never applies or writes a saved plan. Exit codes: 0 = no drift,
2 = observed drift, 1 = execution/configuration failure. An error is not "no drift".

This detects remote changes relative to state, not desired configuration changes.
Use a normal reviewed `terraform plan` for proposed configuration changes.
Raw output may contain sensitive values; the command emits only a summary and
discards captured output. Investigate failures in a protected terminal.

The scheduled workflow uses a normal desired-configuration plan with detailed
exit codes, per-stack concurrency and lease locking. Code 2 fails drift monitoring;
in PRs it is reported as a proposed change. Refreshed state differences are
reported separately; this count alone does not classify their cause. It never auto-applies. See [remote state and OIDC](remote-state.md).

## Cost estimation and controls

The Azure Free Trial spending limit is active; it is not a cost estimate and the
architecture is not always free. Before changing infrastructure, record a dated
estimate with region, currency, billing offer and usage assumptions using the
[Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/).

Account for three Private Endpoints, private DNS zones and queries, Storage LRS
capacity/transactions/versions/change feed, Log Analytics ingestion and retention,
Key Vault operations and alert rules. Include data transfer and recovery retention.
Distinguish fixed hourly charges, variable usage and credits. Use both low-usage
and expected-usage scenarios; do not equate empty containers with zero total cost.

Compare estimates with Cost Management actual/amortized costs after billing delay.
Budget alerts notify; they are not a hard spending cap. The trial spending limit
is a separate protection and must not be removed automatically. Infracost or a
retail-price script could automate part of estimation, but coverage, credentials
and usage assumptions must be verified first. No numerical estimate or automated
cost gate is claimed in this revision.

## Incident handling

1. Record the failing workflow, commit, timestamp and affected resource.
2. Separate static-policy failures, authentication/network errors and live drift.
3. Preserve state and avoid retries that replace resources without plan review.
4. Correct code or document a narrowly scoped accepted tradeoff; never disable a
   scanner globally to get a green badge.
5. Verify Azure state, convergence and CI; publish redacted evidence and limitations.

## Observed drift triage — 2026-11-18

The first read-only refresh check returned exit code 2. Inspection of the fresh
refresh-only plan found three state differences:

- The shared Blob DNS zone's computed `number_of_record_sets` increased from 2
  to 3 after the Storage private endpoint added its record.
- Blob and Queue diagnostic logs were returned by Azure with explicit legacy
  `retention_policy { days = 0, enabled = false }` values instead of empty blocks.
  StorageRead, StorageWrite and StorageDelete remained present. This legacy
  diagnostic retention field is distinct from Log Analytics workspace retention.

These observations are metadata/default normalization, not proof of an outage or
lost audit categories. No apply, refresh-only apply or state edit was performed.
Until a reviewed state refresh records those values, a refresh-only drift check
can continue reporting them. Do not suppress all drift to hide expected changes;
classify and record the result. A normal desired-configuration plan is a separate
check from this remote-versus-saved-state comparison.
