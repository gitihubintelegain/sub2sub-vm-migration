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
Write-Host "Phase 6 - Backup Setup (Standard Policy)"
Write-Host "========================================="

Import-Module Az.RecoveryServices -Force
Import-Module Az.Compute -Force

# -------------------------------------------------------
# 1. Switch Subscription
# -------------------------------------------------------

Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# -------------------------------------------------------
# 2. Create Unique Recovery Services Vault
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
# 3. Create STANDARD Backup Policy
# -------------------------------------------------------

$policyName = "$VMName-policy"

Write-Host "Creating STANDARD AzureVM backup policy..."

# Explicitly request Standard subtype objects
$schedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject `
    -WorkloadType AzureVM `
    -PolicySubType Standard

$schedulePolicy.ScheduleRunFrequency = "Daily"
$schedulePolicy.ScheduleRunTimes = @((Get-Date "11:00"))

$retentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject `
    -WorkloadType AzureVM `
    -PolicySubType Standard

$retentionPolicy.DailySchedule.DurationCountInDays = 7
$retentionPolicy.DailySchedule.RetentionTimes = @((Get-Date "11:00"))

$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType AzureVM `
    -PolicySubType Standard `
    -SchedulePolicy $schedulePolicy `
    -RetentionPolicy $retentionPolicy

Write-Host "Standard backup policy created successfully."

# -------------------------------------------------------
# 4. Enable Backup for VM
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

Write-Host "Retrieving backup container..."

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
