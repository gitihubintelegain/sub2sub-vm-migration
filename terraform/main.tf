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
# Backup Vault (Data Protection)
# -----------------------------
resource "azurerm_data_protection_backup_vault" "vault" {
  name                = "backup-vault-${var.unique_suffix}"
  resource_group_name = var.resource_group
  location            = var.location

  datastore_type = "VaultStore"
  redundancy     = "LocallyRedundant"
}

# -----------------------------
# Backup Policy (VM)
# -----------------------------
resource "azurerm_data_protection_backup_policy" "policy" {
  name     = "vm-daily-policy"
  vault_id = azurerm_data_protection_backup_vault.vault.id

  backup_repeating_time_intervals = [
    "R/2024-01-01T06:00:00+00:00/P1D"
  ]

  default_retention_rule {
    life_cycle {
      data_store_type = "VaultStore"
      duration        = "P7D"
    }
  }
}

# -----------------------------
# Backup Instance (Protect VM)
# -----------------------------
resource "azurerm_data_protection_backup_instance" "vm_backup" {
  name               = "vm-backup-${var.unique_suffix}"
  vault_id           = azurerm_data_protection_backup_vault.vault.id
  data_source_id     = var.vm_id
  backup_policy_id   = azurerm_data_protection_backup_policy.policy.id
}
