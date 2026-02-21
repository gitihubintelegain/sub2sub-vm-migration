output "vault_name" {
  value = azurerm_recovery_services_vault.vault.name
}

output "policy_name" {
  value = azurerm_backup_policy_vm.policy.name
}
