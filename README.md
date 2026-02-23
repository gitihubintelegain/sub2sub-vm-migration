# 🚀 Azure Subscription-to-Subscription VM Migration Automation

**GitHub Actions + OIDC + Terraform + CLI + PowerShell (Enterprise-Ready)**

------------------------------------------------------------------------

## 📌 Overview

This repository provides a fully automated, secure, and structured
solution to migrate Azure Virtual Machines between subscriptions within
the same Azure AD tenant.

The migration framework is built using:

-   GitHub Actions (CI/CD orchestration)
-   OIDC-based authentication (no secrets stored)
-   Terraform (backup vault provisioning)
-   PowerShell phase-based migration scripts
-   Azure Resource Manager (Move-AzResource)
-   Integrated Backup Handling (Recovery Services Vault)
-   Azure CLI (backup enablement & trigger)

Designed for enterprise production environments with governance and
security best practices.

------------------------------------------------------------------------

## 🏗 High-Level Architecture Flow

GitHub Actions\
↓ (OIDC Token)\
Azure AD (Federated Service Principal)\
↓\
Terraform (Vault + Policy Provisioning)\
↓\
Azure Resource Manager\
↓\
PowerShell Migration Phases\
↓\
Azure CLI (Enable & Trigger Backup)\
↓\
Destination Subscription (VM + Resources)

------------------------------------------------------------------------

## 📁 Repository Structure

    .
    ├── .github/workflows/
    │   ├── migrate.yml
    │   └── test-azure-login.yml
    │
    ├── config/
    │   └── migration-config.json
    │
    ├── scripts/
    │   ├── main.ps1
    │   └── phases/
    │       ├── 01-validate.ps1
    │       ├── 02-backup-cleanup.ps1
    │       ├── 03-prepare-for-move.ps1
    │       ├── 04-move-resources.ps1
    │       └── 05-post-move.ps1
    │
    ├── terraform/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf

------------------------------------------------------------------------

## 🔐 Authentication Model (OIDC Federation)

This project uses GitHub OpenID Connect (OIDC) authentication with a
federated Azure Service Principal bound to the `main` branch.

Security Characteristics:

-   No client secrets stored
-   No long-lived credentials
-   Short-lived secure tokens
-   Branch-restricted access
-   RBAC-controlled permissions

### Required GitHub Secrets

Configure in:

Repository → Settings → Secrets and Variables → Actions

    AZURE_CLIENT_ID
    AZURE_TENANT_ID
    AZURE_SUBSCRIPTION_ID

Do NOT configure `AZURE_CLIENT_SECRET`.

------------------------------------------------------------------------

## 🏗 Terraform 

Terraform ensures:

-   Recovery Services Vault is created
-   Backup policies are created & applied

### Terraform Lifecycle (CI Integrated)

    terraform init
    terraform validate
    terraform plan
    terraform apply -auto-approve

------------------------------------------------------------------------

## 💾 Azure CLI Backup Operations

After migration, Azure CLI is used to enable and trigger backup.

### Enable Backup

az backup protection enable-for-vm --resource-group \$RG --vault-name
${VM}-rsv-${SUFFIX} --vm \$VM --policy-name \${VM}-daily-11am-policy

### Trigger Initial Backup

az backup protection backup-now --resource-group \$RG --vault-name
${VM}-rsv-${SUFFIX} --container-name \$VM --item-name \$VM
--backup-management-type AzureIaasVM

------------------------------------------------------------------------

## ⚙️ Azure Prerequisites

Before execution:

-   Source and destination subscriptions must be in same tenant
-   Service Principal must have Contributor role on both subscriptions
-   Backup Contributor role (if backup phase used)
-   No resource locks
-   No blocking Azure Policies
-   VM must not be classic deployment
-   Dependent resources must be movable

------------------------------------------------------------------------

## 🧾 Configuration File

Edit:

`config/migration-config.json`

Example:

``` json
{
  "vmName": "myVM",
  "sourceSubscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "destinationSubscriptionId": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
  "sourceResourceGroup": "source-rg",
  "sourceVaultName": "source-rsv",
  "location": "centralindia"
}
```

------------------------------------------------------------------------

## 🔁 Migration Workflow Execution

GitHub → Actions → Sub2Sub VM Migration → Run Workflow

### 📋 Available Phases

| Phase        | Description                         |
|-------------|-------------------------------------|
| validate    | Validate VM and dependencies        |
| backup      | Handle backup cleanup               |
| prepare     | Prepare VM for move                 |
| move        | Execute Move-AzResource             |
| post        | Post-migration validation           |
| backupsetup | Enable backup in destination        |
| all         | Full migration lifecycle            |

------------------------------------------------------------------------

## 📊 Complete Migration Flow

Terraform Provisioning\
↓\
Validate\
↓\
Backup Cleanup\
↓\
Prepare\
↓\
Move Resources\
↓\
Post Validation\
↓\
Backup Setup

------------------------------------------------------------------------

## 🚨 Known Limitations

-   Cross-tenant migration not supported
-   Azure Policies may block move
-   Some resource types are non-movable
-   Marketplace plan VMs may require revalidation
-   VM extensions may require post-move checks

------------------------------------------------------------------------

## 🛡 Security Design Summary

| Component              | Implementation        |
|------------------------|-----------------------|
| Authentication         | GitHub OIDC           |
| Secret Storage         | None                  |
| Token Lifetime         | Short-lived           |
| Branch Restriction     | main                  |
| Backup Provisioning & Policy   | Terraform     |
| Resource Move          | Azure Resource Manager |
| Backup Enable & Start  | Azure CLI             |

------------------------------------------------------------------------

## 🎯 Use Cases

-   Subscription restructuring
-   Landing zone realignment
-   Migration due to cost factors
-   Enterprise Azure modernization

------------------------------------------------------------------------

## 👨‍💻 Maintainer

Enterprise-grade Azure VM migration automation built by Darshan Thenge 
using GitHub Actions, Terraform, OIDC federation, Azure CLI and 
structured PowerShell execution.
