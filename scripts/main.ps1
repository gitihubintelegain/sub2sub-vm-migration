param(
    [Parameter(Mandatory)]
    [string]$SourceSubscription,

    [Parameter(Mandatory)]
    [string]$DestinationSubscription,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$VMName
)

Write-Host "Phase 1 - Validation"
. "$PSScriptRoot/phases/01-validate.ps1" `
    -SourceSubscription $SourceSubscription `
    -DestinationSubscription $DestinationSubscription `
    -ResourceGroup $ResourceGroup `
    -VMName $VMName

Write-Host "Phase 2 - Backup Cleanup"
. "$PSScriptRoot/phases/02-backup-cleanup.ps1" `
    -SourceSubscription $SourceSubscription `
    -ResourceGroup $ResourceGroup `
    -VMName $VMName
