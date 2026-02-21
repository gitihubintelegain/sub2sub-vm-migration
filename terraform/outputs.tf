output "vault_name" {
  value = azurerm_data_protection_backup_vault.vault.name
}

output "policy_id" {
  value = azurerm_data_protection_backup_policy_azure_vm.policy.id
}
