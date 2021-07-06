function Get-cChocoExConfig {
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
            $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } } | Where-Object { $_.Name -ne 'MaintenanceWindow' }
                    
            $Configurations | ForEach-Object {
                $array += [PSCustomObject]@{
                    ConfigName = $_.ConfigName
                    Value      = $_.Value
                    Ensure     = $_.Ensure
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