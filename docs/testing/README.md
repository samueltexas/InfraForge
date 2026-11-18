# Infrastructure testing and reliability

Author: Samuel Texa

## What each layer proves

The Python `python-hcl2` tests inspect parsed HCL, module contracts and selected
source expressions. Some tests use text assertions. They are structural regression
checks, not Terraform plans or Azure integration tests.

All seven modules also have native `.tftest.hcl` tests. There are currently 40
`command = plan` runs using `mock_provider "azurerm"`. Terraform evaluates the
configuration and resource instances with mocked provider responses. Tests cover
input rejection, expanded resource counts, deny/allow rules, per-container RBAC,
optional CMK, diagnostics and shared DNS selection. These are meaningful plan-time
checks beyond matching HCL text, but do not exercise the Azure API or real provider
create/update behavior and cannot establish service availability.

The OPA payload in `scripts/validate_terraform_network.py` is derived from parsed
HCL, not `terraform show -json`. Do not describe this as enforcement on a real
provider-backed plan. Checkov and TFLint are also static checks.

The recorded deployment used a real provider-backed plan and apply, followed by
read-only Azure checks and a refreshed no-change plan. That is separate operational
evidence, not an automatically repeated end-to-end test suite.

## Commands

```bash
terraform -chdir=modules/storage init -backend=false -input=false -lockfile=readonly
terraform -chdir=modules/storage test -no-color
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Python dependencies include `python-hcl2` and PyYAML, pinned in CI. The native
Terraform test jobs run for every module. Tests use mock providers and do not
create Azure resources. CI also checks all example configurations.

## Next test boundaries

Before production adoption, add policy assertions over a real saved-plan JSON,
upgrade/state migration tests for breaking releases and workload-level tests from
a VNet-connected runner. Keep any plan/state artifacts private: they can contain
sensitive values. Do not claim these suites exist until they run successfully.

`scripts/check_drift.py` has failure-classification tests so authentication errors,
empty state and exit code 2 cannot silently be reported as a clean environment.
This command is operational tooling; it is not a replacement for module tests.
