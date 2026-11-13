# InfraForge

**Secure Azure Infrastructure as Code | Terraform | DevSecOps | Automated Testing**

InfraForge is a modular Infrastructure as Code project demonstrating
secure Azure infrastructure design, reusable Terraform modules,
automated security controls and CI/CD validation.

It is designed for local evaluation without provisioning Azure resources.

## Architecture

Four reusable Terraform modules are connected through an
integrated example.

| Module | Responsibilities |
| --- | --- |
| Networking | Virtual networks, subnets, NSGs and ingress controls |
| Identity | User-assigned managed identity and scoped RBAC |
| Key Vault | RBAC, private endpoints, private DNS and purge protection |
| Monitoring | Log Analytics, diagnostics, alerts and private link |

- [Architecture documentation](docs/architecture/README.md)
- [Architecture diagrams](docs/architecture/diagrams.md)
- [Integrated example](examples/integrated/main.tf)

## Technology Stack

Terraform, Microsoft Azure, Docker, GitHub Actions,
Python, Checkov, TFLint and Open Policy Agent.

## Quick Start

From the repository root, run:

    ./scripts/validate.sh quick

This runs the Python infrastructure tests.

For Python tests, install the required Python dependencies,
including python-hcl2.

For complete Terraform configuration validation, start Docker
Desktop and run:

    ./scripts/validate.sh full

Full validation uses Terraform 1.14.0 in Docker.

Neither mode runs terraform apply or deploys Azure resources.

## Testing and Reliability

At the completion of Phase 7:

- 89 Python tests passed.
- Nine GitHub Actions checks passed.
- Module contracts and integrated architecture were validated.
- Security regression and negative tests were included.

The CI pipeline also performs Terraform validation, Checkov,
TFLint, OPA and module-specific security checks.

- [Testing documentation](docs/testing/README.md)
- [Engineering evidence](docs/evidence/README.md)
- [Phase 7 Pull Request](https://github.com/samueltexas/InfraForge/pull/8)

## Security

The project demonstrates least-privilege RBAC, managed identities,
private networking, Key Vault purge protection, restricted public
access, NSGs and automated security validation.

These are configuration-level controls. They have not been
verified through a live Azure deployment.

## Repository Structure

    InfraForge/
      .github/workflows/
      docs/architecture/
      docs/evidence/
      docs/testing/
      examples/
      modules/
      policies/network/
      scripts/
      tests/
      Makefile
      README.md

## Developer Workload Example

The `examples/developer-workload` configuration demonstrates
how application teams compose the four reusable infrastructure modules.

It exposes application-ready outputs including subnet IDs,
managed identity identifiers, Key Vault URI and monitoring resources.

See [Developer Workload Documentation](docs/developer-workload/README.md).

## Deployment Policy

**No Azure infrastructure is deployed by default.**

A real deployment requires authorization, valid cloud configuration,
security review, network verification and cost assessment.

## Project Status

| Component | Status |
| --- | --- |
| Networking | Implemented and locally validated |
| Identity | Implemented and locally validated |
| Key Vault | Implemented and locally validated |
| Monitoring | Implemented and locally validated |
| Integrated architecture | Locally validated |
| Python tests | 107 passed |
| GitHub Actions | Nine checks passed at Phase 7 |
| Live Azure deployment | Not performed |

## Author

**Samuel Texa**

## License

This project is licensed under the MIT License.
See the [LICENSE](LICENSE) file for details.

Copyright (c) 2026 Samuel Texa
