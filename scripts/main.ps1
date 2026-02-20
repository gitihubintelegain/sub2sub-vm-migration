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
    [string]$SourceVaultName,

    [Parameter(Mandatory)]
    [ValidateSet("all","validate","backup","prepare","move","post")]
    [string]$Phase
)

Write-Host "========================================="
Write-Host "Sub2Sub VM Migration - Phase: $Phase"
Write-Host "========================================="

$resourcesToMove = $null

# -------------------------
# Phase 1 - Validation
# -------------------------
if ($Phase -in @("validate","all")) {

    Write-Host "Phase 1 - Validation"

    . "$PSScriptRoot/phases/01-validate.ps1" `
        -SourceSubscription $SourceSubscription `
        -DestinationSubscription $DestinationSubscription `
        -ResourceGroup $ResourceGroup `
        -VMName $VMName `
        -SourceVaultName $SourceVaultName
}

# -------------------------
# Phase 2 - Backup Cleanup
# -------------------------
if ($Phase -in @("backup","all")) {

    Write-Host "Phase 2 - Backup Cleanup"

    . "$PSScriptRoot/phases/02-backup-cleanup.ps1" `
        -SourceSubscription $SourceSubscription `
        -ResourceGroup $ResourceGroup `
        -VMName $VMName `
        -SourceVaultName $SourceVaultName
}

# -------------------------
# Phase 3 - Prepare
# -------------------------
if ($Phase -in @("prepare","all")) {

    Write-Host "Phase 3 - Prepare For Move"

    $resourcesToMove = . "$PSScriptRoot/phases/03-prepare-for-move.ps1" `
        -SourceSubscription $SourceSubscription `
        -ResourceGroup $ResourceGroup `
        -VMName $VMName
}

# -------------------------
# Phase 4 - Move
# -------------------------
if ($Phase -in @("move","all")) {

    if (-not $resourcesToMove) {
        throw "ResourcesToMove is empty. Run prepare phase first or use Phase=all."
    }

    Write-Host "Phase 4 - Move Resources"

    . "$PSScriptRoot/phases/04-move-resources.ps1" `
        -SourceSubscription $SourceSubscription `
        -DestinationSubscription $DestinationSubscription `
        -ResourceGroup $ResourceGroup `
        -ResourcesToMove $resourcesToMove
}

# -------------------------
# Phase 5 - Post Move
# -------------------------
if ($Phase -in @("post","all")) {

    Write-Host "Phase 5 - Post Move"

    . "$PSScriptRoot/phases/05-post-move.ps1" `
        -DestinationSubscription $DestinationSubscription `
        -ResourceGroup $ResourceGroup `
        -VMName $VMName `
        -Location "centralindia"
}

Write-Host "========================================="
Write-Host "Execution Completed"
Write-Host "========================================="
