param(
    [Parameter(Mandatory)]
    [string]$SourceSubscription,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$VMName,

    [Parameter(Mandatory)]
    [string]$SourceVaultName
)

Write-Host "========================================="
Write-Host "Phase 2 - Backup Cleanup"
Write-Host "========================================="

# -------------------------------------------------------
# 1. Set Subscription Context
# -------------------------------------------------------
Write-Host "Setting context to source subscription..."
Set-AzContext -SubscriptionId $SourceSubscription -ErrorAction Stop

# -------------------------------------------------------
# 2. Get Vault
# -------------------------------------------------------
Write-Host "Fetching Recovery Services Vault: $SourceVaultName"
$vault = Get-AzRecoveryServicesVault -Name $SourceVaultName -ErrorAction Stop
Set-AzRecoveryServicesVaultContext -Vault $vault

# -------------------------------------------------------
# 3. Get VM ARM ID
# -------------------------------------------------------
$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -ErrorAction Stop
$vmId = $vm.Id

Write-Host "VM ARM ID: $vmId"

# -------------------------------------------------------
# 4. Locate Active Backup Item (Standard + Enhanced Safe)
# -------------------------------------------------------
Write-Host "Locating active protected backup item..."

$containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -ErrorAction Stop

$backupItem = $null

foreach ($container in $containers) {

    $items = Get-AzRecoveryServicesBackupItem `
        -Container $container `
        -WorkloadType AzureVM `
        -ErrorAction SilentlyContinue

    foreach ($item in $items) {

        if ($item.SourceResourceId -eq $vmId -and $item.ProtectionState -eq 1) {
            $backupItem = $item
            break
        }
    }

    if ($backupItem) { break }
}

if (-not $backupItem) {
    Write-Host "No ACTIVE protected backup item found. Skipping backup cleanup."
    return
}

Write-Host "Active backup item located."

# -------------------------------------------------------
# 5. Resolve Policy (Supports Standard + Enhanced)
# -------------------------------------------------------
Write-Host "Resolving associated backup policy..."

$policy = $null

# First try PolicyId (Standard Policy)
if ($backupItem.PolicyId) {
    Write-Host "PolicyId detected. Resolving via ARM ID..."
    try {
        $policy = Get-AzResource -ResourceId $backupItem.PolicyId -ErrorAction Stop
    }
    catch {
        Write-Host "PolicyId resolution failed. Will try name-based resolution."
    }
}

# Fallback to Policy Name (Enhanced Policy)
if (-not $policy -and $backupItem.ProtectionPolicyName) {
    Write-Host "Resolving via ProtectionPolicyName..."
    try {
        $policy = Get-AzRecoveryServicesBackupProtectionPolicy `
            -Name $backupItem.ProtectionPolicyName `
            -ErrorAction Stop
    }
    catch {
        Write-Host "Name-based resolution failed."
    }
}

# Final fallback — enumerate policies
if (-not $policy) {
    Write-Host "Attempting enumeration-based policy resolution..."
    $allPolicies = Get-AzRecoveryServicesBackupProtectionPolicy
    $policy = $allPolicies | Where-Object {
        $_.WorkloadType -eq "AzureVM"
    } | Select-Object -First 1
}

if (-not $policy) {
    throw "Unable to resolve associated backup policy."
}

# -------------------------------------------------------
# 6. Export Policy to Artifact Path
# -------------------------------------------------------
$policyExportPath = "$env:RUNNER_TEMP/exported-policy-$VMName.json"

Write-Host "Exporting backup policy to $policyExportPath"
$policy | ConvertTo-Json -Depth 25 | Out-File $policyExportPath

Write-Host "Policy export completed."

# -------------------------------------------------------
# 7. Disable Backup + Remove Recovery Points
# -------------------------------------------------------
Write-Host "Disabling backup and removing recovery points..."

Disable-AzRecoveryServicesBackupProtection `
    -Item $backupItem `
    -RemoveRecoveryPoints `
    -Force

# -------------------------------------------------------
# 8. Wait for Protection State Transition
# -------------------------------------------------------
Write-Host "Waiting for backup item to exit Protected state..."

$maxRetries = 30
$retry = 0
$stillProtected = $true

while ($retry -lt $maxRetries -and $stillProtected) {

    Start-Sleep -Seconds 15

    $updatedItems = Get-AzRecoveryServicesBackupItem `
        -Container $container `
        -WorkloadType AzureVM

    $updatedItem = $updatedItems | Where-Object {
        $_.SourceResourceId -eq $vmId
    }

    if (-not $updatedItem -or $updatedItem.ProtectionState -ne 1) {
        $stillProtected = $false
    }

    $retry++
}

if ($stillProtected) {
    throw "Backup disable operation did not complete in expected time."
}

Write-Host "Backup successfully disabled and recovery points removed."
Write-Host "Phase 2 completed successfully."
