param(
    [string]$SourceSubscription,
    [string]$ResourceGroup,
    [string]$VMName
)

Write-Host "Setting context to source subscription..."
Set-AzContext -SubscriptionId $SourceSubscription

Write-Host "Searching for Recovery Services Vault protecting VM..."

$vaults = Get-AzRecoveryServicesVault
$backupItem = $null
$vaultFound = $null

foreach ($vault in $vaults) {

    Set-AzRecoveryServicesVaultContext -Vault $vault

    # Get all Azure VM containers (no version-sensitive params)
    $containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -ErrorAction SilentlyContinue

    foreach ($container in $containers) {

        # FriendlyName usually equals VM name
        if ($container.FriendlyName -eq $VMName) {

            $items = Get-AzRecoveryServicesBackupItem `
                -Container $container `
                -WorkloadType AzureVM `
                -ErrorAction SilentlyContinue

            if ($items) {
                $backupItem = $items
                $vaultFound = $vault
                break
            }
        }
    }

    if ($backupItem) { break }
}

if (-not $backupItem) {
    Write-Host "No backup protection found. Skipping Phase 2."
    return
}

Write-Host "Backup found in vault: $($vaultFound.Name)"

# Export Backup Policy
$policy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -Name $backupItem.PolicyName `
    -WorkloadType AzureVM

$policyExportPath = "$PSScriptRoot/../../config/exported-policy-$VMName.json"

Write-Host "Exporting backup policy to $policyExportPath"
$policy | ConvertTo-Json -Depth 10 | Out-File $policyExportPath

# Disable Protection and Remove Recovery Points
Write-Host "Disabling backup and removing recovery points..."

Disable-AzRecoveryServicesBackupProtection `
    -Item $backupItem `
    -RemoveRecoveryPoints `
    -Force

# Wait for cleanup
Write-Host "Waiting for protection state to change..."

$maxRetries = 30
$retry = 0
$protectionRemoved = $false

while ($retry -lt $maxRetries) {
    Start-Sleep -Seconds 20

    $itemCheck = Get-AzRecoveryServicesBackupItem `
        -WorkloadType AzureVM `
        -Name $VMName `
        -ErrorAction SilentlyContinue

    if (-not $itemCheck) {
        $protectionRemoved = $true
        break
    }

    Write-Host "Still removing backup... attempt $retry"
    $retry++
}

if (-not $protectionRemoved) {
    throw "Backup removal did not complete within expected time."
}

Write-Host "Backup cleanup completed successfully."
