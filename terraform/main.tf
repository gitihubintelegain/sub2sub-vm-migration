terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------
# Safe Name Handling
# -----------------------------
locals {
  trimmed_vm_name = substr(var.vm_name, 0, 20)
  vault_name      = "${local.trimmed_vm_name}-vault-${var.unique_suffix}"
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
# Enhanced Backup Policy
# -----------------------------
resource "azurerm_backup_policy_vm_enhanced" "policy" {
  name                = "enhanced-daily-policy"
  resource_group_name = var.resource_group
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

  backup {
    frequency = "Daily"
    time      = "06:00"
  }

  retention_daily {
    count = 7
  }
}

# -----------------------------
# Protect VM
# -----------------------------
resource "azurerm_backup_protected_vm" "vm_backup" {
  resource_group_name = var.resource_group
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = var.vm_id
  backup_policy_id    = azurerm_backup_policy_vm_enhanced.policy.id
}
