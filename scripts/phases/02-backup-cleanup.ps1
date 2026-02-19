param(
    [Parameter(Mandatory)]
    [string]$SourceSubscription,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$VMName,

    [Parameter(Mandatory)]
    [string]$SourceVaultName
)

Write-Host "========================================="
Write-Host "Phase 2 - Disable Backup (No Policy Export)"
Write-Host "========================================="

Set-AzContext -SubscriptionId $SourceSubscription -ErrorAction Stop

$vault = Get-AzRecoveryServicesVault -Name $SourceVaultName -ErrorAction Stop
Set-AzRecoveryServicesVaultContext -Vault $vault

$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -ErrorAction Stop
$vmId = $vm.Id

Write-Host "Locating active protected backup item..."

$items = Get-AzRecoveryServicesBackupItem -WorkloadType AzureVM -ErrorAction Stop

$backupItem = $items | Where-Object {
    $_.SourceResourceId -eq $vmId -and $_.ProtectionState -eq 1
}

if (-not $backupItem) {
    Write-Host "No active protected backup item found. Nothing to disable."
    return
}

Write-Host "Active backup found. Disabling and removing recovery points..."

Disable-AzRecoveryServicesBackupProtection `
    -Item $backupItem `
    -RemoveRecoveryPoints `
    -Force

Write-Host "Waiting for backup to exit protected state..."

$maxRetries = 30
$retry = 0

do {
    Start-Sleep -Seconds 15
    $updatedItems = Get-AzRecoveryServicesBackupItem -WorkloadType AzureVM
    $updatedItem = $updatedItems | Where-Object {
        $_.SourceResourceId -eq $vmId
    }
    $retry++
} while ($updatedItem -and $updatedItem.ProtectionState -eq 1 -and $retry -lt $maxRetries)

if ($updatedItem -and $updatedItem.ProtectionState -eq 1) {
    throw "Backup disable did not complete in expected time."
}

Write-Host "Backup successfully disabled."
