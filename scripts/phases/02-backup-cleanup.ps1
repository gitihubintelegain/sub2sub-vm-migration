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
Write-Host "Phase 2 - Disable Backup (No Policy Export)"
Write-Host "========================================="

Set-AzContext -SubscriptionId $SourceSubscription -ErrorAction Stop

$vault = Get-AzRecoveryServicesVault -Name $SourceVaultName -ErrorAction Stop
Set-AzRecoveryServicesVaultContext -Vault $vault

Write-Host "Locating backup container..."

$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType AzureVM `
    -FriendlyName $VMName `
    -ErrorAction SilentlyContinue

if (-not $container) {
    Write-Host "No registered backup container found for VM."
    return
}

Write-Host "Container found."

Write-Host "Locating protected backup item..."

$backupItem = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM `
    -ErrorAction SilentlyContinue

if (-not $backupItem) {
    Write-Host "No active protected backup item found."
    return
}

if ($backupItem.ProtectionState -ne "Protected") {
    Write-Host "Backup exists but not in Protected state. Current state: $($backupItem.ProtectionState)"
    return
}

Write-Host "Active backup found. Disabling and removing recovery points..."

Disable-AzRecoveryServicesBackupProtection `
    -Item $backupItem `
    -RemoveRecoveryPoints `
    -Force

Write-Host "Waiting for backup to exit protected state..."

$maxRetries = 40
$retry = 0

do {
    Start-Sleep -Seconds 15

    $container = Get-AzRecoveryServicesBackupContainer `
        -ContainerType AzureVM `
        -FriendlyName $VMName `
        -ErrorAction SilentlyContinue

    if ($container) {
        $updatedItem = Get-AzRecoveryServicesBackupItem `
            -Container $container `
            -WorkloadType AzureVM `
            -ErrorAction SilentlyContinue
    }
    else {
        $updatedItem = $null
    }

    $retry++

} while ($updatedItem -and $updatedItem.ProtectionState -eq "Protected" -and $retry -lt $maxRetries)

Write-Host "Backup successfully disabled."

Write-Host "Searching for Restore Point Collections..."

$backupRGs = Get-AzResourceGroup | Where-Object {
    $_.ResourceGroupName -like "AzureBackupRG_*"
}

foreach ($brg in $backupRGs) {

    Write-Host "Checking RG: $($brg.ResourceGroupName)"

    $rpcResources = Get-AzResource `
        -ResourceGroupName $brg.ResourceGroupName `
        -ResourceType "Microsoft.Compute/restorePointCollections" `
        -ErrorAction SilentlyContinue

    foreach ($rpc in $rpcResources) {

        if ($rpc.Name -like "AzureBackup_$VMName*") {

            Write-Host "Processing RPC: $($rpc.Name)"

            # Get restore points inside collection
            $restorePoints = Get-AzResource `
                -ResourceGroupName $brg.ResourceGroupName `
                -ResourceType "Microsoft.Compute/restorePointCollections/restorePoints" `
                -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$($rpc.Name)/*" }

            foreach ($rp in $restorePoints) {

                Write-Host "Ending access for restore point: $($rp.Name)"

                try {
                    Invoke-AzRestMethod `
                        -Method POST `
                        -Path "$($rp.ResourceId)/endGetAccess?api-version=2022-03-02" `
                        -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Host "No active SAS session."
                }

                Write-Host "Deleting restore point: $($rp.Name)"

                Remove-AzResource `
                    -ResourceId $rp.ResourceId `
                    -Force `
                    -Confirm:$false
            }

            Write-Host "Deleting RPC: $($rpc.Name)"

            Remove-AzResource `
                -ResourceId $rpc.ResourceId `
                -Force `
                -Confirm:$false
        }
    }
}
