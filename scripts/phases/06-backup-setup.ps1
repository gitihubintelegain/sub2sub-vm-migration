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
# 1. Create Unique Vault Name
# -------------------------------------------------------

$uniqueSuffix = (Get-Date -Format "yyyyMMddHHmmss")
$vaultName = "$VMName-vault-$uniqueSuffix"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

Set-AzRecoveryServicesVaultContext -Vault $vault

# -------------------------------------------------------
# 2. Create Backup Policy (Daily 11 AM, 7 days retention)
# -------------------------------------------------------

$policyName = "$VMName-policy"

Write-Host "Creating backup policy..."

$schedulePolicy = New-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType AzureVM
$schedulePolicy.ScheduleRunFrequency = "Daily"
$schedulePolicy.ScheduleRunTimes = @((Get-Date "11:00"))

$retentionPolicy = New-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType AzureVM
$retentionPolicy.DailySchedule.DurationCountInDays = 7
$retentionPolicy.DailySchedule.RetentionTimes = @((Get-Date "11:00"))

$policy = New-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -WorkloadType AzureVM `
    -SchedulePolicy $schedulePolicy `
    -RetentionPolicy $retentionPolicy

Write-Host "Backup policy created."

# -------------------------------------------------------
# 3. Enable Backup
# -------------------------------------------------------

Write-Host "Enabling backup for VM..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

Write-Host "Backup enabled."

# -------------------------------------------------------
# 4. Trigger Initial Backup
# -------------------------------------------------------

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
Write-Host "Backup Setup Completed"
Write-Host "========================================="
