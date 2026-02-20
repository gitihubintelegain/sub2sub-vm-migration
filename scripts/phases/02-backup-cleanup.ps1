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

Write-Host "Locating backup container..."

$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType AzureVM `
    -Status Registered `
    | Where-Object { $_.FriendlyName -eq $VMName }

if (-not $container) {
    Write-Host "No registered backup container found for VM."
    return
}

Write-Host "Container found."

Write-Host "Locating protected backup item..."

$backupItem = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM `
    -ErrorAction SilentlyContinue

if (-not $backupItem) {
    Write-Host "No active protected backup item found."
    return
}

if ($backupItem.ProtectionState -ne 1) {
    Write-Host "Backup exists but not in Protected state. Current state: $($backupItem.ProtectionState)"
    return
}

Write-Host "Active backup found. Disabling and removing recovery points..."

Disable-AzRecoveryServicesBackupProtection `
    -Item $backupItem `
    -RemoveRecoveryPoints `
    -Force

Write-Host "Waiting for backup to exit protected state..."

$maxRetries = 40
$retry = 0

do {
    Start-Sleep -Seconds 15

    $container = Get-AzRecoveryServicesBackupContainer `
        -ContainerType AzureVM `
        -Status Registered `
        | Where-Object { $_.FriendlyName -eq $VMName }

    if ($container) {
        $updatedItem = Get-AzRecoveryServicesBackupItem `
            -Container $container `
            -WorkloadType AzureVM `
            -ErrorAction SilentlyContinue
    } else {
        $updatedItem = $null
    }

    $retry++

} while ($updatedItem -and $updatedItem.ProtectionState -eq 1 -and $retry -lt $maxRetries)

if ($updatedItem -and $updatedItem.ProtectionState -eq 1) {
    throw "Backup disable did not complete in expected time."
}

Write-Host "Backup successfully disabled."
