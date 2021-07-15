function New-cChocoExFeature {
    [CmdletBinding()]
    param (
        # Path of Output File
        [Parameter(Mandatory)]
        [string]
        $Path
    )
    
    begin {
        #Gather Requested Values
        $cChocoFeatureOptions = @(
            "checksumFiles"
            "autoUninstaller"
            "allowGlobalConfirmation"
            "failOnAutoUninstaller"
            "failOnStandardError"
            "allowEmptyChecksums"
            "allowEmptyChecksumsSecure"
            "powershellHost"
            "logEnvironmentValues"
            "virusCheck"
            "failOnInvalidOrMissingLicense"
            "ignoreInvalidOptionsSwitches"
            "usePackageExitCodes"
            "useEnhancedExitCodes"
            "exitOnRebootDetected"
            "useFipsCompliantChecksums"
            "showNonElevatedWarnings"
            "showDownloadProgress"
            "stopOnFirstPackageFailure"
            "useRememberedArgumentsForUpgrades"
            "ignoreUnfoundPackagesOnUpgradeOutdated"
            "skipPackageUpgradesWhenNotInstalled"
            "removePackageInformationOnUninstall"
            "logWithoutColor"
            "logValidationResultsOnWarnings"
            "usePackageRepositoryOptimizations"
            "scriptsCheckLastExitCode"    
        )
        [array]$HashTableArray = @()
        $ExportString = "@{`n"
        $Absent = New-Object System.Management.Automation.Host.ChoiceDescription '&Absent'
        $Present = New-Object System.Management.Automation.Host.ChoiceDescription '&Present'
        $SelectTrue = New-Object System.Management.Automation.Host.ChoiceDescription '&True'
        $SelectFalse = New-Object System.Management.Automation.Host.ChoiceDescription '&False'
        $EnsureOptions = [System.Management.Automation.Host.ChoiceDescription[]]($Present, $Absent)
        $TrueFalseOptions = [System.Management.Automation.Host.ChoiceDescription[]]($SelectTrue, $SelectFalse)
        $Title = 'cChocoEx - Desired State'
        $cChocoConfigSelections = $cChocoFeatureOptions | Sort-Object | Out-GridView -Title "cChocoConfig Options" -OutputMode Multiple
    }
    
    process {
        $cChocoConfigSelections | ForEach-Object {
            $FeatureName = $null
            $Ensure = $null

            Write-Host "FeatureName: $_"
            $FeatureName = $_
            $EnsureSelection = $host.ui.PromptForChoice(($Title + " - $FeatureName - Ensure"), '', $EnsureOptions, 0)

            switch ($EnsureSelection) {
                0 { $Ensure = 'Present' }
                1 { $Ensure = 'Absent' }
                Default {}
            }

            $HashTableArray += @{
                FeatureName = $FeatureName
                Ensure      = $Ensure
            }
            $ExportString += @"
    '$FeatureName' = @{
        FeatureName = '$FeatureName'
        Ensure      = '$Ensure'
    }`n
"@
        }
        $ExportString += "`n}"
    }
    
    end {
        $ExportString | Set-Content -Path $Path
    }
}