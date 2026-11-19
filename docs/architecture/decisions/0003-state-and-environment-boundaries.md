# ADR 0003: Separate stack ownership and a dedicated team backend

- Status: Stack separation implemented; backend proposal superseded by ADR 0004
- Date: 2026-11-18
- Author: Samuel Texa

Foundation owns network and identity; Integrated reads them through data sources.
This avoids duplicate ownership and limits the scope of changes. Two state files
are not two environments: both currently represent the development demonstration.

For team operation, choose a dedicated Azure Blob backend with lease locking,
Entra federation and container/environment-scoped permissions. Application
storage must not also be the only backend for the stack that manages it.
Production requires separately scoped identities and state boundaries.

Local state was retained to preserve the existing deployment and cost constraint;
it is a documented operational limitation, not a recommended team architecture.
Migration requires verified backups, private runner connectivity, explicit cost
review and a no-change plan. See the [runbook](../../operations/remote-state.md).

The backend migration was executed on 2026-11-19. See [ADR 0004](0004-remote-state-migration.md); the earlier local-state limitation above records the original decision, not the current backend.
