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

Import-Module Az.RecoveryServices -Force
Import-Module Az.Compute -Force

# -------------------------------------------------------
# Switch Subscription
# -------------------------------------------------------

Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# -------------------------------------------------------
# Create Vault (Unique Name)
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
# Create Backup Policy (Module-Compatible Way)
# -------------------------------------------------------

$policyName = "$VMName-policy"

Write-Host "Creating backup policy..."

$schedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject `
    -WorkloadType AzureVM

$retentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject `
    -WorkloadType AzureVM

# -----------------------------
# Handle BOTH object models
# -----------------------------

if ($schedulePolicy.PSObject.Properties.Name -contains "ScheduleRunTimes") {
    # Standard model
    $schedulePolicy.ScheduleRunFrequency = "Daily"
    $schedulePolicy.ScheduleRunTimes = @((Get-Date "11:00"))

    $retentionPolicy.DailySchedule.DurationCountInDays = 7
    $retentionPolicy.DailySchedule.RetentionTimes = @((Get-Date "11:00"))
}
else {
    # Enhanced model
    $schedulePolicy.ScheduleRunFrequency = "Daily"
    $schedulePolicy.ScheduleRunTime = (Get-Date "11:00")

    $retentionPolicy.DailySchedule.DurationCountInDays = 7
    $retentionPolicy.DailySchedule.RetentionTime = (Get-Date "11:00")
}

$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType AzureVM `
    -SchedulePolicy $schedulePolicy `
    -RetentionPolicy $retentionPolicy

Write-Host "Backup policy created."

# -------------------------------------------------------
# Enable Backup
# -------------------------------------------------------

Write-Host "Enabling backup for VM..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

Write-Host "Backup enabled."

# -------------------------------------------------------
# Trigger Initial Backup
# -------------------------------------------------------

Write-Host "Triggering initial backup..."

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
