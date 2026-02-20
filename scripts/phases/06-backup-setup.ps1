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
Write-Host "Phase 6 - Backup Setup (Az 15.3.0 Corrected)"
Write-Host "========================================="

# Switch subscription
Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# Create vault
$uniqueSuffix = Get-Date -Format "yyyyMMddHHmmss"
$vaultName = "$VMName-vault-$uniqueSuffix"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

Set-AzRecoveryServicesVaultContext -Vault $vault

Start-Sleep -Seconds 20

# Get default AzureVM policy
Write-Host "Retrieving default AzureVM policy..."

$policy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -WorkloadType AzureVM |
    Where-Object { $_.Name -like "*Default*" } |
    Select-Object -First 1

if (-not $policy) {
    throw "Default AzureVM policy not found."
}

Write-Host "Using policy: $($policy.Name)"

# Get VM
$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup

# Register VM container (FIXED LINE)
Write-Host "Registering VM container..."

Register-AzRecoveryServicesBackupContainer `
    -BackupManagementType AzureVM `
    -WorkloadType AzureVM `
    -ResourceId $vm.Id | Out-Null

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

Write-Host "Container registered."

# Enable protection
Write-Host "Enabling backup for VM..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

Write-Host "Backup enable initiated."

Start-Sleep -Seconds 20

$item = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM

if (-not $item) {
    throw "Protected item not found."
}

Write-Host "Protection established."

# Trigger initial backup
Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem -Item $item

Write-Host "Initial backup triggered successfully."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
