param(
    [Parameter(Mandatory)]
    [string]$DestinationSubscription,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$VMName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host "Phase 6 - Backup Setup"
Write-Host "========================================="

# ------------------------------------------------------------
# Ensure latest Az modules (important for GitHub runners)
# ------------------------------------------------------------
Write-Host "Installing latest Az module..."
Install-Module Az -Scope CurrentUser -Force -AllowClobber
Import-Module Az -Force

# ------------------------------------------------------------
# Switch Subscription
# ------------------------------------------------------------
Write-Host "Switching subscription..."
Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# ------------------------------------------------------------
# Validate VM
# ------------------------------------------------------------
$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -ErrorAction Stop
$location = $vm.Location

Write-Host "VM Found in region: $location"

# ------------------------------------------------------------
# Get or Create Vault
# ------------------------------------------------------------
$vaultName = "ubuntu-vault"

$vault = Get-AzRecoveryServicesVault `
            -Name $vaultName `
            -ResourceGroupName $ResourceGroup `
            -ErrorAction SilentlyContinue

if (-not $vault) {
    Write-Host "Creating Recovery Services Vault..."
    $vault = New-AzRecoveryServicesVault `
        -Name $vaultName `
        -ResourceGroupName $ResourceGroup `
        -Location $location
}

Set-AzRecoveryServicesVaultContext -Vault $vault
Start-Sleep -Seconds 30

# ------------------------------------------------------------
# Create Custom Enhanced Policy (Daily 1AM UTC, 30 days)
# ------------------------------------------------------------
$policyName = "Enhanced-Daily-Policy"

$policy = Get-AzRecoveryServicesBackupProtectionPolicy `
            -WorkloadType AzureVM |
          Where-Object { $_.Name -eq $policyName }

if (-not $policy) {

    Write-Host "Creating custom Enhanced policy..."

    # Create Enhanced Policy
    $policy = New-AzRecoveryServicesBackupProtectionPolicy `
        -Name $policyName `
        -WorkloadType AzureVM `
        -PolicySubType Enhanced

    # Configure Daily Schedule
    $policy.SchedulePolicy.ScheduleRunFrequency = "Daily"
    $policy.SchedulePolicy.ScheduleRunTimes.Clear()
    $policy.SchedulePolicy.ScheduleRunTimes.Add((Get-Date "01:00"))

    # Retention 30 days
    $policy.RetentionPolicy.DailySchedule.DurationCountInDays = 30

    Set-AzRecoveryServicesBackupProtectionPolicy -Policy $policy
}

Write-Host "Using Policy: $($policy.Name)"

# ------------------------------------------------------------
# Check if already protected
# ------------------------------------------------------------
$item = Get-AzRecoveryServicesBackupItem `
            -WorkloadType AzureVM |
        Where-Object { $_.FriendlyName -eq $VMName }

if (-not $item) {

    Write-Host "Waiting for container registration..."

    $container = $null
    $timeout = 600
    $elapsed = 0

    do {
        Start-Sleep -Seconds 20

        $container = Get-AzRecoveryServicesBackupContainer `
            -ContainerType AzureVM `
            -Status Registered |
            Where-Object { $_.FriendlyName -eq $VMName }

        $elapsed += 20
        Write-Host "Waiting... $elapsed sec"

    } while (-not $container -and $elapsed -lt $timeout)

    if (-not $container) {
        throw "VM container not registered in vault."
    }

    Write-Host "Enabling backup..."

    Enable-AzRecoveryServicesBackupProtection `
        -Policy $policy `
        -Container $container `
        -Confirm:$false

    Start-Sleep -Seconds 40

    $item = Get-AzRecoveryServicesBackupItem `
                -Container $container `
                -WorkloadType AzureVM
}
else {
    Write-Host "VM already protected."
}

# ------------------------------------------------------------
# Trigger Initial Backup
# ------------------------------------------------------------
Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem `
    -Item $item `
    -Confirm:$false

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
