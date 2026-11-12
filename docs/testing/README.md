# Infrastructure Testing and Reliability

InfraForge validates Azure Terraform infrastructure without deploying
or provisioning Azure resources.

## Test layers

1. Terraform formatting and validation.
2. Module input and output contract testing.
3. Infrastructure integration testing.
4. Security regression testing.
5. Negative tests for insecure configurations.
6. OPA, Checkov and TFLint policy validation.

## Local execution

From the repository root, activate the existing Python environment
and execute the complete unittest discovery command:

    .venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v

## Security guarantees and limitations

These tests verify selected static infrastructure properties.

They do not prove live Azure network connectivity, successful
resource deployment, alert delivery or cloud availability.

No Azure subscription, Terraform apply or paid services are
required to run these Python tests.
