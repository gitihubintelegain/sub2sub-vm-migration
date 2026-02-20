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

Write-Host "========================================="
Write-Host "Phase 6 - Backup Setup"
Write-Host "========================================="

Set-AzContext -SubscriptionId $DestinationSubscription -ErrorAction Stop | Out-Null

# -------------------------------------------------------
# 1. Generate Unique Vault Name
# -------------------------------------------------------

$shortId = ([guid]::NewGuid().ToString().Substring(0,8))
$vaultName = "$VMName-vault-$shortId"

Write-Host "Vault Name: $vaultName"

# -------------------------------------------------------
# 2. Create Vault
# -------------------------------------------------------

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

Set-AzRecoveryServicesVaultContext -Vault $vault

# -------------------------------------------------------
# 3. Create Policy (Modern Method)
# -------------------------------------------------------

$policyName = "$VMName-policy"

Write-Host "Creating backup policy..."

# Get default template
$templatePolicy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -WorkloadType AzureVM | 
    Where-Object { $_.Name -like "*Default*" } | 
    Select-Object -First 1

if (-not $templatePolicy) {
    throw "Unable to retrieve default AzureVM backup policy template."
}

# Clone template
$policy = $templatePolicy

# Schedule
$policy.SchedulePolicy.ScheduleRunFrequency = "Daily"
$policy.SchedulePolicy.ScheduleRunTimes.Clear()
$policy.SchedulePolicy.ScheduleRunTimes.Add((Get-Date "11:00"))

# Retention
$policy.RetentionPolicy.DailySchedule.DurationCountInDays = 7
$policy.RetentionPolicy.DailySchedule.RetentionTimes.Clear()
$policy.RetentionPolicy.DailySchedule.RetentionTimes.Add((Get-Date "11:00"))

# Instant Restore (Enhanced policy only)
if ($policy.InstantRPDetails) {
    $policy.InstantRPDetails.RecoveryPointRetentionInDays = 5
}

# Create new policy
$policy.Name = $policyName

$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType AzureVM `
    -SchedulePolicy $policy.SchedulePolicy `
    -RetentionPolicy $policy.RetentionPolicy

# -------------------------------------------------------
# 4. Enable Backup
# -------------------------------------------------------

Write-Host "Enabling backup..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

# -------------------------------------------------------
# 5. Trigger Initial Backup
# -------------------------------------------------------

$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType AzureVM `
    -FriendlyName $VMName

$item = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM

Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem -Item $item

Write-Host "Initial backup triggered."

Write-Host "========================================="
Write-Host "Backup Setup Completed"
Write-Host "========================================="
