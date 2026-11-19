# Changelog

All notable consumer-facing changes are recorded here. InfraForge uses repository-wide
Semantic Versioning: one tag versions all modules and examples. Author: Samuel Texa.

## Unreleased

No changes recorded yet.

## [3.0.0] — 2026-11-19

### Breaking operational change

Foundation and Integrated now declare an Azure Blob backend. Existing local-state
consumers must follow the remote-state migration runbook; new checkouts need
authorized backend configuration. Never initialize an empty state over deployed
resources. The reusable module input/output contracts are unchanged in this release.

### Added

- Separate backend bootstrap, versioning/soft deletion, deletion lock and lease locking.
- GitHub OIDC resource-Reader identity, real Azure PR plans with redacted comments,
  and daily drift monitoring. State-container data access is separately scoped.
- Protected future apply environment; no workload-write identity or automatic apply.
- State migration comparisons, sanitised state address exports and retention-aware evidence.

### Documentation

- Concise README with architecture diagram, dated status and no independent-attestation claim.
- ADR 0004 records the actual backend migration and authenticated public-endpoint tradeoff.

## [2.0.0] — 2026-11-19

Prepared on 2026-11-18 and published on 2026-11-19.

Major release: the changes below can affect existing consumers. Read the migration
notes and review a fresh plan before upgrading from v1.0.0.

### Breaking changes and migration

- Storage callers supplying `existing_blob_private_dns_zone_id` must now also set
  `create_blob_private_dns_zone = false`. Otherwise the module defaults to owning
  the zone. Review the plan to prevent duplicate DNS ownership.
- Networking explicitly disables default outbound access on all subnets. Workloads
  needing internet egress must provide an approved explicit egress path; do not
  assume the former implicit behavior remains available.
- Storage defaults portal authorization to Entra ID and disables local users.
  Consumers using local-user/SFTP authentication must review compatibility before
  upgrading. Shared Key remains disabled.
- The integrated example now reads an existing Foundation resource group, VNet,
  subnet and identity instead of creating them. Do not apply it against an older
  integrated state that owns those resources: prepare and review a state-ownership
  migration first. This repository's deployment started with separate states.
- The integrated configuration requires AzureRM >= 4.81.0, < 5.0.0.

### Added

- Separately owned Foundation example; private Azure deployment and redacted evidence.
- Optional Azure Monitor Queue diagnostics via `enable_legacy_queue_logging = false`.
  `queue_diagnostic_setting_id` is the new output. `queue_properties_id` is null
  when legacy analytics are disabled; legacy consumers retain the default behavior.
- State-preserving `moved` block from Queue properties to indexed instance `[0]`.
- Read-only deployment verification and drift-check tooling; operational runbooks.
- Documented redundancy, custom-module/AVM and remote-state decisions.

### Fixed

- Use supported Standard LRS for the Poland Central demonstration; the reusable
  module retains GRS as its default. LRS is a scoped, documented policy exception.
- Shared DNS resource counts no longer depend on an unknown resource ID.
- Foundation lock file includes verified Linux AMD64 and macOS ARM64 checksums.

## [1.0.0] — 2026-11-16

Initial published release at commit `da58e3b`: seven reusable Azure Terraform
modules, integrated/developer workload examples, native Terraform tests, Python
regression checks, Checkov, TFLint and OPA. This release predates the live Azure
deployment and the subsequent fixes listed above.

[1.0.0]: https://github.com/samueltexas/InfraForge/releases/tag/v1.0.0
[2.0.0]: https://github.com/samueltexas/InfraForge/releases/tag/v2.0.0

[3.0.0]: https://github.com/samueltexas/InfraForge/releases/tag/v3.0.0
