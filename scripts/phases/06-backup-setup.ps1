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
Write-Host "Phase 6 - Backup Setup (Use Default Policy)"
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

# Set vault context (CRITICAL)
Set-AzRecoveryServicesVaultContext -Vault $vault

# Wait 10 seconds for vault backend provisioning
Start-Sleep -Seconds 10

# Get default policy created by Azure
Write-Host "Retrieving default backup policy..."

$policy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -WorkloadType AzureVM |
    Where-Object { $_.Name -like "*Default*" } |
    Select-Object -First 1

if (-not $policy) {
    throw "Default AzureVM backup policy not found in vault."
}

Write-Host "Using policy: $($policy.Name)"

# Enable backup
Write-Host "Enabling backup for VM..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

Write-Host "Backup enable initiated."

# Wait for container registration
Start-Sleep -Seconds 15

$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType AzureVM `
    -FriendlyName $VMName

if (-not $container) {
    throw "VM container registration failed."
}

# Trigger initial backup
$item = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM

Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem -Item $item

Write-Host "Initial backup triggered successfully."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
