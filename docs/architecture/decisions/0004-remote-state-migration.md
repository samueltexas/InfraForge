# ADR 0004: Migrate the development states to a dedicated Azure Blob backend

- Status: Implemented on 2026-11-19
- Author: Samuel Texa
- Supersedes the proposed-backend portion of ADR 0003

## Decision and migration

Create an independent backend through `bootstrap/state_backend.py`, outside the
lifecycle of both Terraform stacks. Migrate Foundation and Integrated with
`terraform init -migrate-state` into distinct keys, `foundation.tfstate` and
`integrated.tfstate`, in a development-only container. The operator verified an
empty destination and reviewed each copy prompt. Protected pre-migration backups
were compared with the remote states for lineage, every resource and every output.
The migration does not recreate application resources.

Use Entra authorization, disable anonymous Blob access, Shared Key and local
users, enforce TLS 1.2 and infrastructure encryption, retain Blob versions and
30-day soft deletion, and protect the account with a CanNotDelete management lock.
Blob leases provide state-operation locking. A management deletion lock is not
an immutable backup or a substitute for Blob retention.

## Connectivity and cost tradeoff

There are no private runners. The dedicated backend therefore exposes its HTTPS
endpoint to GitHub-hosted runners while requiring Entra authentication and scoped
RBAC for all state access. This does not expose Blob contents anonymously. It is
less isolated than a private endpoint; this exception is restricted to backend
storage. Application Storage, Key Vault and Monitor remain private.

A private runner and private backend endpoint would add operational complexity
and potentially cost. Revisit this decision before production. The Free Trial
spending limit is retained; backend storage/version transactions consume credits.
No promise of permanently free operation is made.

## Identity boundaries

The plan identity has Reader on the workload resource group and Storage Blob
Data Contributor only on the development state container. It cannot change
workload resources, but it can read/write state Blobs and acquire leases: do not
call it universally read-only. Treat Terraform state as sensitive data.

Federation is bound to this repository's immutable OIDC subject prefix and the
specific development-plan/development-drift environments. Environment branch
rules and workflow conditions exclude forks and Dependabot from authenticated
plans. Same-repository contributors are trusted to propose Terraform code; review
access to that repository accordingly. No client secret or storage key is created.

The development-apply environment requires manual owner approval. No workload-write
identity or automatic apply workflow is enabled in this delivery.

## Environment boundaries

Foundation and Integrated are stacks, not separate environments. This backend
container and identity are development-only. Production must use separately scoped
storage/identity/subscription boundaries; changing a Blob key is not RBAC isolation.

## Evidence and recovery

See the committed migration comparison and operational results in
`docs/evidence/2026-11-19`. Keep local backups protected (directory 0700, files 0600)
and out of Git; filesystem permissions are not encryption. Prefer an encrypted
backup destination under the operator's recovery policy. Never publish state files.
Freeze writers before any recovery and validate lineage/serial before restoring
a retained version. Never force-unlock an active operation or overwrite remote
state with an older local copy blindly.
