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

Import-Module Az.Accounts -Force
Import-Module Az.Compute -Force
Import-Module Az.RecoveryServices -Force

Write-Host "========================================="
Write-Host "Phase 6 - Backup Setup"
Write-Host "========================================="

# ------------------------------------------------------------
# Switch Subscription
# ------------------------------------------------------------
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
# Get Existing Enhanced Policy (DO NOT CREATE NEW)
# ------------------------------------------------------------
Write-Host "Getting existing Enhanced policy..."

$policy = Get-AzRecoveryServicesBackupProtectionPolicy -WorkloadType AzureVM |
          Where-Object { $_.Name -like "*Enhanced*" } |
          Select-Object -First 1

if (-not $policy) {
    throw "No Enhanced policy found in vault."
}

Write-Host "Using Policy: $($policy.Name)"

# ------------------------------------------------------------
# Check If Already Protected
# ------------------------------------------------------------
Write-Host "Checking container registration..."

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

# Now check protected item
$item = Get-AzRecoveryServicesBackupItem `
            -Container $container `
            -WorkloadType AzureVM `
            -ErrorAction SilentlyContinue

if (-not $item) {

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
