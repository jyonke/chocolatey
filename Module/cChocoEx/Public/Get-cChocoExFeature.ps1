function Get-cChocoExFeature {
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
            $cChocoExFeatureFile = $Path
        }
        else {
            $cChocoExFeatureFile = (Get-ChildItem -Path (Join-Path -Path $ChocolateyInstall -ChildPath 'config') -Filter 'features.psd1').FullName
        }
    }
    
    process {
        if ($cChocoExFeatureFile) {
            $ConfigImport = Import-PowerShellDataFile -Path $cChocoExFeatureFile
            $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
                    
            $Configurations | ForEach-Object {
                $array += [PSCustomObject]@{
                    FeatureName = $_.FeatureName
                    Ensure      = $_.Ensure
                }
            }
        }
        else {
            Write-Warning 'No cChocoEx Features file found'
            Exit
        }
    }
    
    end {
        $array
    }
}