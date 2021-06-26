function Start-cChocoFeature {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]
        $ConfigImport
    )
    Write-Log -Severity 'Information' -Message "cChocoConfig:Validating Chocolatey Configurations are Setup"
    $ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoFeature")
    Import-Module $ModulePath
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
    $Status = @()
    $Configurations | ForEach-Object {
        $DSC = $null
        $Configuration = $_
        $Object = [PSCustomObject]@{
            FeatureName = $Configuration.FeatureName
            DSC         = $null
            Ensure      = $Configuration.Ensure
        }
        $DSC = Test-TargetResource @Configuration
        if (-not($DSC)) {
            $null = Set-TargetResource @Configuration
            $DSC = Test-TargetResource @Configuration
        }
    
        $Object.DSC = $DSC
        $Status += $Object
    }
    #Remove Module for Write-Host limitations
    Remove-Module "cChocoFeature"

    Write-Log -Severity 'Information' -Message 'Starting cChocoFeature'
    $Status | ForEach-Object {
        Write-Host '-------------cChocoFeature--------------' -ForegroundColor DarkCyan
        Write-Log -Severity 'Information' -Message "FeatureName: $($_.FeatureName)"
        Write-Log -Severity 'Information' -Message "DSC: $($_.DSC)"
        Write-Log -Severity 'Information' -Message "Ensure: $($_.Ensure)"
    }
    Write-Host '-------------cChocoFeature--------------' -ForegroundColor DarkCyan
}