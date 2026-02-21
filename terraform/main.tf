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

resource "azurerm_data_protection_backup_vault" "vault" {
  name                = "backup-vault-${var.unique_suffix}"
  resource_group_name = var.resource_group
  location            = var.location

  datastore_type = "VaultStore"
  redundancy     = "LocallyRedundant"
}
