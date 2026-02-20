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

Set-AzContext -SubscriptionId $SourceSubscription -ErrorAction Stop

$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -ErrorAction Stop

# Deallocate
$status = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -Status
if ($status.PowerState -ne "VM deallocated") {
    Write-Host "Deallocating VM..."
    Stop-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -Force
    Write-Host "VM deallocated."
}

# NIC
$nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
$nicName = ($nicId -split "/")[-1]
$nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroup

# Detach Public IP
if ($nic.IpConfigurations[0].PublicIpAddress) {
    Write-Host "Detaching Public IP..."
    $nic.IpConfigurations[0].PublicIpAddress = $null
    Set-AzNetworkInterface -NetworkInterface $nic
    Write-Host "Public IP detached."
}

# Collect dependencies
$resourcesToMove = @()

$resourcesToMove += $vm.Id
$resourcesToMove += $nic.Id
$resourcesToMove += $vm.StorageProfile.OsDisk.ManagedDisk.Id

foreach ($disk in $vm.StorageProfile.DataDisks) {
    $resourcesToMove += $disk.ManagedDisk.Id
}

# VNet
$vnetId = ($nic.IpConfigurations[0].Subnet.Id -split "/subnets/")[0]
$resourcesToMove += $vnetId

# NSG
if ($nic.NetworkSecurityGroup) {
    $resourcesToMove += $nic.NetworkSecurityGroup.Id
}

Write-Host "Resources prepared for move:"
$resourcesToMove | ForEach-Object { Write-Host $_ }

# RETURN ARRAY
return $resourcesToMove
