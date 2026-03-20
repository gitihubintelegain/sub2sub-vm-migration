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
Write-Host "Phase 4 - Move Resources (Production Mode)"
Write-Host "========================================="

# Set source context
Set-AzContext -SubscriptionId $SourceSubscription | Out-Null

# 🚫 Filter problematic resource types
$filteredResources = $ResourcesToMove | Where-Object {
    $_ -notmatch "Microsoft.SqlVirtualMachine" -and
    $_ -notmatch "Microsoft.Logic" -and
    $_ -notmatch "Microsoft.Web/connections"
}

Write-Host "Total संसाधने (input): $($ResourcesToMove.Count)"
Write-Host "Filtered संसाधने (to move): $($filteredResources.Count)"

if ($filteredResources.Count -eq 0) {
    throw "No valid resources to move after filtering."
}

Write-Host "`nResources being moved:"
$filteredResources | ForEach-Object { Write-Host $_ }

Write-Host "`n========================================="
Write-Host "Starting Move-AzResource..."
Write-Host "========================================="

$moveError = $null

try {
    Move-AzResource `
        -DestinationSubscriptionId $DestinationSubscription `
        -DestinationResourceGroupName $ResourceGroup `
        -ResourceId $filteredResources `
        -Force `
        -ErrorAction Stop

    Write-Host "✅ Move command executed (may still be in progress)..."
}
catch {
    $moveError = $_

    Write-Host "`n❌ Move-AzResource FAILED"
    Write-Host "========================================="

    Write-Host "🔴 Exception Message:"
    Write-Host $moveError.Exception.Message

    # 👇 MOST IMPORTANT PART (REAL ERROR)
    if ($moveError.Exception.Response -and $moveError.Exception.Response.Content) {
        Write-Host "`n🔴 RAW AZURE RESPONSE (REAL ROOT CAUSE):"

        try {
            $json = $moveError.Exception.Response.Content | ConvertFrom-Json -ErrorAction Stop
            $json.error | Format-List * -Force

            if ($json.error.details) {
                Write-Host "`n🔴 INNER ERROR DETAILS:"
                $json.error.details | Format-List * -Force
            }
        }
        catch {
            Write-Host $moveError.Exception.Response.Content
        }
    }

    Write-Host "`n🔴 Full Error Dump:"
    $moveError | Format-List * -Force

    Write-Host "========================================="
    Write-Warning "Continuing with validation..."
}

# Switch to destination subscription
Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

Write-Host "`n========================================="
Write-Host "Validating Move (with retries)"
Write-Host "========================================="

# Extract VM ID
$vmId = $filteredResources | Where-Object { $_ -like "*Microsoft.Compute/virtualMachines/*" }

if (-not $vmId) {
    throw "Could not determine VM ID for validation."
}

$vmName = ($vmId -split "/")[-1]

# Retry settings
$maxRetries = 12
$retryDelay = 20
$vmFound = $false

for ($i = 1; $i -le $maxRetries; $i++) {

    Write-Host "🔍 Checking VM in destination... Attempt $i/$maxRetries"

    $vm = Get-AzVM -Name $vmName -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue

    if ($vm) {
        Write-Host "✅ VM FOUND in destination!"
        $vmFound = $true
        break
    }

    Start-Sleep -Seconds $retryDelay
}

# Final decision
if (-not $vmFound) {

    Write-Host "`n❌ FINAL STATUS: MOVE FAILED"

    if ($moveError) {
        Write-Host "`n👉 Root cause (from Azure):"
        Write-Host $moveError.Exception.Message
    }
    else {
        Write-Host "Move command did not throw error, but VM not found."
    }

    throw "❌ Move failed: VM not found after retries."
}

Write-Host "`n========================================="
Write-Host "🎉 MOVE SUCCESSFUL"
Write-Host "========================================="
