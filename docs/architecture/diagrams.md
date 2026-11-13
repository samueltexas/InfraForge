# Architecture Diagrams

> Visual identity: Dark Cloud Engineering
> Palette: Midnight Navy, Electric Cyan, Azure Blue and Ice White.

These diagrams represent the Terraform configurations and engineering
workflows implemented in this repository. They do not represent a live
Azure deployment.

## 1. Azure Infrastructure Architecture

The integrated architecture connects five reusable Terraform modules, including a shared Resource Group foundation.
Networking provides connectivity, Identity provides managed access,
Key Vault protects application secrets, and Monitoring provides
diagnostics and observability.

```mermaid
%%{init: {"theme":"base","themeVariables":{"background":"#071426","primaryColor":"#102B46","primaryTextColor":"#F2F7FC","primaryBorderColor":"#00D5F5","lineColor":"#00C9E8","secondaryColor":"#123653","tertiaryColor":"#0B2038","fontFamily":"Inter, Arial","fontSize":"14px"}}}%%
flowchart TB
    ROOT["InfraForge<br/>Integrated Terraform Architecture"]

    subgraph AZURE["MICROSOFT AZURE FOUNDATION"]
        direction LR

        subgraph NETWORK["01 · NETWORKING"]
            VNET["Virtual Network"]
            SUBNET["Application Subnet"]
            PRIVATE["Private Endpoint Subnet"]
            NSG["Network Security Groups"]
            VNET --> SUBNET
            VNET --> PRIVATE
            SUBNET -.-> NSG
        end

        subgraph IDENTITY["02 · IDENTITY & ACCESS"]
            UAMI["User-Assigned<br/>Managed Identity"]
            RBAC["Scoped Azure RBAC"]
            UAMI --> RBAC
        end

        subgraph KEYVAULT["03 · SECRETS MANAGEMENT"]
            KV["Azure Key Vault"]
            PE["Private Endpoint"]
            DNS["Private DNS"]
            KV --> PE
            PE --> DNS
        end

        subgraph MONITORING["04 · MONITORING"]
            LAW["Log Analytics<br/>Workspace"]
            DIAG["Diagnostic Settings"]
            AMPLS["Azure Monitor<br/>Private Link Scope"]
            ALERTS["Metric Alerts<br/>and Action Group"]
            DIAG --> LAW
            LAW --> AMPLS
            LAW --> ALERTS
        end
    end

    ROOT --> NETWORK
    ROOT --> IDENTITY
    ROOT --> KEYVAULT
    ROOT --> MONITORING

    PRIVATE --> PE
    UAMI -->|"Authorized access"| KV
    KV -->|"Audit diagnostics"| DIAG

    classDef root fill:#123B62,stroke:#00D5F5,color:#FFFFFF,stroke-width:2px
    classDef network fill:#102D4A,stroke:#25BFFF,color:#FFFFFF
    classDef identity fill:#123653,stroke:#43C6FF,color:#FFFFFF
    classDef vault fill:#302B23,stroke:#E6B65A,color:#FFFFFF
    classDef monitoring fill:#102F3D,stroke:#00D5F5,color:#FFFFFF

    class ROOT root
    class VNET,SUBNET,PRIVATE,NSG network
    class UAMI,RBAC identity
    class KV,PE,DNS vault
    class LAW,DIAG,AMPLS,ALERTS monitoring
```

## 2. DevSecOps CI/CD Pipeline

The pipeline validates infrastructure changes before they are
considered ready for review and merge.

```mermaid
%%{init: {"theme":"base","themeVariables":{"background":"#071426","primaryColor":"#102B46","primaryTextColor":"#F2F7FC","primaryBorderColor":"#00D5F5","lineColor":"#00C9E8","secondaryColor":"#123653","tertiaryColor":"#0B2038","fontFamily":"Inter, Arial","fontSize":"14px"}}}%%
flowchart TB
    DEV["Developer"]
    PR["GitHub Pull Request"]
    CI["GitHub Actions"]

    DEV --> PR --> CI

    subgraph VALIDATION["AUTOMATED VALIDATION"]
        direction LR
        TF["Terraform<br/>Format & Validate"]
        LINT["TFLint<br/>Static Analysis"]
        SCAN["Checkov<br/>Security Scanning"]
    end

    subgraph SECURITY["SECURITY & POLICY"]
        direction LR
        OPA["OPA<br/>Policy Validation"]
        POLICY["Terraform<br/>Security Tests"]
        IAM["Azure IAM<br/>Security Tests"]
        KV["Key Vault<br/>Security Tests"]
        MON["Monitoring<br/>Security Tests"]
    end

    REL["Infrastructure Reliability<br/>Python Tests"]

    CI --> TF
    CI --> LINT
    CI --> SCAN
    CI --> OPA
    CI --> POLICY
    CI --> IAM
    CI --> KV
    CI --> MON
    CI --> REL

    TF --> REVIEW["Human Review"]
    LINT --> REVIEW
    SCAN --> REVIEW
    OPA --> REVIEW
    POLICY --> REVIEW
    IAM --> REVIEW
    KV --> REVIEW
    MON --> REVIEW
    REL --> REVIEW

    REVIEW --> MERGE["Merge after successful<br/>checks and review"]

    classDef entry fill:#123B62,stroke:#00D5F5,color:#FFFFFF,stroke-width:2px
    classDef validation fill:#102D4A,stroke:#25BFFF,color:#FFFFFF
    classDef security fill:#302B23,stroke:#E6B65A,color:#FFFFFF
    classDef result fill:#123B3A,stroke:#35D39A,color:#FFFFFF,stroke-width:2px

    class DEV,PR,CI entry
    class TF,LINT,SCAN,REL validation
    class OPA,POLICY,IAM,KV,MON security
    class REVIEW,MERGE result
```

The diagram represents the validation workflow. It does not imply
that GitHub branch protection or mandatory status checks have
been configured.

## 3. Developer Workload Integration

This example demonstrates how an application team can consume the
outputs exposed by InfraForge's reusable Terraform modules.

```mermaid
%%{init: {"theme":"base","themeVariables":{"background":"#071426","primaryColor":"#102B46","primaryTextColor":"#F2F7FC","primaryBorderColor":"#00D5F5","lineColor":"#00C9E8","secondaryColor":"#123653","tertiaryColor":"#0B2038","fontFamily":"Inter, Arial","fontSize":"14px"}}}%%
flowchart TB
    subgraph PLATFORM["INFRAFORGE · REUSABLE MODULES"]
        RG["Resource Group Module"]
        NET["Networking Module"]
        IAM["Identity Module"]
        KV["Key Vault Module"]
        MON["Monitoring Module"]
    end

    subgraph OUTPUTS["TERRAFORM MODULE OUTPUTS"]
        SUBNET["Application Subnet ID"]
        CLIENT["Managed Identity Client ID"]
        VAULT["Key Vault URI"]
        WORKSPACE["Monitoring Resource IDs"]
    end

    subgraph APP["APPLICATION WORKLOAD"]
        APPRESOURCE["Application Infrastructure"]
        AUTH["Managed Identity Authentication"]
        CONFIG["Application Configuration"]
        OBS["Logs and Diagnostics"]
    end

    RG --> NET
    RG --> IAM
    RG --> KV
    RG --> MON
    NET --> SUBNET
    IAM --> CLIENT
    KV --> VAULT
    MON --> WORKSPACE

    SUBNET --> APPRESOURCE
    CLIENT --> AUTH
    VAULT --> CONFIG
    WORKSPACE --> OBS

    APPRESOURCE --> AUTH
    AUTH --> CONFIG
    APPRESOURCE --> OBS

    classDef module fill:#102D4A,stroke:#25BFFF,color:#FFFFFF
    classDef output fill:#123653,stroke:#00D5F5,color:#FFFFFF
    classDef app fill:#302B23,stroke:#E6B65A,color:#FFFFFF

    class NET,IAM,KV,MON module
    class SUBNET,CLIENT,VAULT,WORKSPACE output
    class APPRESOURCE,AUTH,CONFIG,OBS app
```

### Integration contract

| Module | Application-facing output |
|---|---|
| Networking | Application subnet ID |
| Identity | Managed identity client ID |
| Key Vault | Key Vault URI |
| Monitoring | Workspace and monitoring resource IDs |

The example demonstrates Terraform composition and output
consumption. It does not deploy an application or prove
runtime connectivity to Azure.

---

## Architecture validation boundaries

- Terraform formatting and configuration validation are local checks.
- Python tests validate infrastructure contracts and security assumptions.
- CI/CD checks validate repository configurations and policies.
- Azure deployment and runtime connectivity require separate verification.
- No Azure resources are provisioned by these diagrams.

## Technology foundation

Terraform · Microsoft Azure · GitHub Actions · Docker · Python ·
Checkov · TFLint · Open Policy Agent

**Author:** Samuel Texa
