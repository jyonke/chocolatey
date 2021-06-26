function Start-cChocoInstaller {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]
        $Configuration
    )
    Write-Log -Severity 'Information' -Message "cChocoInstaller:Validating Chocolatey is installed"
    $ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoInstaller")
    Import-Module $ModulePath

    $Object = [PSCustomObject]@{
        Name                  = 'chocolatey'
        DSC                   = $null
        InstallDir            = $Configuration.InstallDir
        ChocoInstallScriptUrl = $Configuration.ChocoInstallScriptUrl
    }
    $DSC = $null
    $DSC = Test-TargetResource @Configuration
    if (-not($DSC)) {
        $null = Set-TargetResource @Configuration
        $DSC = Test-TargetResource @Configuration
    }
    $Object.DSC = $DSC
    #Remove Module for Write-Host limitations
    Remove-Module "cChocoInstaller"

    Write-Log -Severity 'Information' -Message "Starting cChocoInstaller"
    Write-Host '------------cChocoInstaller-------------' -ForegroundColor DarkCyan
    Write-Log -Severity 'Information' -Message "Name: $($Object.Name)"
    Write-Log -Severity 'Information' -Message "DSC: $($Object.DSC)"
    Write-Log -Severity 'Information' -Message "InstallDir: $($Object.InstallDir)"
    Write-Log -Severity 'Information' -Message "ChocoInstallScriptUrl: $($Object.ChocoInstallScriptUrl)"
    Write-Host '------------cChocoInstaller-------------' -ForegroundColor DarkCyan
}