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

Write-Host "========================================="
Write-Host "Phase 6 - Backup Setup (2026 Safe)"
Write-Host "========================================="

Import-Module Az.RecoveryServices -Force
Import-Module Az.Compute -Force

# -------------------------------------------------------
# 1. Switch Subscription
# -------------------------------------------------------

Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# -------------------------------------------------------
# 2. Create Recovery Services Vault (Unique)
# -------------------------------------------------------

$uniqueSuffix = Get-Date -Format "yyyyMMddHHmmss"
$vaultName = "$VMName-vault-$uniqueSuffix"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

Set-AzRecoveryServicesVaultContext -Vault $vault

# -------------------------------------------------------
# 3. Create Enhanced Default Backup Policy
# -------------------------------------------------------

$policyName = "$VMName-policy"

Write-Host "Creating Enhanced backup policy..."

$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType AzureVM

# Modify retention only (supported operation)
$policy.RetentionPolicy.DailySchedule.DurationCountInDays = 7

Set-AzRecoveryServicesBackupProtectionPolicy -Policy $policy

Write-Host "Backup policy created."

# -------------------------------------------------------
# 4. Enable Backup for VM
# -------------------------------------------------------

Write-Host "Enabling backup..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

Write-Host "Backup enabled."

# -------------------------------------------------------
# 5. Trigger Initial Backup
# -------------------------------------------------------

Write-Host "Triggering initial backup..."

$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType AzureVM `
    -FriendlyName $VMName

$item = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM

Backup-AzRecoveryServicesBackupItem -Item $item

Write-Host "Initial backup triggered successfully."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
