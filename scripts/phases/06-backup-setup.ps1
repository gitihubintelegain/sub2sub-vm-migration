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

# -------------------------------------------------------
# 2. Create Backup Policy (Enhanced Model - Az 15+ Safe)
# -------------------------------------------------------

# -------------------------------------------------------
# 2. Create Backup Policy (Enhanced Model - 2026 Safe)
# -------------------------------------------------------

$policyName = "$VMName-policy"

$existingPolicy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -ErrorAction SilentlyContinue

if (-not $existingPolicy) {

    Write-Host "Creating Enhanced backup policy..."

    # Create default Enhanced policy
    $policy = New-AzRecoveryServicesBackupProtectionPolicy `
        -Name $policyName `
        -WorkloadType AzureVM

    # Modify schedule (Daily 11 AM)
    $policy.SchedulePolicy.ScheduleRunFrequency = "Daily"
    $policy.SchedulePolicy.ScheduleRunTimes = @((Get-Date "11:00"))

    # Modify retention (7 days)
    $policy.RetentionPolicy.DailySchedule.DurationCountInDays = 7
    $policy.RetentionPolicy.DailySchedule.RetentionTimes = @((Get-Date "11:00"))

    # Commit changes
    Set-AzRecoveryServicesBackupProtectionPolicy -Policy $policy
}
else {
    Write-Host "Policy already exists."
    $policy = $existingPolicy
}

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
