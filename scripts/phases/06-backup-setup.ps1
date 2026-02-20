Import-Module Az.RecoveryServices -Force

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
Write-Host "Phase 6 - Backup Setup"
Write-Host "========================================="

Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# ---------------------------------------
# Create Vault
# ---------------------------------------

$uniqueSuffix = Get-Date -Format "yyyyMMddHHmmss"
$vaultName = "$VMName-vault-$uniqueSuffix"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

Set-AzRecoveryServicesVaultContext -Vault $vault

# Disable soft delete for automation safety
Update-AzRecoveryServicesVault `
    -Vault $vault `
    -SoftDeleteFeatureState Disable `
    -Confirm:$false

# ---------------------------------------
# Create Enhanced Policy (Supported Way)
# ---------------------------------------

$policyName = "$VMName-policy"

Write-Host "Creating Enhanced AzureVM backup policy..."

$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType AzureVM `
    -PolicySubType Enhanced

# Now modify supported fields only
$policy.RetentionPolicy.DailySchedule.DurationCountInDays = 7

Set-AzRecoveryServicesBackupProtectionPolicy -Policy $policy

Write-Host "Policy created successfully."

# ---------------------------------------
# Enable Backup
# ---------------------------------------

Write-Host "Enabling backup..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

Write-Host "Backup enabled."

# ---------------------------------------
# Trigger Initial Backup
# ---------------------------------------

$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType AzureVM `
    -FriendlyName $VMName

$item = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM

Backup-AzRecoveryServicesBackupItem -Item $item

Write-Host "Initial backup triggered."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
