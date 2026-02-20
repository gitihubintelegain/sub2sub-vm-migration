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

Write-Host "Phase 1 - Validation"

. "$PSScriptRoot/phases/01-validate.ps1" `
    -SourceSubscription $SourceSubscription `
    -DestinationSubscription $DestinationSubscription `
    -ResourceGroup $ResourceGroup `
    -VMName $VMName `
    -SourceVaultName $SourceVaultName

Write-Host "Phase 2 - Backup Cleanup"

. "$PSScriptRoot/phases/02-backup-cleanup.ps1" `
    -SourceSubscription $SourceSubscription `
    -ResourceGroup $ResourceGroup `
    -VMName $VMName `
    -SourceVaultName $SourceVaultName

Write-Host "Phase 3 - Prepare For Move"

$resourcesToMove = . "$PSScriptRoot/phases/03-prepare-for-move.ps1" `
    -SourceSubscription $SourceSubscription `
    -ResourceGroup $ResourceGroup `
    -VMName $VMName

Write-Host "Phase 4 - Move Resources"

. "$PSScriptRoot/phases/04-move-resources.ps1" `
    -SourceSubscription $SourceSubscription `
    -DestinationSubscription $DestinationSubscription `
    -ResourceGroup $ResourceGroup `
    -ResourcesToMove $resourcesToMove
