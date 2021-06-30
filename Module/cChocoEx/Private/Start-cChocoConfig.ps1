function Start-cChocoConfig {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]
        $ConfigImport
    )
    $TSEnv = Test-TSEnv

    Write-Log -Severity 'Information' -Message "cChocoConfig:Validating Chocolatey Configurations are Setup"
    $ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoConfig")
    Import-Module $ModulePath
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } } | Where-Object { $_.Name -ne 'MaintenanceWindow' }
    $MaintenanceWindowConfig = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } } | Where-Object { $_.Name -eq 'MaintenanceWindow' }

    $Status = @()
    $Configurations | ForEach-Object {
        $DSC = $null
        $Configuration = $_
        $Object = [PSCustomObject]@{
            ConfigName = $Configuration.ConfigName
            DSC        = $null
            Ensure     = $Configuration.Ensure
            Value      = $Configuration.Value
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
    Remove-Module "cChocoConfig"

    Write-Log -Severity 'Information' -Message 'Starting cChocoConfig'
    $Status | ForEach-Object {
        Write-Host '--------------cChocoConfig--------------' -ForegroundColor DarkCyan
        Write-Log -Severity 'Information' -Message "ConfigName: $($_.ConfigName)"
        Write-Log -Severity 'Information' -Message "DSC: $($_.DSC)"
        Write-Log -Severity 'Information' -Message "Ensure: $($_.Ensure)"
        Write-Log -Severity 'Information' -Message "Value: $($_.Value)"               
    }
    Write-Host '--------------cChocoConfig--------------' -ForegroundColor DarkCyan

    #cChocoConfig-MaintenanceWindowConfig
    Write-Log -Severity 'Information'  -Message "cChocoConfig-MaintenanceWindowConfig:Validating Chocolatey Maintenance Window is Setup"

    $Global:MaintenanceWindowEnabled = $True
    $Global:MaintenanceWindowActive = $True

    if ($MaintenanceWindowConfig -and (-not($TSEnv))) {
        $MaintenanceWindowTest = Get-MaintenanceWindow -StartTime $MaintenanceWindowConfig.Start -EndTime $MaintenanceWindowConfig.End -EffectiveDateTime $MaintenanceWindowConfig.EffectiveDateTime -UTC $MaintenanceWindowConfig.UTC -Verbose
        $Global:MaintenanceWindowEnabled = $MaintenanceWindowTest.MaintenanceWindowEnabled
        $Global:MaintenanceWindowActive = $MaintenanceWindowTest.MaintenanceWindowActive
        Write-Host '--cChocoConfig-MaintenanceWindowConfig--' -ForegroundColor DarkCyan
        Write-Log -Severity 'Information' -Message "cChocoConfig-MaintenanceWindowConfig"
        Write-Log -Severity 'Information' -Message "Name: $($MaintenanceWindowConfig.Name)"
        Write-Log -Severity 'Information' -Message "EffectiveDateTime: $($MaintenanceWindowConfig.EffectiveDateTime)"
        Write-Log -Severity 'Information' -Message "Start: $($MaintenanceWindowConfig.Start)"
        Write-Log -Severity 'Information' -Message "End: $($MaintenanceWindowConfig.End)"
        Write-Log -Severity 'Information' -Message "UTC: $($MaintenanceWindowConfig.UTC)"
        Write-Log -Severity 'Information' -Message "MaintenanceWindowEnabled: $($MaintenanceWindowEnabled)"
        Write-Log -Severity 'Information' -Message "MaintenanceWindowActive: $($MaintenanceWindowActive)"
        Write-Host '--cChocoConfig-MaintenanceWindowConfig--' -ForegroundColor DarkCyan
    }
    else {
        Write-Log -Severity 'Warning' -Message "No Defined Maintenance Window"
    }
    if ($TSEnv) {
        Write-Log -Severity 'Information' -Message "TaskSeqence Environment Detected, overriding maintennce window settings"
        Write-Log -Severity 'Information' -Message "MaintenanceWindowEnabled: $($MaintenanceWindowEnabled)"
        Write-Log -Severity 'Information' -Message "MaintenanceWindowActive: $($MaintenanceWindowActive)"
    }
}