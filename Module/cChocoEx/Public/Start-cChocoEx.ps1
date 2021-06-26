function Start-cChocoEx {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $SettingsURI,
        # Chocolatey Installation Directory
        [Parameter()]
        [string]
        $InstallDir = "$env:ProgramData\chocolatey",
        # Chocolatey Installation Script URL
        [Parameter()]
        [string]
        $ChocoInstallScriptUrl = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/Install/install.ps1',
        # Parameter help description
        [Parameter()]
        [string]
        $ChocoDownloadUrl = 'https://github.com/jyonke/chocolatey/raw/master/Install/chocolatey.0.10.15.nupkg',
        # URL to cChoco sources configuration file
        [Parameter()]
        [string]
        $SourcesConfig,
        # URL to cCHoco packages
        [Parameter()]
        [array]
        $PackageConfig,
        # URL to cChoco Chocolatey configuration file
        [Parameter()]
        [string]
        $ChocoConfig,
        # URL to cChoco Chocolatey features configuration file
        [Parameter()]
        [string]
        $FeatureConfig,
        # Do not cache configuration files
        [Parameter()]
        [switch]
        $NoCache,
        # Wipe locally cached psd1 configurations
        [Parameter()]
        [switch]
        $WipeCache,
        # RandomDelay
        [Parameter()]
        [switch]
        $RandomDelay,
        # Loop the Function
        [Parameter()]
        [Switch]
        $Loop,
        # Loop Delay in Minutes
        [Parameter()]
        [int]
        $LoopDelay = 60
    )

    $i = 0
    do {
        $i++
        #Enable TLS 1.2
        #https://docs.microsoft.com/en-us/dotnet/api/system.net.securityprotocoltype?view=net-5.0
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        $CurrentExecutionPolicy = Get-ExecutionPolicy
        try {
            $null = Set-ExecutionPolicy Bypass -Scope CurrentUser
        }
        catch {
            Write-Log -Severity 'Warning' -Message "Error Changing Execution Policy"
        }

        try {
            $Global:LogPath = (Join-Path $InstallDir "logs")
            $null = New-Item -ItemType Directory -Path $LogPath -Force -ErrorAction SilentlyContinue
            Write-Log -Severity 'Information' -Message 'cChocoEx Started'
        }
        catch {
            Write-Warning "Error Starting Log, wiping and retrying"
            Write-Log -Severity 'Information' -Message 'cChoco Bootstrap Started' -New

        }

        #Evaluate Random Delay Switch
        if ($RandomDelay) {
            $RandomSeconds = Get-Random -Minimum 0 -Maximum 900
            Write-Log -Severity 'Information' -Message "Random Delay Enabled"
            Write-Log -Severity 'Information' -Message "Delay: $RandomSeconds`s"
            Start-Sleep -Seconds $RandomSeconds
        }

        #Settings
        if ($SettingsURI) {
            $Destination = (Join-Path "$env:SystemRoot\temp" "bootstrap-cchoco.psd1")
            switch (Test-PathEx -Path $SettingsURI) {
                'URL' { Invoke-WebRequest -Uri $SettingsURI -UseBasicParsing -OutFile $Destination }
                'FileSystem' { Copy-Item -Path $SettingsURI -Destination $Destination -Force }
            }    
            $SettingsFile = Import-PowerShellDataFile -Path (Join-Path "$env:SystemRoot\temp" "bootstrap-cchoco.psd1")
            $Settings = $SettingsFile | ForEach-Object { $_.Keys | ForEach-Object { $SettingsFile.$_ } } 
    
            #Variables
            $InstallDir = $Settings.InstallDir
            $ChocoInstallScriptUrl = $Settings.ChocoInstallScriptUrl
            $SourcesConfig = $Settings.SourcesConfig
            $PackageConfig = $Settings.PackageConfig
            $ChocoConfig = $Settings.ChocoConfig
            $FeatureConfig = $Settings.FeatureConfig
        }

        Write-Log -Severity 'Information' -Message "cChocoEx Settings"
        Write-Log -Severity 'Information' -Message "SettingsURI: $SettingsURI"
        Write-Log -Severity 'Information' -Message "InstallDir: $InstallDir"
        Write-Log -Severity 'Information' -Message "ChocoInstallScriptUrl: $ChocoInstallScriptUrl"
        Write-Log -Severity 'Information' -Message "SourcesConfig: $SourcesConfig"
        Write-Log -Severity 'Information' -Message "PackageConfig: $PackageConfig"
        Write-Log -Severity 'Information' -Message "ChocoConfig: $ChocoConfig"
        Write-Log -Severity 'Information' -Message "FeatureConfig: $FeatureConfig"

        #Set Enviromental Variable for chocolatey url to nupkg
        $env:chocolateyDownloadUrl = $ChocoDownloadUrl

        #Ensure Base Destination Paths Exist
        $null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
        $null = New-Item -ItemType Directory -Path (Join-Path "$env:TEMP\chocolatey" 'config') -Force -ErrorAction SilentlyContinue

        if ($WipeCache) {
            Write-Log -Severity 'Information' -Message 'WipeCache Enabled. Wiping any previously downloaded psd1 configuration files'
            Get-ChildItem -Path (Join-Path $InstallDir "config") -Filter *.psd1 | Remove-Item -Recurse -Force
        }
        #Preclear any previously downloaded NoCache configuration files
        if ($NoCache) {
            Write-Log -Severity 'Information' -Message 'NoCache Enabled. Wiping any previously downloaded NoCache configuration files from temp'
            Get-ChildItem -Path (Join-Path "$env:TEMP\chocolatey" 'config') -Filter *.psd1 | Remove-Item -Recurse -Force
        }

        #Copy Config Config?
        $Global:ChocoConfigDestination = (Join-Path "$InstallDir\config" "config.psd1")
        if ($ChocoConfig) {
            if ($NoCache) {
                $Global:ChocoConfigDestination = (Join-Path "$env:TEMP\chocolatey\config" "config.psd1")
            }
            switch (Test-PathEx -Path $ChocoConfig) {
                'URL' { Invoke-WebRequest -Uri $ChocoConfig -UseBasicParsing -OutFile $ChocoConfigDestination }
                'FileSystem' { Copy-Item -Path $ChocoConfig -Destination $ChocoConfigDestination -Force }
            }
            Write-Log -Severity 'Information' -Message 'Chocolatey Config File Set.'
        }

        #Copy Sources Config
        $Global:SourcesConfigDestination = (Join-Path "$InstallDir\config" "sources.psd1")
        if ($SourcesConfig) {
            if ($NoCache) {
                $Global:SourcesConfigDestination = (Join-Path "$env:TEMP\chocolatey\config" "sources.psd1")
            }
            switch (Test-PathEx -Path $SourcesConfig) {
                'URL' { Invoke-WebRequest -Uri $SourcesConfig -UseBasicParsing -OutFile $SourcesConfigDestination }
                'FileSystem' { Copy-Item -Path $SourcesConfig -Destination $SourcesConfigDestination -Force }
            }
            Write-Log -Severity 'Information' -Message 'Chocolatey Sources File Set.'
        }

        #Copy Features Config
        $Global:FeatureConfigDestination = (Join-Path "$InstallDir\config" "features.psd1")
        if ($FeatureConfig) {
            if ($NoCache) {
                $Global:FeatureConfigDestination = (Join-Path "$env:TEMP\chocolatey\config" "features.psd1")
            }
            switch (Test-PathEx -Path $FeatureConfig) {
                'URL' { Invoke-WebRequest -Uri $FeatureConfig -UseBasicParsing -OutFile $FeatureConfigDestination }
                'FileSystem' { Copy-Item -Path $FeatureConfig -Destination $FeatureConfigDestination -Force }
            }
            Write-Log -Severity 'Information' -Message 'Chocolatey Feature File Set.'
        }

        #Copy Package Config
        $Global:PackageConfigDestination = "$InstallDir\config"
        if ($PackageConfig) {
            if ($NoCache) {
                $Global:PackageConfigDestination = "$env:TEMP\chocolatey\config"
            }
            $PackageConfig | ForEach-Object {
                $Path = $_
                $Destination = (Join-Path $PackageConfigDestination ($_ | Split-Path -Leaf))
                switch (Test-PathEx -Path $_) {
                    'URL' { Invoke-WebRequest -Uri $Path -UseBasicParsing -OutFile $Destination }
                    'FileSystem' { Copy-Item -Path $Path -Destination $Destination -Force }
                }
            }
            Write-Log -Severity 'Information' -Message 'Chocolatey Package File Set.'
        }

        #Start-DSCConfiguation
        $Global:ModuleBase = (Get-Module -Name 'cChoco' -ListAvailable -ErrorAction Stop | Sort-Object -Property Version | Select-Object -Last 1).ModuleBase
        $Global:MaintenanceWindowEnabled = $True
        $Global:MaintenanceWindowActive = $True

        #cChocoInstaller
        $Configuration = @{
            InstallDir            = $InstallDir
            ChocoInstallScriptUrl = $ChocoInstallScriptUrl
        }
    
        Start-cChocoInstaller -Configuration $Configuration

        #cChocoConfig
        if (Test-Path $ChocoConfigDestination ) {
            $ConfigImport = $null
            $ConfigImport = Import-PowerShellDataFile $ChocoConfigDestination
            Start-cChocoConfig -ConfigImport $ConfigImport
        }
        else {
            Write-Log -Severity 'Warning'  -Message "File not found, configuration will not be modified"
        }

        #cChocoFeature
        if (Test-Path $FeatureConfigDestination ) {
            $ConfigImport = $null
            $ConfigImport = Import-PowerShellDataFile $FeatureConfigDestination
            Start-cChocoFeature -ConfigImport $ConfigImport
        }
        else {
            Write-Log -Severity 'Information' -Message "File not found, features will not be modified"
        }

        #cChocoSource
        if (Test-Path $SourcesConfigDestination ) {
            $ConfigImport = $null
            $ConfigImport = Import-PowerShellDataFile $SourcesConfigDestination
            Start-cChocoSource -ConfigImport $ConfigImport
        }
        else {
            Write-Log -Severity 'Information' -Message "File not found, sources will not be modified"
        }

        #cChocoPackageInstall
        [array]$Configurations = $null
        Get-ChildItem -Path $PackageConfigDestination -Filter *.psd1 | Where-Object { $_.Name -notmatch "sources.psd1|config.psd1|features.psd1" } | ForEach-Object {
            $ConfigImport = $null
            $ConfigImport = Import-PowerShellDataFile $_.FullName 
            $Configurations += $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
        }

        if ($Configurations ) {
            Start-cChocoPackageInstall -Configurations $Configurations
        }
        else {
            Write-Log -Severity 'Warning' -Message "File not found, packages will not be modified"
        }
    
        #Cleanup
        #Preclear any previously downloaded NoCache configuration files
        if ($NoCache) {
            Write-Log -Severity "Information" -Message "Preclear any previously downloaded NoCache configuration files"
            Get-ChildItem -Path (Join-Path "$env:TEMP\chocolatey" 'config') -Filter *.psd1 | Remove-Item -Recurse -Force
        }
        $null = Set-ExecutionPolicy $CurrentExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
        RotateLog

        if ($Loop) {
            Write-Log -Severity "Information" -Message "Function Looping Enabled"
            Write-Log -Severity "Information" -Message "Looping Delay: $LoopDelay Minutes"
            Write-Log -Severity "Information" -Message "Loop Count: $i"
            Start-Sleep -Seconds ($LoopDelay * 60)
        }

    } until ($Loop -eq $false)
}