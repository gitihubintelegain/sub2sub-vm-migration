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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module Az.Accounts -Force
Import-Module Az.Resources -Force
Import-Module Az.Compute -Force

Write-Host "========================================="
Write-Host "Phase 6 - Backup Setup (REST Based)"
Write-Host "========================================="

Set-AzContext -SubscriptionId $DestinationSubscription | Out-Null

# -------------------------------------------------------
# 1. Create Vault
# -------------------------------------------------------

$uniqueSuffix = Get-Date -Format "yyyyMMddHHmmss"
$vaultName = "$VMName-vault-$uniqueSuffix"

Write-Host "Creating Recovery Services Vault: $vaultName"

$vault = New-AzRecoveryServicesVault `
    -Name $vaultName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location

# -------------------------------------------------------
# 2. Create Backup Policy via REST
# -------------------------------------------------------

$policyName = "$VMName-policy"

$policyUri = "/subscriptions/$DestinationSubscription/resourceGroups/$ResourceGroup/providers/Microsoft.RecoveryServices/vaults/$vaultName/backupPolicies/$policyName?api-version=2023-02-01"

$policyBody = @{
    properties = @{
        backupManagementType = "AzureIaasVM"
        schedulePolicy = @{
            schedulePolicyType = "SimpleSchedulePolicy"
            scheduleRunFrequency = "Daily"
            scheduleRunTimes = @((Get-Date "2026-01-01T11:00:00Z").ToString("o"))
        }
        retentionPolicy = @{
            retentionPolicyType = "SimpleRetentionPolicy"
            dailySchedule = @{
                retentionTimes = @((Get-Date "2026-01-01T11:00:00Z").ToString("o"))
                retentionDuration = @{
                    count = 7
                    durationType = "Days"
                }
            }
        }
    }
} | ConvertTo-Json -Depth 10

Write-Host "Creating backup policy via REST..."

Invoke-AzRestMethod `
    -Method PUT `
    -Path $policyUri `
    -Payload $policyBody

Write-Host "Policy created."

# -------------------------------------------------------
# 3. Enable Backup
# -------------------------------------------------------

$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup

$containerUri = "/subscriptions/$DestinationSubscription/resourceGroups/$ResourceGroup/providers/Microsoft.RecoveryServices/vaults/$vaultName/backupFabrics/Azure/protectionContainers/IaasVMContainer;iaasvmcontainerv2;$ResourceGroup;$VMName/protectedItems/VM;iaasvmcontainerv2;$ResourceGroup;$VMName?api-version=2023-02-01"

$enableBody = @{
    properties = @{
        protectedItemType = "Microsoft.Compute/virtualMachines"
        policyId = "/subscriptions/$DestinationSubscription/resourceGroups/$ResourceGroup/providers/Microsoft.RecoveryServices/vaults/$vaultName/backupPolicies/$policyName"
        sourceResourceId = $vm.Id
    }
} | ConvertTo-Json -Depth 10

Write-Host "Enabling backup via REST..."

Invoke-AzRestMethod `
    -Method PUT `
    -Path $containerUri `
    -Payload $enableBody

Write-Host "Backup enabled."

Write-Host "========================================="
Write-Host "Backup Setup Completed Successfully"
Write-Host "========================================="
