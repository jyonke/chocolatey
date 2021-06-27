function Start-cChocoPackageInstall {
    [CmdletBinding()]
    param (
        [Parameter()]
        [array]
        $Configurations
    )
    
    Write-Log -Severity "Information" -Message "cChocoPackageInstall:Validating Chocolatey Packages are Setup"
    $Status = @()

    #Evaluate Ring Status
    $Ring = Get-Ring
    Write-Log -Severity 'Information' -Message "Local Machine Deployment Ring: $Ring"
    
    #Evaluate VPN Status
    $VPNStatus = Get-VPNStatus

    #Validate No Duplicate Packages Defined with no Ring Details
    $DuplicateSearch = (Compare-Object -ReferenceObject $Configurations.Name -DifferenceObject ($Configurations.Name | Select-Object -Unique) | Where-Object { $_.SideIndicator -eq '<=' }).InputObject
    $Duplicates = $Configurations | Where-Object { $DuplicateSearch -eq $_.Name } | Where-Object { $_.Ring -eq $null }
    if ($Duplicates) {
        Write-Log -Severity 'Warning' -Message "Duplicate cChocoPackageInstall"
        Write-Log -Severity 'Warning' -Message "Duplicate Package Found removing from active processesing"
        $Configurations | Where-Object { $Duplicates.Name -eq $_.Name } | ForEach-Object {
            Write-Log -Severity 'Warning' -Message "Name: $($_.Name)"
            Write-Log -Severity 'Warning' -Message "Version $($_.Version)"
            Write-Log -Severity 'Warning' -Message "DSC: $($_.DSC)"
            Write-Log -Severity 'Warning' -Message "Source: $($_.Source)"
            Write-Log -Severity 'Warning' -Message "Ensure: $($_.Ensure)"
            Write-Log -Severity 'Warning' -Message "AutoUpgrade: $($_.AutoUpgrade)"
            Write-Log -Severity 'Warning' -Message "VPN: $($_.VPN)"
            Write-Log -Severity 'Warning' -Message "Params: $($_.Params)"
            Write-Log -Severity 'Warning' -Message "ChocoParams: $($_.ChocoParams)"
            Write-Log -Severity 'Warning' -Message "Ring: $($_.Ring)"
            Write-Log -Severity 'Warning' -Message "OverrideMaintenanceWindow: $($_.OverrideMaintenanceWindow)"
            Write-Log -Severity 'Warning' -Message "Duplicate Package Defined"
        }
        #Filter Out Duplicates and Clear all package configuration files for next time processing
        Write-Log -Severity 'Warning' -Message "Filter Out Duplicates and Clear all package configuration files for next time processing"
        $Configurations = $Configurations | Where-Object { $Duplicates.Name -notcontains $_.Name }
        Get-ChildItem -Path $PackageConfigDestination -Filter *.psd1 | Where-Object { $_.Name -notmatch "sources.psd1|config.psd1|features.psd1" } | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    #Filter and Validate Packages with defined deploymentrings
    Write-Log -Severity 'Information' -Message "Getting Valid Deployment Ring Packages"
    $PriorityConfigurations = Get-PackagePriority -Configurations $Configurations
    
    $ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoPackageInstall")
    Import-Module $ModulePath
    
    $PriorityConfigurations | ForEach-Object {
        $DSC = $null
        $Configuration = $_
        $Object = [PSCustomObject]@{
            Name                      = $Configuration.Name
            Version                   = $Configuration.Version
            DSC                       = $null
            Ensure                    = $Configuration.Ensure
            Source                    = $Configuration.Source
            AutoUpgrade               = $Configuration.AutoUpgrade
            VPN                       = $Configuration.VPN
            Params                    = $Configuration.Params
            ChocoParams               = $Configuration.ChocoParams
            Ring                      = $Configuration.Ring
            OverrideMaintenanceWindow = $Configuration.OverrideMaintenanceWindow
            Warning                   = $null
        }
        #Evaluate VPN Restrictions
        if ($null -ne $Configuration.VPN) {
            if ($Configuration.VPN -eq $false -and $VPNStatus) {
                $Configuration.Remove("VPN")
                $Configuration.Remove("Ring")
                $Configuration.Remove("OverrideMaintenanceWindow")
                $Object.Warning = "Configuration restricted when VPN is connected"
                $DSC = Test-TargetResource @Configuration
                $Object.DSC = $DSC
                $Status += $Object        
                return
            }
            if ($Configuration.VPN -eq $true -and -not($VPNStatus)) {
                $Configuration.Remove("VPN")
                $Configuration.Remove("Ring")
                $Configuration.Remove("OverrideMaintenanceWindow")
                $Object.Warning = "Configuration restricted when VPN is not established"
                $DSC = Test-TargetResource @Configuration
                $Object.DSC = $DSC
                $Status += $Object
                return
            }
            $Configuration.Remove("VPN")
        }
        #Evaluate Ring Restrictions
        if ($null -ne $Configuration.Ring) {
            $ConfigurationRingValue = Get-RingValue -Name $Configuration.Ring
            if ($Ring) {
                $SystemRingValue = Get-RingValue -Name $Ring
            }
            if ($SystemRingValue -lt $ConfigurationRingValue ) {
                $Object.Warning = "Configuration restricted to $($Configuration.Ring) ring. Current ring $Ring"
                $Configuration.Remove("Ring")
                $Configuration.Remove("OverrideMaintenanceWindow")
                $Configuration.Remove("VPN")
                $DSC = Test-TargetResource @Configuration
                $Object.DSC = $DSC
                $Status += $Object        
                return
            }
            $Configuration.Remove("Ring")
        }
        #Evaluate Maintenance Window Restrictions
        if ($Configuration.OverrideMaintenanceWindow -ne $true) {
            if (-not($Global:MaintenanceWindowEnabled -and $Global:MaintenanceWindowActive)) {
                $Object.Warning = "Configuration restricted to Maintenance Window"
                $Configuration.Remove("OverrideMaintenanceWindow")
                $Configuration.Remove("Ring")
                $Configuration.Remove("VPN")
                $DSC = Test-TargetResource @Configuration
                $Object.DSC = $DSC
                $Status += $Object        
                return
            }
        }
        $Configuration.Remove("OverrideMaintenanceWindow")
    
        $DSC = Test-TargetResource @Configuration
        if (-not($DSC)) {
            $null = Set-TargetResource @Configuration
            $DSC = Test-TargetResource @Configuration
        }
        $Object.DSC = $DSC
        $Status += $Object
    }
    #Remove Module for Write-Host limitations
    Remove-Module "cChocoPackageInstall"
    
    Write-Log -Severity "Information" -Message "Starting cChocoPackageInstall"
    $Status | ForEach-Object {
        Write-Host '----------cChocoPackageInstall----------' -ForegroundColor DarkCyan
        Write-Log -Severity 'Information' -Message "Name: $($_.Name)"
        Write-Log -Severity 'Information' -Message "Version $($_.Version)"
        Write-Log -Severity 'Information' -Message "DSC: $($_.DSC)"
        Write-Log -Severity 'Information' -Message "Source: $($_.Source)"
        Write-Log -Severity 'Information' -Message "Ensure: $($_.Ensure)"
        Write-Log -Severity 'Information' -Message "AutoUpgrade: $($_.AutoUpgrade)"
        Write-Log -Severity 'Information' -Message "VPN: $($_.VPN)"
        Write-Log -Severity 'Information' -Message "Params: $($_.Params)"
        Write-Log -Severity 'Information' -Message "ChocoParams: $($_.ChocoParams)"
        Write-Log -Severity 'Information' -Message "Ring: $($_.Ring)"
        Write-Log -Severity 'Information' -Message "OverrideMaintenanceWindow: $($_.OverrideMaintenanceWindow)"
        if ($_.Warning) {
            Write-Log -Severity Warning -Message "$($_.Warning)"
        }
    }
    Write-Host '----------cChocoPackageInstall----------' -ForegroundColor DarkCyan
}