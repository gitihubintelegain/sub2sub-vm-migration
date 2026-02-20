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
# 2. Create Vault
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

# Create Standard schedule policy object
$schedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType AzureVM

$schedulePolicy.ScheduleRunFrequency = "Daily"
$schedulePolicy.ScheduleRunTimes.Clear()
$schedulePolicy.ScheduleRunTimes.Add((Get-Date "11:00"))

# Create Standard retention policy object
$retentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType AzureVM

$retentionPolicy.DailySchedule.DurationCountInDays = 7
$retentionPolicy.DailySchedule.RetentionTimes.Clear()
$retentionPolicy.DailySchedule.RetentionTimes.Add((Get-Date "11:00"))

# Create Policy
$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType AzureVM `
    -SchedulePolicy $schedulePolicy `
    -RetentionPolicy $retentionPolicy

Write-Host "Standard policy created successfully."

# -------------------------------------------------------
# 4. Enable Backup
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
