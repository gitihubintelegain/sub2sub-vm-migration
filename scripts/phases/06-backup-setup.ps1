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
# Create Unique Vault
# ------------------------------------------------------------
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$vaultName = "$VMName-vault-$timestamp"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $location

Set-AzRecoveryServicesVaultContext -Vault $vault

Write-Host "Waiting for vault backend initialization..."
Start-Sleep -Seconds 60

# ------------------------------------------------------------
# Get Existing Enhanced Policy (auto-created by Azure)
# ------------------------------------------------------------
Write-Host "Retrieving Enhanced policy..."

$policy = $null
$timeout = 300
$elapsed = 0

do {
    Start-Sleep -Seconds 15

    $policies = Get-AzRecoveryServicesBackupProtectionPolicy `
        -WorkloadType AzureVM

    $policy = $policies | Where-Object {
        $_.Name -like "*Enhanced*"
    } | Select-Object -First 1

    $elapsed += 15
    Write-Host "Waiting for policy availability... $elapsed sec"

} while (-not $policy -and $elapsed -lt $timeout)

if (-not $policy) {
    throw "Enhanced policy not found in vault."
}

Write-Host "Using Policy: $($policy.Name)"

# ------------------------------------------------------------
# Wait for Container Registration
# ------------------------------------------------------------
Write-Host "Waiting for container registration..."

$container = $null
$timeout = 120
$elapsed = 0

do {
    Start-Sleep -Seconds 20

    $containers = Get-AzRecoveryServicesBackupContainer `
        -ContainerType AzureVM

    $container = $containers | Where-Object {
        $_.FriendlyName -eq $VMName
    }

    $elapsed += 20
    Write-Host "Waiting... $elapsed sec"

} while (-not $container -and $elapsed -lt $timeout)

if (-not $container) {
    throw "VM container not found in vault."
}

# ------------------------------------------------------------
# Check If Already Protected
# ------------------------------------------------------------
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

    Write-Host "Waiting for protected item creation..."
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
