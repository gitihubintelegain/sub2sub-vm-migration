param(
    [Parameter(Mandatory)]
    [string]$SourceSubscription,

    [Parameter(Mandatory)]
    [string]$DestinationSubscription,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string[]]$ResourcesToMove
)

Write-Host "========================================="
Write-Host "Phase 4 - Move Resources"
Write-Host "========================================="

Set-AzContext -SubscriptionId $SourceSubscription | Out-Null

# 🚫 Filter unsupported/problematic resources
$filteredResources = $ResourcesToMove | Where-Object {
    $_ -notmatch "Microsoft.SqlVirtualMachine" -and
    $_ -notmatch "Microsoft.Logic" -and
    $_ -notmatch "Microsoft.Web/connections"
}

Write-Host "Filtered Resources Count: $($filteredResources.Count)"

try {
    Write-Host "Initiating Move-AzResource..."

    Move-AzResource `
        -DestinationSubscriptionId $DestinationSubscription `
        -DestinationResourceGroupName $ResourceGroup `
        -ResourceId $filteredResources `
        -Force `
        -ErrorAction Stop

    Write-Host "Move command executed."

}
catch {
    Write-Warning "Move command threw an error. Will verify actual state..."
}

# ✅ Switch to destination
Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# 🎯 Extract VM name
$vmId = $filteredResources | Where-Object { $_ -like "*Microsoft.Compute/virtualMachines/*" }

if (-not $vmId) {
    throw "Could not determine VM ID for validation."
}

$vmName = ($vmId -split "/")[-1]

# 🔁 Retry logic (IMPORTANT)
$maxRetries = 10
$retryDelay = 20
$vmFound = $false

for ($i = 1; $i -le $maxRetries; $i++) {

    Write-Host "Checking VM in destination... Attempt $i/$maxRetries"

    $vm = Get-AzVM -Name $vmName -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue

    if ($vm) {
        Write-Host "✅ VM found in destination."
        $vmFound = $true
        break
    }

    Start-Sleep -Seconds $retryDelay
}

if (-not $vmFound) {
    throw "❌ Move failed: VM not found after multiple retries."
}

Write-Host "========================================="
Write-Host "Move Phase Completed Successfully"
Write-Host "========================================="
