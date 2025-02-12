param(
    [parameter(Mandatory = $true)][string]$OutputFileName
)

#Connect MgGraph
try {
    Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All, User.Read.All' | Out-Null
} 
catch {
    Write-Warning ("Error connecting Microsoft Graph, check Permissions/Accounts. Exiting...")
    return
}

#Loop through the devices and the logged on users per device 
$total = Foreach ($device in (Get-MgBetaDeviceManagementManagedDevice | Where-Object OperatingSystem -eq Windows)) {
    Write-Host ("Processing {0}..." -f $device.DeviceName) -ForegroundColor Green
    foreach ($user in $device.UsersLoggedOn.UserId | Select-Object -Unique  ) {
        [PSCustomObject]@{
            Device            = $device.DeviceName
            Model             = $device.Model
            "Users logged in" = (Get-MgUser -UserId $user).DisplayName
            LastLogon         = ($device.UsersLoggedOn | Where-Object Userid -eq $user | Sort-Object LastLogonDateTime | Select-Object -Last 1).LastLogOnDateTime
            PrimaryUser       = if ((Get-MgBetaDeviceManagementManagedDeviceUser -ManagedDeviceId $device.Id).DisplayName) {
                $((Get-MgBetaDeviceManagementManagedDeviceUser -ManagedDeviceId $device.Id).DisplayName)
            }
            else {
                "None"
            }
        }
    }
}
Disconnect-MgGraph | Out-Null

try {
    $total | Sort-Object Device, 'Users logged in' | Export-Csv -Path $OutputFileName -NoTypeInformation -Encoding UTF8 -Delimiter ';' -ErrorAction Stop
    Write-Host ("Exported results to {0}" -f $OutputFileName) -ForegroundColor Green
}
catch {
    Write-Warning ("Error saving results to {0}, check path/permissions..." -f $OutputFileName)
}