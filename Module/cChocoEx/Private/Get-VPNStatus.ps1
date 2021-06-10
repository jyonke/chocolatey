function Get-VPNStatus {
    $VPNStatus = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'pangp|cisco|juniper|vpn' -and $_.Status -eq 'Up' }
    if ($VPNStatus) {
        Write-Log -Severity 'Information' -Message "VPN Status: Active"
        Return $true
    }
    else {
        Write-Log -Severity 'Information' -Message "VPN Status: InActive"
        Return $false
    }
}