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

try {

    Write-Host "Initiating Move-AzResource..."

    Move-AzResource `
        -DestinationSubscriptionId $DestinationSubscription `
        -DestinationResourceGroupName $ResourceGroup `
        -ResourceId $ResourcesToMove `
        -Force

    Write-Host "Move completed successfully."

}
catch {

    Write-Host "Move reported failure. Validating actual resource state..."

    # Switch to destination subscription
    Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

    # Extract VM ID from move list
    $vmId = $ResourcesToMove | Where-Object { $_ -like "*Microsoft.Compute/virtualMachines/*" }

    if (-not $vmId) {
        throw "Could not determine VM ID for validation."
    }

    $vmName = ($vmId -split "/")[-1]

    $vm = Get-AzVM -Name $vmName -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue

    if ($vm) {
        Write-Host "VM found in destination subscription."
        Write-Host "Treating move as successful despite batch failure."
    }
    else {
        throw "Move failed and VM not found in destination. Aborting."
    }
}

Write-Host "========================================="
Write-Host "Move Phase Completed"
Write-Host "========================================="
