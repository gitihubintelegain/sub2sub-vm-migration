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

Import-Module Az.RecoveryServices -Force
Import-Module Az.Compute -Force

Write-Host "========================================="
Write-Host "Phase 6 - Backup Setup (Az 15.3.0 Final)"
Write-Host "========================================="

# -------------------------------------------------------
# Switch Subscription
# -------------------------------------------------------

Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# -------------------------------------------------------
# Create Recovery Services Vault
# -------------------------------------------------------

$uniqueSuffix = Get-Date -Format "yyyyMMddHHmmss"
$vaultName = "$VMName-vault-$uniqueSuffix"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

# IMPORTANT
Set-AzRecoveryServicesVaultContext -Vault $vault

# Give backend time to initialize vault fabric
Start-Sleep -Seconds 20

# -------------------------------------------------------
# Get Default AzureVM Policy
# -------------------------------------------------------

Write-Host "Retrieving default AzureVM policy..."

$policy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -WorkloadType AzureVM |
    Where-Object { $_.Name -like "*Default*" } |
    Select-Object -First 1

if (-not $policy) {
    throw "Default AzureVM policy not found."
}

Write-Host "Using policy: $($policy.Name)"

# -------------------------------------------------------
# Register VM Container (CRITICAL STEP)
# -------------------------------------------------------

Write-Host "Registering VM container in vault..."

$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup

Register-AzRecoveryServicesBackupContainer `
    -ResourceId $vm.Id `
    -WorkloadType AzureVM | Out-Null

Write-Host "Waiting for container discovery..."

$timeout = 240
$elapsed = 0
$container = $null

do {
    Start-Sleep -Seconds 15
    $container = Get-AzRecoveryServicesBackupContainer `
        -ContainerType AzureVM `
        -FriendlyName $VMName `
        -ErrorAction SilentlyContinue
    $elapsed += 15
} while (-not $container -and $elapsed -lt $timeout)

if (-not $container) {
    throw "VM container registration failed or timed out."
}

Write-Host "Container registered successfully."

# -------------------------------------------------------
# Enable Backup Protection
# -------------------------------------------------------

Write-Host "Enabling backup for VM..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

Write-Host "Backup enable initiated."

# -------------------------------------------------------
# Wait for Protected Item Creation
# -------------------------------------------------------

Start-Sleep -Seconds 20

$item = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM

if (-not $item) {
    throw "Protected item not found after enabling backup."
}

Write-Host "Protection established."

# -------------------------------------------------------
# Trigger Initial Backup
# -------------------------------------------------------

Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem -Item $item

Write-Host "Initial backup triggered successfully."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
