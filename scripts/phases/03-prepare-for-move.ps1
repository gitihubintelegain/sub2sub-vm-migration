param(
    [Parameter(Mandatory)]
    [string]$SourceSubscription,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$VMName
)

Write-Host "========================================="
Write-Host "Phase 3 - Prepare VM For Move"
Write-Host "========================================="

Set-AzContext -SubscriptionId $SourceSubscription -ErrorAction Stop | Out-Null

$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -ErrorAction Stop

# -------------------------------------------------------
# Deallocate VM
# -------------------------------------------------------

$status = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -Status

$powerState = ($status.Statuses | Where-Object {
    $_.Code -like "PowerState/*"
}).DisplayStatus

if ($powerState -ne "VM deallocated") {
    Write-Host "Deallocating VM..."
    Stop-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -Force | Out-Null
    Write-Host "VM deallocated."
}
else {
    Write-Host "VM already deallocated."
}

# -------------------------------------------------------
# NIC
# -------------------------------------------------------
$nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
$nicName = ($nicId -split "/")[-1]
$nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroup

# -------------------------------------------------------
# Detach Public IP
# -------------------------------------------------------

# Detach Public IP (but capture its ID first)
$publicIpId = $null

if ($nic.IpConfigurations[0].PublicIpAddress) {

    $publicIpId = $nic.IpConfigurations[0].PublicIpAddress.Id

    Write-Host "Public IP detected: $publicIpId"
    Write-Host "Detaching Public IP..."

    $nic.IpConfigurations[0].PublicIpAddress = $null
    Set-AzNetworkInterface -NetworkInterface $nic | Out-Null

    Write-Host "Public IP detached."
}

# -------------------------------------------------------
# Collect Dependencies
# -------------------------------------------------------

$resourcesToMove = @()

# VM
$resourcesToMove += $vm.Id

# NIC
$resourcesToMove += $nic.Id

# Public IP (attached one if existed)
if ($publicIpId) {
    $resourcesToMove += $publicIpId
}

# OS Disk
$resourcesToMove += $vm.StorageProfile.OsDisk.ManagedDisk.Id

# Data Disks
foreach ($disk in $vm.StorageProfile.DataDisks) {
    if ($disk.ManagedDisk) {
        $resourcesToMove += $disk.ManagedDisk.Id
    }
}

# VNet
$vnetId = ($nic.IpConfigurations[0].Subnet.Id -split "/subnets/")[0]
$resourcesToMove += $vnetId

# NSG
if ($nic.NetworkSecurityGroup) {
    $resourcesToMove += $nic.NetworkSecurityGroup.Id
}

# -------------------------------------------------------
# Include Standalone Public IPs (if any exist in RG)
# -------------------------------------------------------

$allPips = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue

foreach ($pip in $allPips) {
    if ($pip.Id -notin $resourcesToMove) {
        Write-Host "Including standalone Public IP: $($pip.Name)"
        $resourcesToMove += $pip.Id
    }
}

# Remove duplicates just in case
$resourcesToMove = $resourcesToMove | Select-Object -Unique

Write-Host "Resources prepared for move:"
$resourcesToMove | ForEach-Object { Write-Host $_ }

return $resourcesToMove
