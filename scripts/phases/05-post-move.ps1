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

Set-AzContext -SubscriptionId $DestinationSubscription -ErrorAction Stop

# -------------------------------------------------------
# 1. Get VM + NIC
# -------------------------------------------------------

$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -ErrorAction Stop

$nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
$nicName = ($nicId -split "/")[-1]
$nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroup

# -------------------------------------------------------
# 2. Re-attach Public IP (if exists)
# -------------------------------------------------------

$pip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -like "$VMName*" }

if ($pip) {
    Write-Host "Re-attaching Public IP: $($pip.Name)"

    $nic.IpConfigurations[0].PublicIpAddress = $pip
    Set-AzNetworkInterface -NetworkInterface $nic
}
else {
    Write-Host "No Public IP found to reattach."
}

# -------------------------------------------------------
# 3. Start VM
# -------------------------------------------------------

Write-Host "Starting VM..."
Start-AzVM -Name $VMName -ResourceGroupName $ResourceGroup
Write-Host "VM started."

# -------------------------------------------------------
# 4. Create Recovery Services Vault
# -------------------------------------------------------

$vaultName = "$VMName-vault"

$vault = Get-AzRecoveryServicesVault -Name $vaultName -ErrorAction SilentlyContinue

if (-not $vault) {
    Write-Host "Creating Recovery Services Vault..."
    $vault = New-AzRecoveryServicesVault `
        -Name $vaultName `
        -ResourceGroupName $ResourceGroup `
        -Location $Location
}

Set-AzRecoveryServicesVaultContext -Vault $vault

# -------------------------------------------------------
# 5. Create Backup Policy (7 days retention, 5 days instant restore, daily 11 AM)
# -------------------------------------------------------

$policyName = "$VMName-policy"

$policy = Get-AzRecoveryServicesBackupProtectionPolicy `
    -Name $policyName `
    -ErrorAction SilentlyContinue

if (-not $policy) {

    Write-Host "Creating backup policy..."

    $schedulePolicy = New-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType AzureVM
    $schedulePolicy.ScheduleRunFrequency = "Daily"
    $schedulePolicy.ScheduleRunTimes.Clear()
    $schedulePolicy.ScheduleRunTimes.Add((Get-Date "11:00"))

    $retentionPolicy = New-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType AzureVM
    $retentionPolicy.DailySchedule.DurationCountInDays = 7
    $retentionPolicy.DailySchedule.RetentionTimes.Clear()
    $retentionPolicy.DailySchedule.RetentionTimes.Add((Get-Date "11:00"))

    $policy = New-AzRecoveryServicesBackupProtectionPolicy `
        -Name $policyName `
        -WorkloadType AzureVM `
        -RetentionPolicy $retentionPolicy `
        -SchedulePolicy $schedulePolicy
}

# -------------------------------------------------------
# 6. Enable Backup
# -------------------------------------------------------

Write-Host "Enabling backup for VM..."

Enable-AzRecoveryServicesBackupProtection `
    -Policy $policy `
    -Name $VMName `
    -ResourceGroupName $ResourceGroup

# -------------------------------------------------------
# 7. Trigger Initial Backup
# -------------------------------------------------------

$container = Get-AzRecoveryServicesBackupContainer `
    -ContainerType AzureVM `
    -FriendlyName $VMName

$item = Get-AzRecoveryServicesBackupItem `
    -Container $container `
    -WorkloadType AzureVM

Write-Host "Triggering initial backup..."

Backup-AzRecoveryServicesBackupItem -Item $item

Write-Host "Initial backup triggered successfully."

Write-Host "========================================="
Write-Host "Post Move Completed"
Write-Host "========================================="
