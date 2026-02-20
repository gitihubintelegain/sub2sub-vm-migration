param(
    [Parameter(Mandatory)]
    [string]$SourceSubscription,

    [Parameter(Mandatory)]
    [string]$DestinationSubscription,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [array]$ResourcesToMove
)

Write-Host "========================================="
Write-Host "Phase 4 - Moving Resources"
Write-Host "========================================="

Set-AzContext -SubscriptionId $SourceSubscription

# Ensure destination RG exists
Set-AzContext -SubscriptionId $DestinationSubscription

$destRG = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue

if (-not $destRG) {
    Write-Host "Creating destination resource group..."
    New-AzResourceGroup -Name $ResourceGroup -Location "centralindia"
}

# Switch back to source for move operation
Set-AzContext -SubscriptionId $SourceSubscription

Write-Host "Initiating Move-AzResource..."

Write-Host "Final Resource IDs being moved:"
$ResourcesToMove | ForEach-Object { Write-Host $_ }

Move-AzResource `
    -ResourceId $ResourcesToMove `
    -DestinationSubscriptionId $DestinationSubscription `
    -DestinationResourceGroupName $ResourceGroup `
    -Force

Write-Host "Move operation initiated."
