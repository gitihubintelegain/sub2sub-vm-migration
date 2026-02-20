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

Import-Module Az.Accounts -Force
Import-Module Az.RecoveryServices -Force
Import-Module Az.Compute -Force

Write-Host "========================================="
Write-Host "Phase 6 - Backup Setup (Enterprise Version)"
Write-Host "========================================="

# ----------------------------------------------------------
# Switch to destination subscription
# ----------------------------------------------------------
Write-Host "Switching subscription..."
Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# ----------------------------------------------------------
# Validate VM exists
# ----------------------------------------------------------
Write-Host "Validating VM..."
$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -ErrorAction Stop
$vaultLocation = $vm.Location

Write-Host "VM found in location: $vaultLocation"

# ----------------------------------------------------------
# Create or Get Recovery Services Vault
# ----------------------------------------------------------
$vaultName = "$VMName-backup-vault"

Write-Host "Checking for existing vault..."

$vault = Get-AzRecoveryServicesVault `
            -ResourceGroupName $ResourceGroup `
            -ErrorAction SilentlyContinue |
         Where-Object { $_.Location -eq $vaultLocation } |
         Select-Object -First 1

if (-not $vault) {
    Write-Host "No vault found. Creating new vault..."
    $vault = New-AzRecoveryServicesVault `
        -Name $vaultName `
        -ResourceGroupName $ResourceGroup `
        -Location $vaultLocation

    Write-Host "Vault created: $($vault.Name)"
} else {
    Write-Host "Using existing vault: $($vault.Name)"
}

# ----------------------------------------------------------
# Set vault context
# ----------------------------------------------------------
Set-AzRecoveryServicesVaultContext -Vault $vault

Write-Host "Waiting for vault backend provisioning..."
Start-Sleep -Seconds 45

# ----------------------------------------------------------
# Get default Azure VM policy
# ----------------------------------------------------------
Write-Host "Retrieving default AzureVM policy..."

$policy = Get-AzRecoveryServicesBackupProtectionPolicy `
            -WorkloadType AzureVM |
          Where-Object { $_.Name -like "*Default*" } |
          Select-Object -First 1

if (-not $policy) {
    throw "Default AzureVM policy not found."
}

Write-Host "Using policy: $($policy.Name)"

# ----------------------------------------------------------
# Check if VM already protected (Idempotent logic)
# ----------------------------------------------------------
Write-Host "Checking if VM is already protected..."

$existingItem = Get-AzRecoveryServicesBackupItem `
                    -WorkloadType AzureVM |
                Where-Object { $_.FriendlyName -eq $VMName }

if ($existingItem) {
    Write-Host "VM is already protected. Skipping enable step."
    $item = $existingItem
}
else {

    # ------------------------------------------------------
    # Wait for VM container registration
    # ------------------------------------------------------
    Write-Host "Discovering VM container in vault..."

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
        Write-Host "Waiting for container registration... ($elapsed sec)"

    } while (-not $container -and $elapsed -lt $timeout)

    if (-not $container) {
        throw "VM container not registered in vault within expected time."
    }

    Write-Host "Container discovered. Enabling protection..."

    Enable-AzRecoveryServicesBackupProtection `
        -Policy $policy `
        -Container $container `
        -Confirm:$false

    Write-Host "Backup enable initiated."

    # ------------------------------------------------------
    # Wait for protected item creation
    # ------------------------------------------------------
    Write-Host "Waiting for protected item..."

    $timeout = 600
    $elapsed = 0
    $item = $null

    do {
        Start-Sleep -Seconds 20
        $item = Get-AzRecoveryServicesBackupItem `
                    -Container $container `
                    -WorkloadType AzureVM
        $elapsed += 20
        Write-Host "Waiting for protection confirmation... ($elapsed sec)"

    } while (-not $item -and $elapsed -lt $timeout)

    if (-not $item) {
        throw "Protected item did not appear within expected time."
    }

    Write-Host "Protection established successfully."
}

# ----------------------------------------------------------
# Trigger initial backup
# ----------------------------------------------------------
Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem `
    -Item $item `
    -Confirm:$false

Write-Host "Initial backup triggered successfully."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
