<#
.SYNOPSIS
Updates the cChocoEx PowerShell Module to the latest version

.DESCRIPTION
Updates the cChocoEx PowerShell Module to the latest version from the PowerShell Gallery

.LINK

.Example
Update-cChocoEx
#>

function Update-cChocoEx {
    [CmdletBinding()]
    Param ()
    try {
        Write-Warning "Uninstall-Module -Name cChocoEx -AllVersions -Force"
        Uninstall-Module -Name cChocoEx -AllVersions -Force
    }
    catch {}

    try {
        Write-Warning "Install-Module -Name cChocoEx -Force"
        Install-Module -Name cChocoEx -Force
    }
    catch {}

    try {
        Write-Warning "Import-Module -Name cChocoEx -Force"
        Import-Module -Name cChocoEx -Force
    }
    catch {}
}