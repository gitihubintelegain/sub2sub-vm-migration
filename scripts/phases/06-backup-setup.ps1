Import-Module Az.RecoveryServices -Force
Import-Module Az.Compute -Force

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

# -------------------------------------------------------
# 1. Switch Subscription
# -------------------------------------------------------

Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# -------------------------------------------------------
# 2. Create Unique Vault
# -------------------------------------------------------

$uniqueSuffix = Get-Date -Format "yyyyMMddHHmmss"
$vaultName = "$VMName-vault-$uniqueSuffix"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

Set-AzRecoveryServicesVaultContext -Vault $vault

# OPTIONAL (recommended to avoid future migration blocks)
Update-AzRecoveryServicesVault `
    -Vault $vault `
    -SoftDeleteFeatureState Disable `
    -Confirm:$false

# -------------------------------------------------------
# 3. Create Enhanced Backup Policy (Az 15+ Safe)
# -------------------------------------------------------

$policyName = "$VMName-policy"

Write-Host "Creating Enhanced backup policy..."

# Create default Enhanced policy
$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType AzureVM

# Modify schedule
$policy.SchedulePolicy.ScheduleRunFrequency = "Daily"
$policy.SchedulePolicy.ScheduleRunTimes = @((Get-Date "11:00"))

# Modify retention
$policy.RetentionPolicy.DailySchedule.DurationCountInDays = 7
$policy.RetentionPolicy.DailySchedule.RetentionTimes = @((Get-Date "11:00"))

# Commit changes
Set-AzRecoveryServicesBackupProtectionPolicy -Policy $policy

Write-Host "Backup policy created."

# -------------------------------------------------------
# 4. Enable Backup
# -------------------------------------------------------

Write-Host "Enabling backup for VM..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

Write-Host "Backup enabled."

# -------------------------------------------------------
# 5. Trigger Initial Backup
# -------------------------------------------------------

Write-Host "Retrieving container..."

$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType AzureVM `
    -FriendlyName $VMName

$item = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM

Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem -Item $item

Write-Host "Initial backup triggered successfully."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
