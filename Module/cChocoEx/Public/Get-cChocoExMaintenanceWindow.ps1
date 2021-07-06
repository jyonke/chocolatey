function Get-cChocoExMaintenanceWindow {
    [CmdletBinding()]
    param (
        # Path
        [Parameter()]
        [string]
        $Path
    )
    
    begin {
        [array]$array = @()
        $ChocolateyInstall = $env:ChocolateyInstall
        if ($Path) {
            $cChocoExConfigFile = $Path
        }
        else {
            $cChocoExConfigFile = (Get-ChildItem -Path (Join-Path -Path $ChocolateyInstall -ChildPath 'config') -Filter 'config.psd1').FullName
        }
    }
    
    process {
        if ($cChocoExConfigFile) {
            $ConfigImport = Import-PowerShellDataFile -Path $cChocoExConfigFile
            $MaintenanceWindowConfig = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } } | Where-Object { $_.Name -eq 'MaintenanceWindow' }
                    
            $MaintenanceWindowConfig | ForEach-Object {
                $array += [PSCustomObject]@{
                    ConfigName        = $_.Name
                    UTC               = $_.UTC
                    EffectiveDateTime = $_.EffectiveDateTime
                    Start             = $_.Start
                    End               = $_.End
                }
            }
        }
        else {
            Write-Warning 'No cChocoEx Configuration file found'
            Exit
        }
    }
    
    end {
        $array
    }
}