# InfraForge Architecture Diagrams

These diagrams describe the intended Terraform infrastructure,
not a live Azure deployment.

## Integrated Infrastructure

```mermaid
flowchart TD
    ROOT["Integrated Terraform Example"]
    NET["Networking"]
    IAM["Identity"]
    KV["Key Vault"]
    MON["Monitoring"]
    VNET["Virtual Network and Subnets"]
    MI["Managed Identity and RBAC"]
    PE["Private Endpoints and DNS"]
    LOG["Log Analytics and Diagnostics"]
    ALERT["Azure Monitor Alerts"]

    ROOT --> NET
    ROOT --> IAM
    ROOT --> KV
    ROOT --> MON
    NET --> VNET
    IAM --> MI
    VNET --> PE
    KV --> PE
    MI --> KV
    KV --> LOG
    MON --> LOG
    MON --> ALERT
```

## DevSecOps CI/CD

```mermaid
flowchart TD
    PR["Pull Request"]
    CI["GitHub Actions"]
    TF["Terraform Validation"]
    CHECKOV["Checkov"]
    TFLINT["TFLint"]
    OPA["OPA"]
    POLICY["Terraform Policy Enforcement"]
    IAM["Identity Security"]
    KV["Key Vault Security"]
    MON["Monitoring Security"]
    REL["Reliability Tests"]
    REVIEW["Review and Merge"]

    PR --> CI
    CI --> TF
    CI --> CHECKOV
    CI --> TFLINT
    CI --> OPA
    CI --> POLICY
    CI --> IAM
    CI --> KV
    CI --> MON
    CI --> REL
    TF --> REVIEW
    CHECKOV --> REVIEW
    TFLINT --> REVIEW
    OPA --> REVIEW
    POLICY --> REVIEW
    IAM --> REVIEW
    KV --> REVIEW
    MON --> REVIEW
    REL --> REVIEW
```

The review diagram does not imply that GitHub branch protection
or mandatory status checks have been configured.
