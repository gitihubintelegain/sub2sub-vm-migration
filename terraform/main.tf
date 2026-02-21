terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------
# Safe Naming
# -----------------------------
locals {
  trimmed_vm_name = substr(var.vm_name, 0, 20)
  vault_name      = "${local.trimmed_vm_name}-rsv-${var.unique_suffix}"
}

# -----------------------------
# Recovery Services Vault (LRS)
# -----------------------------
resource "azurerm_recovery_services_vault" "vault" {
  name                = local.vault_name
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "Standard"

  storage_mode_type   = "LocallyRedundant"
  soft_delete_enabled = true
}

# -----------------------------
# Enhanced Backup Policy (V2)
# -----------------------------
resource "azurerm_backup_policy_vm" "policy" {
  name                = "${local.trimmed_vm_name}-daily-11am-policy"
  resource_group_name = var.resource_group
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

  policy_type = "V2"

  timezone = "India Standard Time"

  backup {
    frequency = "Daily"
    time      = "11:00"
  }

  retention_daily {
    count = 7
  }

  instant_restore_retention_days = 5
}
