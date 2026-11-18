# ADR 0001: LRS for the protected Azure trial demonstration

- Status: Accepted for the integrated demonstration only
- Date: 2026-11-18
- Author: Samuel Texa

## Context

Azure rejected Standard GRS for StorageV2 in Poland Central. The subscription
SKU inventory lists Standard LRS and Standard ZRS. The demonstration must
preserve deployed resources and the Free Trial spending limit.

## Decision

Use Standard LRS for `examples/integrated`. Keep the reusable module default
at GRS. Scope the Checkov CKV_AZURE_206 exception to the integrated module call,
not the reusable Storage resource or the CI command. All other security checks
continue to run and failures still fail CI.

## Consequences

LRS provides local replication, not availability-zone or regional disaster
recovery. Soft deletion and versioning support recovery from logical deletion;
they do not replace disaster recovery. This environment contains demonstration
containers and must not be presented as production-ready or used for critical
data. ZRS is a supported alternative requiring a separately reviewed migration,
cost assessment and recovery requirements. Do not replace the existing account
merely to turn a static check green.

## Review triggers

Revisit before storing critical data, removing the trial spending limit,
introducing an availability SLA or changing region. A production design must
define RPO/RTO, choose supported redundancy and test recovery.
