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
# Recovery Services Vault (LRS)
# -----------------------------
resource "azurerm_recovery_services_vault" "vault" {
  name                = "rsv-${var.unique_suffix}"
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
  name                = "daily-11am-7days-policy"
  resource_group_name = var.resource_group
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

  policy_type = "V2"   # Enhanced policy

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
