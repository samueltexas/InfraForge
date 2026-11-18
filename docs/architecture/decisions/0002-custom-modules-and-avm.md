# ADR 0002: Custom modules for the engineering demonstration

- Status: Accepted for this portfolio; reassess for production adoption
- Date: 2026-11-18
- Author: Samuel Texa

## Context

[Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/overview/introduction/)
provide standardized reusable Azure infrastructure modules. InfraForge is an
engineering demonstration, not an alternative claiming broader vendor support.

## Decision

Keep the small custom modules to demonstrate explicit input validation,
least-privilege defaults, composition, state ownership and Terraform testing.
Their limited variable surface makes these decisions reviewable. This is a
learning/design objective, not evidence that custom code is inherently better.

## Alternatives and tradeoffs

Using AVM directly reduces the amount of resource implementation maintained here
and should be evaluated first for a production project. Thin wrappers around AVM
can add organizational policy while delegating resource implementation upstream.
Custom modules provide a deliberately narrow contract but make this project
responsible for provider upgrades, API changes, security fixes and migration tests.

Before production adoption, compare the relevant AVM modules for networking,
Storage and Key Vault against required defaults, outputs, provider versions and
state addresses. Prototype one migration with a saved state copy and review
imports/moved blocks and the resulting plan. Do not switch module sources on a
live state without that exercise. No AVM migration is claimed as implemented.
