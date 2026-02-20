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
Write-Host "Phase 6 - Backup Setup (Az 15.3.0 Stable)"
Write-Host "========================================="

Import-Module Az.RecoveryServices -Force
Import-Module Az.Compute -Force

# -------------------------------------------------------
# Switch Subscription
# -------------------------------------------------------
Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# -------------------------------------------------------
# Create Vault
# -------------------------------------------------------
$uniqueSuffix = Get-Date -Format "yyyyMMddHHmmss"
$vaultName = "$VMName-vault-$uniqueSuffix"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

# CRITICAL
Set-AzRecoveryServicesVaultContext -Vault $vault

# -------------------------------------------------------
# Create Policy (Enhanced default model)
# -------------------------------------------------------

Write-Host "Preparing schedule and retention policy..."

$schedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject `
    -WorkloadType AzureVM

$retentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject `
    -WorkloadType AzureVM

# SAFE modification (retention only)
$retentionPolicy.DailySchedule.DurationCountInDays = 7

$policyName = "$VMName-policy"

Write-Host "Creating backup policy..."

$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType AzureVM `
    -SchedulePolicy $schedulePolicy `
    -RetentionPolicy $retentionPolicy

Write-Host "Policy created."

# -------------------------------------------------------
# Enable Backup (Handles container registration internally)
# -------------------------------------------------------

Write-Host "Enabling backup for VM..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

Write-Host "Backup enable initiated."

# -------------------------------------------------------
# Wait for container registration
# -------------------------------------------------------

Write-Host "Waiting for VM container registration..."

$timeout = 120
$elapsed = 0

do {
    Start-Sleep -Seconds 10
    $container = Get-AzRecoveryServicesBackupContainer `
        -ContainerType AzureVM `
        -FriendlyName $VMName `
        -ErrorAction SilentlyContinue
    $elapsed += 10
} while (-not $container -and $elapsed -lt $timeout)

if (-not $container) {
    throw "VM container registration did not complete in expected time."
}

Write-Host "Container registered."

# -------------------------------------------------------
# Trigger Initial Backup
# -------------------------------------------------------

$item = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM

Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem -Item $item

Write-Host "Initial backup triggered successfully."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
