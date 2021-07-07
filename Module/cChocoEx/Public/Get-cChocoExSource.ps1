function Get-cChocoExSource {
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
            $cChocoExSourceFile = $Path
        }
        else {
            $cChocoExSourceFile = (Get-ChildItem -Path (Join-Path -Path $ChocolateyInstall -ChildPath 'config') -Filter 'sources.psd1').FullName
        }
    }
    
    process {
        if ($cChocoExSourceFile) {
            $ConfigImport = Import-PowerShellDataFile -Path $cChocoExSourceFile
            $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
                    
            $Configurations | ForEach-Object {
                $array += [PSCustomObject]@{
                    Name     = $_.Name
                    Ensure   = $_.Ensure
                    Priority = $_.Priority
                    Source   = $_.Source
                    User     = $_.User
                    Password = $_.Password
                    KeyFile  = $_.KeyFile
                    VPN      = $_.VPN
                }
            }
        }
        else {
            Write-Warning 'No cChocoEx Sources file found'
            Exit
        }
    }
    
    end {
        $array
    }
}