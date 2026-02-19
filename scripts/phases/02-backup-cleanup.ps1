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

$backupItem = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM

if (-not $backupItem) {
    Write-Host "No active backup item found. Skipping."
    return
}

Write-Host "Backup item found."

# If already soft-deleted, skip
if ($backupItem.IsScheduledForDeferredDelete -eq $true -or $backupItem.DeletionState -ne 0) {
    Write-Host "Backup already in soft-delete state. Skipping disable."
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
