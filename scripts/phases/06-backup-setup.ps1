param(
    [Parameter(Mandatory)]
    [string]$DestinationSubscription,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$VMName,

    [Parameter(Mandatory)]
    [string]$Location
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module Az.RecoveryServices -Force
Import-Module Az.Compute -Force

Write-Host "========================================="
Write-Host "Phase 6 - Backup Setup (Final Clean)"
Write-Host "========================================="

# Switch subscription
Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# Create vault
$uniqueSuffix = Get-Date -Format "yyyyMMddHHmmss"
$vaultName = "$VMName-vault-$uniqueSuffix"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

# Set vault context
Set-AzRecoveryServicesVaultContext -Vault $vault

# Wait for vault backend provisioning
Start-Sleep -Seconds 30

# Get default AzureVM policy
Write-Host "Retrieving default AzureVM policy..."

$policy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -WorkloadType AzureVM |
    Where-Object { $_.Name -like "*Default*" } |
    Select-Object -First 1

if (-not $policy) {
    throw "Default AzureVM policy not found."
}

Write-Host "Using policy: $($policy.Name)"

# Enable protection (THIS handles container registration internally)
Write-Host "Enabling backup for VM..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup `
    -Confirm:$false

Write-Host "Backup enable initiated."

# Wait for protected item to appear
$timeout = 240
$elapsed = 0
$item = $null

do {
    Start-Sleep -Seconds 15
    $item = Get-AzRecoveryServicesBackupItem `
        -WorkloadType AzureVM |
        Where-Object { $_.Name -eq $VMName }
    $elapsed += 15
} while (-not $item -and $elapsed -lt $timeout)

if (-not $item) {
    throw "Protected item did not appear within expected time."
}

Write-Host "Protection established."

# Trigger initial backup
Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem -Item $item -Confirm:$false

Write-Host "Initial backup triggered successfully."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
