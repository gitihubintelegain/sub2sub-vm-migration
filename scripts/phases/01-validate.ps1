param(
    [Parameter(Mandatory)]
    [string]$SourceSubscription,

    [Parameter(Mandatory)]
    [string]$DestinationSubscription,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$VMName,

    [Parameter(Mandatory)]
    [string]$SourceVaultName
)

Write-Host "========================================="
Write-Host "Phase 1 - Validation"
Write-Host "========================================="

# -------------------------------------------------------
# 1. Validate Source Subscription & VM
# -------------------------------------------------------

Write-Host "Switching to source subscription..."
Set-AzContext -SubscriptionId $SourceSubscription -ErrorAction Stop

Write-Host "Checking if VM exists..."
$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -ErrorAction Stop

if ($vm.ProvisioningState -ne "Succeeded") {
    throw "VM provisioning state is not Succeeded. Current state: $($vm.ProvisioningState)"
}

Write-Host "VM found: $($vm.Name)"
Write-Host "VM Location: $($vm.Location)"

# -------------------------------------------------------
# 2. Validate NIC & Public IP
# -------------------------------------------------------

$nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
$nicName = ($nicId -split "/")[-1]
$nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroup -ErrorAction Stop

Write-Host "Primary NIC: $($nic.Name)"

if ($nic.IpConfigurations[0].PublicIpAddress) {
    $publicIp = Get-AzPublicIpAddress -ResourceId $nic.IpConfigurations[0].PublicIpAddress.Id
    Write-Host "Public IP detected: $($publicIp.Name)"
    Write-Host "Public IP SKU: $($publicIp.Sku.Name)"
} else {
    Write-Host "No Public IP attached."
}

# -------------------------------------------------------
# 3. Validate Disks
# -------------------------------------------------------

Write-Host "OS Disk: $($vm.StorageProfile.OsDisk.Name)"

if ($vm.StorageProfile.DataDisks.Count -gt 0) {
    foreach ($disk in $vm.StorageProfile.DataDisks) {
        Write-Host "Data Disk: $($disk.Name)"
    }
} else {
    Write-Host "No Data Disks attached."
}

# -------------------------------------------------------
# 4. Check Resource Locks
# -------------------------------------------------------

Write-Host "Checking for resource locks..."
$locks = Get-AzResourceLock -ResourceGroupName $ResourceGroup

if ($locks) {
    foreach ($lock in $locks) {
        Write-Host "Lock detected: $($lock.Name) - $($lock.LockLevel)"
    }
    throw "Resource locks detected. Remove locks before migration."
}

# -------------------------------------------------------
# 5. Validate Source Vault Exists
# -------------------------------------------------------

Write-Host "Validating Recovery Services Vault exists..."
$vault = Get-AzRecoveryServicesVault -Name $SourceVaultName -ErrorAction Stop
Write-Host "Vault found: $($vault.Name)"

# -------------------------------------------------------
# 6. Validate Destination Subscription
# -------------------------------------------------------

Write-Host "Switching to destination subscription..."
Set-AzContext -SubscriptionId $DestinationSubscription -ErrorAction Stop

Write-Host "Destination subscription validated."

# Check if destination RG exists (create later if needed)
$destRG = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue

if (-not $destRG) {
    Write-Host "Destination Resource Group does not exist. It will be created during migration."
} else {
    Write-Host "Destination Resource Group exists."
}

Write-Host "========================================="
Write-Host "Validation Completed Successfully"
Write-Host "========================================="
