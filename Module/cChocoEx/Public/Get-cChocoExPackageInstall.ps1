function Get-cChocoExPackageInstall {
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
        [array]$Configurations = $null
        

        if ($Path) {
            $cChocoExPackageFiles = $Path
        }
        else {
            $cChocoExPackageFiles = Get-ChildItem -Path (Join-Path -Path $ChocolateyInstall -ChildPath 'config') -Filter *.psd1 | Where-Object { $_.Name -notmatch "sources.psd1|config.psd1|features.psd1" } 
        }
    }
    
    process {
        if ($cChocoExPackageFiles) {
            $cChocoExPackageFiles | ForEach-Object {
                $ConfigImport = $null
                $ConfigImport = Import-PowerShellDataFile $_.FullName 
                $Configurations += $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
            }        
                    
            $Configurations | ForEach-Object {
                $array += [PSCustomObject]@{
                    Name                      = $_.Name
                    Version                   = $_.Version
                    MinimumVersion            = $_.MinimumVersion
                    Ensure                    = $_.Ensure
                    AutoUpgrade               = $_.AutoUpgrade
                    Params                    = $_.Params
                    ChocoParams               = $_.ChocoParams
                    OverrideMaintenanceWindow = $_.OverrideMaintenanceWindow
                    VPN                       = $_.VPN
                    Ring                      = $_.Ring
                }
            }
        }
        else {
            Write-Warning 'No cChocoEx Package files found'
            Exit
        }
    }
    
    end {
        $array
    }
}