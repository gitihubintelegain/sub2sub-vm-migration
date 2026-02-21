terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.110.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------
# Backup Vault (Modern)
# -----------------------------
resource "azurerm_data_protection_backup_vault" "vault" {
  name                = "backup-vault-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group

  datastore_type = "VaultStore"
  redundancy     = "LocallyRedundant"
}

# -----------------------------
# Backup Policy for Azure VM
# -----------------------------
resource "azurerm_data_protection_backup_policy_azure_vm" "policy" {
  name     = "vm-daily-policy"
  vault_id = azurerm_data_protection_backup_vault.vault.id

  backup_repeating_time_intervals = ["R/2024-01-01T06:00:00+00:00/P1D"]

  retention_rule {
    name     = "DailyRetention"
    priority = 1

    criteria {
      absolute_criteria = "FirstOfDay"
    }

    life_cycle {
      duration        = "P7D"
      data_store_type = "VaultStore"
    }
  }

  default_retention_rule {
    life_cycle {
      duration        = "P7D"
      data_store_type = "VaultStore"
    }
  }
}

# -----------------------------
# Backup Instance
# -----------------------------
resource "azurerm_data_protection_backup_instance_azure_vm" "vm_backup" {
  name               = "vm-backup-${var.unique_suffix}"
  vault_id           = azurerm_data_protection_backup_vault.vault.id
  source_resource_id = var.vm_id

  backup_policy_id = azurerm_data_protection_backup_policy_azure_vm.policy.id
}
