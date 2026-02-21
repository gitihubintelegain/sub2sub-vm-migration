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

Write-Host "========================================="
Write-Host "Phase 5 - Post Move Finalization"
Write-Host "========================================="

# Ensure module is available (GitHub runner safe)
if (-not (Get-Module -ListAvailable -Name Az.RecoveryServices)) {
    Install-Module Az.RecoveryServices -Scope CurrentUser -Force -AllowClobber
}

Import-Module Az.RecoveryServices -Force

Set-AzContext -SubscriptionId $DestinationSubscription -ErrorAction Stop | Out-Null

# -------------------------------------------------------
# 1. Get VM + NIC
# -------------------------------------------------------

$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -ErrorAction Stop

$nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
$nicName = ($nicId -split "/")[-1]
$nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroup

# -------------------------------------------------------
# 2. Re-attach Public IP
# -------------------------------------------------------

$pip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -like "$VMName*" }

if ($pip) {
    Write-Host "Re-attaching Public IP: $($pip.Name)"
    $nic.IpConfigurations[0].PublicIpAddress = $pip
    Set-AzNetworkInterface -NetworkInterface $nic | Out-Null
}
else {
    Write-Host "No Public IP found to reattach."
}

# -------------------------------------------------------
# 3. Start VM
# -------------------------------------------------------

Write-Host "Starting VM..."
Start-AzVM -Name $VMName -ResourceGroupName $ResourceGroup | Out-Null
Write-Host "VM started."

Write-Host "========================================="
Write-Host "Post Move Completed"
Write-Host "========================================="
