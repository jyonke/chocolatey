function Get-cChocoExLog {
    [CmdletBinding()]
    param (
        #Limit Number of items to return
        [Parameter()]
        [int]
        $Last,
        # Limit Return Values to a specif day
        [Parameter()]
        [datetime]
        $Date
    )
    
    try {
        $ChocolateyInstall = $env:ChocolateyInstall
        $cChocoExLogFiles = Get-ChildItem -Path (Join-Path -Path $ChocolateyInstall -ChildPath 'logs') -Filter 'cChoco*.log'

        if ($Date) {
            $DateFilter = (Get-Date $Date).Date
            $cChocoExLogs = $cChocoExLogFiles | Import-Csv | Where-Object { ( Get-Date $_.'Time').Date -eq $DateFilter }
        }
        else {
            $cChocoExLogs = $cChocoExLogFiles | Import-Csv
        }
        if ($Last) {
            $cChocoExLogs = $cChocoExLogs | Select-Object -Last $Last
        }    
        Return $cChocoExLogs
    }
    catch {
        $_.Exception.Message
        Exit
    }
}