param(
    [string]$SourceSubscription,
    [string]$ResourceGroup,
    [string]$VMName,
    [string]$SourceVaultName
)

Write-Host "Setting context to source subscription..."
Set-AzContext -SubscriptionId $SourceSubscription

Write-Host "Fetching Recovery Services Vault: $SourceVaultName"

$vault = Get-AzRecoveryServicesVault -Name $SourceVaultName -ErrorAction Stop

Set-AzRecoveryServicesVaultContext -Vault $vault

Write-Host "Locating backup container..."

$container = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM |
    Where-Object { $_.FriendlyName -eq $VMName }

if (-not $container) {
    Write-Host "VM not registered in specified vault. Skipping backup cleanup."
    return
}

$items = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM

$backupItem = $items | Where-Object { $_.ProtectionState -eq 1 }

if (-not $backupItem) {
    Write-Host "No active protected backup item found. Skipping."
    return
}

Write-Host "Backup item found."

# If already soft-deleted, skip
if ($backupItem.ProtectionState -ne 1) {
    Write-Host "Backup not in Protected state. Current state: $($backupItem.ProtectionState). Skipping."
    return
}

Write-Host "Active backup detected."

$policyArmId = $backupItem.PolicyId

if (-not $policyArmId) {
    throw "PolicyId missing for active backup item."
}

Write-Host "Exporting policy..."
$policy = Get-AzResource -ResourceId $policyArmId -ErrorAction Stop
$policyExportPath = "$env:RUNNER_TEMP/exported-policy-$VMName.json"
$policy | ConvertTo-Json -Depth 20 | Out-File $policyExportPath
Write-Host "Policy exported to $policyExportPath"

Write-Host "Disabling backup and removing recovery points..."
Disable-AzRecoveryServicesBackupProtection `
    -Item $backupItem `
    -RemoveRecoveryPoints `
    -Force

Write-Host "Backup cleanup initiated."
