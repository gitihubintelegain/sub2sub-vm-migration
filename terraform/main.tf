provider "azurerm" {
  features {}
}

resource "azurerm_recovery_services_vault" "vault" {
  name                = "${var.vm_name}-vault-${var.unique_suffix}"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "Standard"
}

resource "azurerm_backup_policy_vm" "policy" {
  name                = "daily-1130-7days-policy"
  resource_group_name = var.resource_group
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

  backup {
    frequency = "Daily"
    time      = "11:30"
  }

  retention_daily {
    count = 7
  }
}

resource "azurerm_backup_protected_vm" "vm_backup" {
  resource_group_name = var.resource_group
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = var.vm_id
  backup_policy_id    = azurerm_backup_policy_vm.policy.id
}
