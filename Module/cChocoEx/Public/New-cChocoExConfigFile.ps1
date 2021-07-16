function New-cChocoExConfigFile {
    [CmdletBinding()]
    param (
        # Path of Output File
        [Parameter(Mandatory)]
        [string]
        $Path,
        # NoClobber
        [Parameter()]
        [switch]
        $NoClobber
    )
    
    begin {
        #Gather Requested Values
        $cChocoConfigOptions = @(
            "cacheLocation"
            "proxy"
            "proxyUser"
            "proxyPassword"
            "proxyBypassList"
            "proxyBypassOnLocal"
            "commandExecutionTimeoutSeconds"
            "webRequestTimeoutSeconds"
            "containsLegacyPackageInstalls"
            "MaintenanceWindow"
        )
        [array]$HashTableArray = @()
        $ExportString = "@{`n"
        $Absent = New-Object System.Management.Automation.Host.ChoiceDescription '&Absent'
        $Present = New-Object System.Management.Automation.Host.ChoiceDescription '&Present'
        $SelectTrue = New-Object System.Management.Automation.Host.ChoiceDescription '&True'
        $SelectFalse = New-Object System.Management.Automation.Host.ChoiceDescription '&False'
        $EnsureOptions = [System.Management.Automation.Host.ChoiceDescription[]]($Present, $Absent)
        $TrueFalseOptions = [System.Management.Automation.Host.ChoiceDescription[]]($SelectTrue, $SelectFalse)
        $Title = 'cChocoEx - Desired State'
        $cChocoConfigSelections = $cChocoConfigOptions | Out-GridView -Title "cChocoConfig Options" -OutputMode Multiple
    }
    
    process {
        $cChocoConfigSelections | ForEach-Object {
            $ConfigName = $null
            $Ensure = $null
            $Value = $null
            $EffectiveDateTime = $null
            $Start = $null
            $End = $null

            if ($_ -eq 'MaintenanceWindow') {
                Write-Host "ConfigName: $_"
                $ConfigName = $_
                $UTCTimeSelection = $host.ui.PromptForChoice(($Title + " - $ConfigName - UTC"), '', $TrueFalseOptions, 0)
                $EffectiveDateTime = Get-Date -Date (Read-Host -Prompt 'EffectiveDateTime') -Format 'MM/dd/yyyy HH:mm'
                $Start = Get-Date -Date (Read-Host -Prompt 'Start Time') -Format 'HH:mm'
                $End = Get-Date -Date (Read-Host -Prompt 'End Time') -Format 'HH:mm'

                switch ($UTCTimeSelection) {
                    0 { $UTC = $True }
                    1 { $UTC = $False }
                    Default {}
                }
                if ($UTC) {
                    $TimeZones = [System.TimeZoneInfo]::GetSystemTimeZones()
                    $SelectedTimeZone = $TimeZones | Out-GridView -OutputMode Single
                    $gsttz = $TimeZones | Where-Object { $_.Id -match "Greenwich Standard Time" }
                    $EffectiveDateTime = (Get-Date -Date ([System.TimeZoneInfo]::ConvertTime($EffectiveDateTime, $SelectedTimeZone, $gsttz)) -Format 'MM/dd/yyyy HH:mm')
                    $Start = (Get-Date -Date ([System.TimeZoneInfo]::ConvertTime($Start, $SelectedTimeZone, $gsttz)) -Format 'HH:mm')
                    $End = (Get-Date -Date ([System.TimeZoneInfo]::ConvertTime($End, $SelectedTimeZone, $gsttz)) -Format 'HH:mm')
                }

                $HashTableArray += @{
                    ConfigName        = $ConfigName
                    EffectiveDateTime = $EffectiveDateTime
                    Start             = $Start
                    End               = $End
                    UTC               = $UTC
                }
                $ExportString += @"
    '$ConfigName' = @{
        ConfigName        = '$ConfigName'
        EffectiveDateTime = '$EffectiveDateTime'
        Start             = '$Start'
        End               = '$End'
        UTC               = '$UTC'
    }`n
"@
            }
            else {
                Write-Host "ConfigName: $_"
                $ConfigName = $_
                $EnsureSelection = $host.ui.PromptForChoice(($Title + " - $ConfigName - Ensure"), '', $EnsureOptions, 0)
                $Value = Read-Host -Prompt ($Title + " - $ConfigName - Value")

                switch ($EnsureSelection) {
                    0 { $Ensure = 'Present' }
                    1 { $Ensure = 'Absent' }
                    Default {}
                }

                $HashTableArray += @{
                    ConfigName = $ConfigName
                    Ensure     = $Ensure
                    Value      = $Value
                }
                $ExportString += @"
    '$ConfigName' = @{
        ConfigName = '$ConfigName'
        Ensure     = '$Ensure'
        Value      = '$Value'
    }`n
"@
            }
        }
        $ExportString += "`n}"
    }
    
    end {
        try {
            if ($NoClobber -and (Test-Path -Path $Path)) {
                Write-Warning "File Already Exists and NoClobber Specified. Requesting Alternative Path"
                $Path = Read-Host -Prompt "Path"
                $ExportString | Set-Content -Path $Path
            }
            else {
                $ExportString | Set-Content -Path $Path
            }
            $FullPath = (Get-Item -Path $Path).Fullname
            Write-Host "File Wriiten to $FullPath"
        }
        catch {
            $_.Exception.Message
        }    }
}