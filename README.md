# InfraForge

**Azure Infrastructure as Code | Cloud Security | DevSecOps Automation**

InfraForge is a modular Microsoft Azure infrastructure project built with
Terraform and automated security validation.

It demonstrates reusable infrastructure modules, secure cloud configuration,
and automated CI/CD validation without requiring an Azure deployment.

## Architecture

Four Terraform modules are currently implemented:

| Module | Responsibilities |
| --- | --- |
| Networking | Virtual Networks, subnets, NSGs, inbound security rules |
| Identity | Managed identities and scoped Azure RBAC |
| Key Vault | Secrets access controls, private endpoints, private DNS |
| Monitoring | Log Analytics, diagnostics, alerts, Azure Monitor Private Link |

The `examples/integrated` configuration connects these modules using
Terraform outputs.

See [Architecture Documentation](docs/architecture/README.md).

## Technology Stack

- Microsoft Azure
- Terraform
- Docker
- GitHub Actions
- Checkov
- TFLint
- Open Policy Agent (OPA)
- Python
- HCL

## Repository Structure

- `.github/workflows/` — CI/CD pipelines
- `docs/architecture/` — architecture documentation
- `examples/` — standalone and integrated Terraform examples
- `modules/` — reusable Terraform modules
- `policies/network/` — OPA security policies
- `scripts/` — validation utilities
- `tests/` — automated security and integration tests

## Security Approach

- Least-privilege Azure RBAC
- User-assigned managed identities
- Private endpoints and private DNS
- Restricted public access
- Network segmentation
- Automated policy enforcement
- Infrastructure security tests

## CI/CD

GitHub Actions contains eight validation jobs covering Terraform,
Checkov, TFLint, OPA, and module-specific security checks.

The integrated architecture is also included in Terraform validation.

## Local Validation

From the repository root, initialize the integrated example:

    docker run --rm -v "$PWD:/workspace"       -w /workspace/examples/integrated       --entrypoint terraform hashicorp/terraform:1.14.0       init -backend=false -input=false -lockfile=readonly

Validate the configuration:

    docker run --rm -v "$PWD:/workspace"       -w /workspace/examples/integrated       --entrypoint terraform hashicorp/terraform:1.14.0       validate -no-color

Run the Python test suite in an environment with `python-hcl2` installed:

    python -m unittest discover -s tests -p 'test_*.py' -v

## Deployment Policy

**No Azure resources are deployed by default.**

Examples use placeholder subscription and tenant identifiers.

A real deployment requires authorization, valid Azure configuration,
security review, connectivity verification, and cost assessment.

## Project Status

- Networking — implemented
- DevSecOps CI/CD — implemented
- Identity and Access Management — implemented
- Key Vault and Secrets Management — implemented
- Monitoring and Observability — implemented
- Integrated architecture — locally validated
- Live Azure deployment — not performed

## Author

Samuel Texa
