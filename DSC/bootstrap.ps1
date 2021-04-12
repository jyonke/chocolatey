<#
.SYNOPSIS
    Bootstrap Chocolatey and cChoco DSC Resource Module 
.DESCRIPTION
    Long description
.EXAMPLE
    bootstrap.ps1 -SettingsURI 'http://contoso.com/bootstrap-settings.psd1'
.EXAMPLE
    bootstrap.ps1 -PackageConfig 'http://contoso.com/cchoco-packages.psd1' -NoCache
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    Script to automate the installtion of the PowerShell DSC Module cCHoco and Chocolatey, and then process all defined desired states in your configuration files.
    https://github.com/jyonke/chocolatey
#>

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
    # URL to required cChoco nupkg
    [Parameter()]
    [string]
    $ModuleSource = 'https://github.com/jyonke/chocolatey/raw/master/DSC/nupkg/cchoco.2.5.0.nupkg',
    # cChoco Module Version
    [Parameter()]
    [string]
    $ModuleVersion = "2.5.0.0",
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
    $WipeCache
)

#Required Inline Functions
function New-PSCredential {
    [CmdletBinding()]
    param (
        # User Name
        [Parameter(Mandatory = $true)]
        [string]
        $User,
        # Encrypted Password
        [Parameter(Mandatory = $true)]
        [string]
        $Password,
        # Key File
        [Parameter(Mandatory = $true)]
        [string]
        $KeyFile
    )
    $key = Get-Content $KeyFile
    [pscredential]$PSCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, ($Password | ConvertTo-SecureString -Key $key)
    return $PSCredential
}

Function RotateLog {
    if (Test-Path -Path (Join-Path $LogPath "cChoco.log")) {
        $LogFile = Get-Item (Join-Path $LogPath "cChoco.log")
        if ($LogFile.Length -ge 10MB) {
            Copy-Item -Path (Join-Path $LogPath "cChoco.log") -Destination (Join-Path $LogPath "cChoco.1.log")
            Clear-Content -Path (Join-Path $LogPath "cChoco.log") -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-PathEx {
    param (
        # Path
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )
    $PathType = $null
    $URLRegEx = '^(http:\/\/www\.|https:\/\/www\.|http:\/\/|https:\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$'

    if (Test-Path -Path $Path -IsValid) {
        $PathType = 'FileSystem'
    }
    if ($Path -match $URLRegEx) {
        $PathType = 'URL'
    }
    $PathType
}

function Get-Ring {
    $RegValue = (Get-ItemProperty -Path "HKLM:\Software\Chocolatey\cChoco" -ErrorAction SilentlyContinue).Ring

    switch ($RegValue) {
        "Canary" { $Ring = 'canary' }
        "Fast" { $Ring = 'fast' }
        "Slow" { $Ring = 'slow' }
        Default { $Ring = $null }
    }
    if ($Ring) {
        Write-Warning "Machine Ring: $Ring"
    }
    return $Ring
}

function Get-RingValue {
    param (
        # Name
        [Parameter()]
        [string]
        $Name
    )
    switch ($Name) {
        "canary" { $Value = 4 }
        "fast" { $Value = 3 }
        "slow" { $Value = 2 }
        Default { $Value = 0 }
    }
    return [int]$Value
}

function Un7Zip-Archive {
    param (
        # Path
        [Parameter()]
        [string]
        $Path,
        # DestinationPath
        [Parameter()]
        [string]
        $DestinationPath
    )
    
    $7zaExe = Join-Path $env:TEMP -ChildPath '7za.exe'
    if (-not (Test-Path ($7zaExe))) {
        Write-Host "Downloading 7-Zip commandline tool prior to extraction."
        Invoke-WebRequest -UseBasicParsing -Uri 'https://community.chocolatey.org/7za.exe' -OutFile $7zaExe
    }
    else {
        Write-Host "7zip already present, skipping installation."
    }

    $params = 'x -o"{0}" -bd -y "{1}"' -f $DestinationPath, $Path

    # use more robust Process as compared to Start-Process -Wait (which doesn't
    # wait for the process to finish in PowerShell v3)
    $process = New-Object System.Diagnostics.Process

    try {
        $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo -ArgumentList $7zaExe, $params
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

        $null = $process.Start()
        $process.BeginOutputReadLine()
        $process.WaitForExit()

        $exitCode = $process.ExitCode
    }
    finally {
        $process.Dispose()
    }

    $errorMessage = "Unable to unzip package using 7zip. Perhaps try setting `$env:chocolateyUseWindowsCompression = 'true' and call install again. Error:"
    if ($exitCode -ne 0) {
        $errorDetails = switch ($exitCode) {
            1 { "Some files could not be extracted" }
            2 { "7-Zip encountered a fatal error while extracting the files" }
            7 { "7-Zip command line error" }
            8 { "7-Zip out of memory" }
            255 { "Extraction cancelled by the user" }
            default { "7-Zip signalled an unknown error (code $exitCode)" }
        }

        throw ($errorMessage, $errorDetails -join [Environment]::NewLine)
    }
}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
$CurrentExecutionPolicy = Get-ExecutionPolicy
try {
    $null = Set-ExecutionPolicy Bypass -Scope CurrentUser
}
catch {
    Write-Warning "Error Changing Execution Policy"
}

try {
    $LogPath = (Join-Path $InstallDir "logs")
    $null = New-Item -ItemType Directory -Path $LogPath -Force -ErrorAction SilentlyContinue
    $null = Start-Transcript -Path (Join-Path $LogPath "cChoco.log") -Append
    $Transcript = $true
}
catch {
    Write-Warning "Error Starting Log"
}

#Evaluate VPN Status
$VPNStatus = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'pangp|cisco|juniper|vpn' -and $_.Status -eq 'Up' }

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
    $ModuleSource = $Settings.ModuleSource
    $ModuleVersion = $settings.ModuleVersion
    $SourcesConfig = $settings.SourcesConfig
    $PackageConfig = $settings.PackageConfig
    $ChocoConfig = $settings.ChocoConfig
    $FeatureConfig = $settings.FeatureConfig
}

Write-Host -ForegroundColor DarkCyan    '=========================' -NoNewline
Write-Host -ForegroundColor Yellow      'cCHoco Bootstrap Settings' -NoNewline
Write-Host -ForegroundColor DarkCyan    '========================='
Write-Host -ForegroundColor Gray        'SettingsURI:' -NoNewline
Write-Host -ForegroundColor White       "$SettingsURI                               "
Write-Host -ForegroundColor Gray        'InstallDir:' -NoNewline
Write-Host -ForegroundColor White       "$InstallDir                                "
Write-Host -ForegroundColor Gray        'ChocoInstallScriptUrl:' -NoNewline
Write-Host -ForegroundColor White       "$ChocoInstallScriptUrl                     "
Write-Host -ForegroundColor Gray        'ModuleSource:' -NoNewline
Write-Host -ForegroundColor White       "$ModuleSource                              "
Write-Host -ForegroundColor Gray        'ModuleVersion:' -NoNewline
Write-Host -ForegroundColor White       "$ModuleVersion                             "
Write-Host -ForegroundColor Gray        'SourcesConfig:' -NoNewline
Write-Host -ForegroundColor White       "$SourcesConfig                             "
Write-Host -ForegroundColor Gray        'PackageConfig:' -NoNewline
Write-Host -ForegroundColor White       "$PackageConfig                             "
Write-Host -ForegroundColor Gray        'ChocoConfig:' -NoNewline
Write-Host -ForegroundColor White       "$ChocoConfig                               "
Write-Host -ForegroundColor Gray        'FeatureConfig:' -NoNewline
Write-Host -ForegroundColor White       "$FeatureConfig                             "

#Set Enviromental Variable for chocolatey url to nupkg
$env:chocolateyDownloadUrl = $ChocoDownloadUrl

#Confirm cChoco is installed and define $ModuleBase
$Destination = (Join-Path "$env:ProgramFiles\WindowsPowerShell\Modules" "cChoco\$ModuleVersion")

if (-not(Test-ModuleManifest (Join-Path $Destination 'cChoco.psd1') -ErrorAction SilentlyContinue)) {
    Write-Verbose "Installing cChoco - version $ModuleVersion"
    Write-Verbose "Source: $ModuleSource"
    $ModuleInstalled = $false
    if ($ModuleSource) {
        try {
            $DownloadFile = (Join-Path $env:TEMP "cChoco.$ModuleVersion.nupkg.zip")
            Invoke-WebRequest -Uri $ModuleSource -UseBasicParsing -OutFile $DownloadFile
            $null = New-Item -ItemType Directory -Path $Destination -Force -ErrorAction SilentlyContinue
            if ($PSVersionTable.PSVersion.Major -lt 5) {
                try {
                    $shellApplication = new-object -com shell.application
                    $zipPackage = $shellApplication.NameSpace($DownloadFile)
                    $destinationFolder = $shellApplication.NameSpace($Destination)
                    $destinationFolder.CopyHere($zipPackage.Items(), 0x10)
                }
                catch {
                    throw "Unable to unzip package using built-in compression. Error: `n $_"
                }              
            }
            else {
                Expand-Archive -Path $DownloadFile -DestinationPath $Destination -Force -ErrorAction Stop
            }
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }
    else {
        try {
            Write-Verbose "Attemping to install from PowerShell Gallery"
            $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction SilentlyContinue
            Install-Module cChoco -RequiredVersion $ModuleVersion -Confirm:$false -Force -ErrorAction Stop
        }
        catch {
            $_.Exception.Message
        }
    }
    
    if ($AltMethod) {
        
    }
    if (Test-ModuleManifest (Join-Path $Destination 'cChoco.psd1') -ErrorAction SilentlyContinue) {
        $ModuleInstalled = $true
    }
}
else {
    $ModuleInstalled = $true
}
if ($ModuleInstalled) {
    $ModuleBase = (Test-ModuleManifest (Join-Path $Destination 'cChoco.psd1') -ErrorAction SilentlyContinue).ModuleBase
}
else {
    Throw "cChoco not installed"
    exit -1
}

#Ensure Base Destination Paths Exist
$null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path (Join-Path "$env:TEMP\chocolatey" 'config') -Force -ErrorAction SilentlyContinue

#Clean config folders of all cached PSD1's
if ($WipeCache) {
    Get-ChildItem -Path (Join-Path $InstallDir "config") -Filter *.psd1 | Remove-Item -Recurse -Force
}
#Preclear any previously downloaded NoCache configuration files
if ($NoCache) {
    Get-ChildItem -Path (Join-Path "$env:TEMP\chocolatey" 'config') -Filter *.psd1 | Remove-Item -Recurse -Force
}
#Copy Config Config?
$ChocoConfigDestination = (Join-Path "$InstallDir\config" "config.psd1")
if ($ChocoConfig) {
    if ($NoCache) {
        $ChocoConfigDestination = (Join-Path "$env:TEMP\chocolatey\config" "config.psd1")
    }
    switch (Test-PathEx -Path $ChocoConfig) {
        'URL' { Invoke-WebRequest -Uri $ChocoConfig -UseBasicParsing -OutFile $ChocoConfigDestination }
        'FileSystem' { Copy-Item -Path $ChocoConfig -Destination $ChocoConfigDestination -Force }
    }
}

#Copy Sources Config
$SourcesConfigDestination = (Join-Path "$InstallDir\config" "sources.psd1")
if ($SourcesConfig) {
    if ($NoCache) {
        $SourcesConfigDestination = (Join-Path "$env:TEMP\chocolatey\config" "sources.psd1")
    }
    switch (Test-PathEx -Path $SourcesConfig) {
        'URL' { Invoke-WebRequest -Uri $SourcesConfig -UseBasicParsing -OutFile $SourcesConfigDestination }
        'FileSystem' { Copy-Item -Path $SourcesConfig -Destination $SourcesConfigDestination -Force }
    }
}

#Copy Features Config
$FeatureConfigDestination = (Join-Path "$InstallDir\config" "features.psd1")
if ($FeatureConfig) {
    if ($NoCache) {
        $FeatureConfigDestination = (Join-Path "$env:TEMP\chocolatey\config" "features.psd1")
    }
    switch (Test-PathEx -Path $FeatureConfig) {
        'URL' { Invoke-WebRequest -Uri $FeatureConfig -UseBasicParsing -OutFile $FeatureConfigDestination }
        'FileSystem' { Copy-Item -Path $FeatureConfig -Destination $FeatureConfigDestination -Force }
    }
}

#Copy Package Config
$PackageConfigDestination = "$InstallDir\config"
if ($PackageConfig) {
    if ($NoCache) {
        $PackageConfigDestination = "$env:TEMP\chocolatey\config"
    }
    $PackageConfig | ForEach-Object {
        $Path = $_
        $Destination = (Join-Path $PackageConfigDestination ($_ | Split-Path -Leaf))
        switch (Test-PathEx -Path $_) {
            'URL' { Invoke-WebRequest -Uri $Path -UseBasicParsing -OutFile $Destination }
            'FileSystem' { Copy-Item -Path $Path -Destination $Destination -Force }
        }
    }
}

#Start-DSCConfiguation
#cChocoInstaller
Write-Verbose "cChocoInstaller:Validating Chocolatey is installed"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoInstaller")
Import-Module $ModulePath
$Configuration = @{
    InstallDir            = $InstallDir
    ChocoInstallScriptUrl = $ChocoInstallScriptUrl
}
$Object = [PSCustomObject]@{
    Name                  = 'chocolatey'
    DSC                   = $null
    InstallDir            = $InstallDir
    ChocoInstallScriptUrl = $ChocoInstallScriptUrl
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

Write-Host -ForegroundColor DarkCyan    '=========================' -NoNewline
Write-Host -ForegroundColor Yellow      'cChocoInstaller' -NoNewline
Write-Host -ForegroundColor DarkCyan    '========================='
Write-Host -ForegroundColor Gray        'Name:' -NoNewline
Write-Host -ForegroundColor White       "$($Object.Name)                              "
Write-Host -ForegroundColor Gray        'DSC:' -NoNewline
Write-Host -ForegroundColor White       "$($Object.DSC)                               "
Write-Host -ForegroundColor Gray        'InstallDir:' -NoNewline
Write-Host -ForegroundColor White       "$($Object.InstallDir)                        "
Write-Host -ForegroundColor Gray        'ChocoInstallScriptUrl:' -NoNewline
Write-Host -ForegroundColor White       "$($Object.ChocoInstallScriptUrl)             "

#cChocoConfig
Write-Verbose "cChocoConfig:Validating Chocolatey Configurations are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoConfig")
Import-Module $ModulePath
 
if (Test-Path $ChocoConfigDestination ) {
    $ConfigImport = $null
    $ConfigImport = Import-PowerShellDataFile $ChocoConfigDestination
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

    Write-Host -ForegroundColor DarkCyan    '=========================' -NoNewline
    Write-Host -ForegroundColor Yellow      'cChocoConfig' -NoNewline
    Write-Host -ForegroundColor DarkCyan    '========================='
    $Status | ForEach-Object {
        Write-Host -ForegroundColor Gray        'ConfigName:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.ConfigName)             "
        Write-Host -ForegroundColor Gray        'DSC:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.DSC)                    "
        Write-Host -ForegroundColor Gray        'Ensure:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Ensure)                 "
        Write-Host -ForegroundColor Gray        'Value:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Value)                  "    
        Write-Host -ForegroundColor DarkCyan    '========================='                            
    }
}
else {
    Write-Warning "File not found, configuration will not be modified"
    Write-Warning $ChocoConfigDestination
}

#cChocoConfig-MaintenanceWindowConfig
Write-Verbose "cChocoConfig-MaintenanceWindowConfig:Validating Chocolatey Maintenance Window is Setup"

$MaintenanceWindowEnabled = $True
$MaintenanceWindowActive = $True

if ($MaintenanceWindowConfig) {
    $Date = Get-Date
    #Convert to UTC if option is enabled 
    if ($MaintenanceWindowConfig.UTC -eq $True) {
        $Date = $Date.ToUniversalTime()
    }
    #If calculated end time is less than current date, assume start window happens the next day
    if ([datetime]$MaintenanceWindowConfig.End -lt $Date) {
        $StartTime = ([datetime]$MaintenanceWindowConfig.Start).AddDays(1)
    }
    else {
        $StartTime = [datetime]$MaintenanceWindowConfig.Start
    }
    #If calculated end time is less than calculated start time (time span across 00:00), assume the end window happens the next day
    if ([datetime]$MaintenanceWindowConfig.End -lt $StartTime) {
        $EndTime = ([datetime]$MaintenanceWindowConfig.End).AddDays(1)
    }
    else {
        $EndTime = [datetime]$MaintenanceWindowConfig.End
    }
    #Determine if maintenance window is active yet, default to false if not active
    if ($Date -lt [datetime]$MaintenanceWindowConfig.EffectiveDateTime) {
        $MaintenanceWindowEnabled = $False
        $MaintenanceWindowActive = $False
        Write-Warning "EffectiveDateTime Set to Future DateTime"
    }
    #Determine if window is active
    else {
        if (($Date.ticks -ge $StartTime.Ticks) -and ($Date.Ticks -lt $EndTime.Ticks)) {
            $MaintenanceWindowActive = $True
        }
        else {
            $MaintenanceWindowActive = $False
        }
    }
    Write-Host -ForegroundColor DarkCyan    '=========================' -NoNewline
    Write-Host -ForegroundColor Yellow      'cChocoConfig-MaintenanceWindowConfig' -NoNewline
    Write-Host -ForegroundColor DarkCyan    '========================='
    Write-Host -ForegroundColor Gray        'Name:' -NoNewline
    Write-Host -ForegroundColor White       "$($MaintenanceWindowConfig.Name)             "
    Write-Host -ForegroundColor Gray        'EffectiveDateTime:' -NoNewline
    Write-Host -ForegroundColor White       "$($MaintenanceWindowConfig.EffectiveDateTime)             "
    Write-Host -ForegroundColor Gray        'Date:' -NoNewline
    Write-Host -ForegroundColor White       "$($Date)             "
    Write-Host -ForegroundColor Gray        'Start:' -NoNewline
    Write-Host -ForegroundColor White       "$($StartTime)             "
    Write-Host -ForegroundColor Gray        'End:' -NoNewline
    Write-Host -ForegroundColor White       "$($EndTime)             "
    Write-Host -ForegroundColor Gray        'UTC:' -NoNewline
    Write-Host -ForegroundColor White       "$($MaintenanceWindowConfig.UTC)             "
    Write-Host -ForegroundColor Gray        'MaintenanceWindowEnabled:' -NoNewline
    Write-Host -ForegroundColor White       "$($MaintenanceWindowEnabled)             "
    Write-Host -ForegroundColor Gray        'MaintenanceWindowActive:' -NoNewline
    Write-Host -ForegroundColor White       "$($MaintenanceWindowActive)             "

}
else {
    Write-Warning "No Defined Maintenance Window"
}

#cChocoFeature
Write-Verbose "cChocoConfig:Validating Chocolatey Configurations are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoFeature")
Import-Module $ModulePath
 
if (Test-Path $FeatureConfigDestination ) {
    $ConfigImport = $null
    $ConfigImport = Import-PowerShellDataFile $FeatureConfigDestination
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

    Write-Host -ForegroundColor DarkCyan    '=========================' -NoNewline
    Write-Host -ForegroundColor Yellow      'cChocoFeature' -NoNewline
    Write-Host -ForegroundColor DarkCyan    '========================='
    $Status | ForEach-Object {
        Write-Host -ForegroundColor Gray        'FeatureName:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.FeatureName)             "
        Write-Host -ForegroundColor Gray        'DSC:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.DSC)                    "
        Write-Host -ForegroundColor Gray        'Ensure:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Ensure)                 "
        Write-Host -ForegroundColor DarkCyan    '========================='
    }
}
else {
    Write-Warning "File not found, features will not be modified"
    Write-Warning $FeatureConfigDestination
}

#cChocoSource
Write-Verbose "cChocoSource:Validating Chocolatey Sources are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoSource")
Import-Module $ModulePath
 
if (Test-Path $SourcesConfigDestination ) {
    $ConfigImport = $null
    $ConfigImport = Import-PowerShellDataFile $SourcesConfigDestination
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
    $Status = @()
    $Configurations | ForEach-Object {
        $DSC = $null
        $Configuration = $_
        $Object = [PSCustomObject]@{
            Name     = $Configuration.Name
            Priority = $Configuration.Priority
            DSC      = $null
            Source   = $Configuration.Source
            Ensure   = $Configuration.Ensure
            User     = $Configuration.User
            KeyFile  = $Configuration.KeyFile
            Warning  = $null
        }

        #Create PSCredential from key pair if defined
        if ($Configuration.Password) {
            #Validate Keyfile
            if (-not(Test-Path -Path $Configuration.KeyFile)) {
                $Object.Warning = "Keyfile not accessible"
                $Status += $Object
                return
            }
            try {
                $Configuration.Credentials = New-PSCredential -User $Configuration.User -Password $Configuration.Password -KeyFile $Configuration.KeyFile
            }
            catch {
                $Object.Warning = "Can not create PSCredential"
                $Status += $Object
                return
            }
            $Configuration.Remove("User")
            $Configuration.Remove("Password")
            $Configuration.Remove("KeyFile")
        }
        $null = Set-TargetResource @Configuration
        $DSC = Test-TargetResource @Configuration
        
        $Object.DSC = $DSC
        $Status += $Object
    }
    #Remove Module for Write-Host limitations
    Remove-Module "cChocoSource"

    Write-Host -ForegroundColor DarkCyan    '=========================' -NoNewline
    Write-Host -ForegroundColor Yellow      'cChocoSource' -NoNewline
    Write-Host -ForegroundColor DarkCyan    '========================='
    $Status | ForEach-Object {
        Write-Host -ForegroundColor Gray        'Name:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Name)             "
        Write-Host -ForegroundColor Gray        'Priority:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Priority)                    "
        Write-Host -ForegroundColor Gray        'DSC:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.DSC)                 "
        Write-Host -ForegroundColor Gray        'Source:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Source)             "
        Write-Host -ForegroundColor Gray        'Ensure:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Ensure)                    "
        Write-Host -ForegroundColor Gray        'User:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.User)                 "
        Write-Host -ForegroundColor Gray        'KeyFile:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.KeyFile)             "
        Write-Host -ForegroundColor Gray        'Warning:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Warning)                    "
        Write-Host -ForegroundColor DarkCyan    '========================='
    }
}
else {
    Write-Warning "File not found, sources will not be modified"
    Write-Warning $SourcesConfigDestination
}

#cChocoPackageInstall
Write-Verbose "cChocoPackageInstall:Validating Chocolatey Packages are Setup"
$Status = @()
$Ring = Get-Ring

[array]$Configurations = $null
Get-ChildItem -Path $PackageConfigDestination -Filter *.psd1 | Where-Object { $_.Name -notmatch "sources.psd1|config.psd1|features.psd1" } | ForEach-Object {
    $ConfigImport = $null
    $ConfigImport = Import-PowerShellDataFile $_.FullName 
    $Configurations += $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
}
if ($Configurations) {
    #Validate No Duplicate Packages Defined
    $DuplicateSearch = (Compare-Object -ReferenceObject $Configurations.Name -DifferenceObject ($Configurations.Name | Select-Object -Unique) | Where-Object { $_.SideIndicator -eq '<=' }).InputObject
    $Duplicates = $Configurations | Where-Object { $DuplicateSearch -eq $_.Name }
    if ($Duplicates) {
        Write-Warning "Duplicate Package Found removing from active processesing"
        Write-Host -ForegroundColor DarkCyan    '=========================' -NoNewline
        Write-Host -ForegroundColor Red      'Duplicate cChocoPackageInstall' -NoNewline
        Write-Host -ForegroundColor DarkCyan    '========================='
        $Configurations | Where-Object { $Duplicates.Name -eq $_.Name } | ForEach-Object {
            Write-Host -ForegroundColor Gray        'Name:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.Name)             "
            Write-Host -ForegroundColor Gray        'Version:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.Version)                    "
            Write-Host -ForegroundColor Gray        'DSC:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.DSC)                 "
            Write-Host -ForegroundColor Gray        'Source:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.Source)             "
            Write-Host -ForegroundColor Gray        'Ensure:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.Ensure)                    "
            Write-Host -ForegroundColor Gray        'AutoUpgrade:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.AutoUpgrade)                 "
            Write-Host -ForegroundColor Gray        'VPN:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.VPN)             "
            Write-Host -ForegroundColor Gray        'Params:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.Params)                    "
            Write-Host -ForegroundColor Gray        'ChocoParams:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.ChocoParams)                    "
            Write-Host -ForegroundColor Gray        'Ring:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.Ring)                    "
            Write-Host -ForegroundColor Gray        'OverrideMaintenanceWindow:' -NoNewline
            Write-Host -ForegroundColor White       "$($_.OverrideMaintenanceWindow)                    "
            Write-Host -ForegroundColor Gray        'Warning:' -NoNewline
            Write-Host -ForegroundColor White       "Duplicate Package Defined                    "
            Write-Host -ForegroundColor DarkCyan    '========================='
        }
        #Filter Out Duplicates and Clear all package configuration files for next time processing
        $Configurations = $Configurations | Where-Object { $Duplicates.Name -notcontains $_.Name }
        #Get-ChildItem -Path $PackageConfigDestination -Filter *.psd1 | Where-Object { $_.Name -notmatch "sources.psd1|config.psd1|features.psd1" } | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    $ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoPackageInstall")
    Import-Module $ModulePath

    $Configurations | ForEach-Object {
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
            if (-not($MaintenanceWindowEnabled -and $MaintenanceWindowActive)) {
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

    Write-Host -ForegroundColor DarkCyan    '=========================' -NoNewline
    Write-Host -ForegroundColor Yellow      'cChocoPackageInstall' -NoNewline
    Write-Host -ForegroundColor DarkCyan    '========================='
    $Status | ForEach-Object {
        Write-Host -ForegroundColor Gray        'Name:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Name)             "
        Write-Host -ForegroundColor Gray        'Version:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Version)                    "
        Write-Host -ForegroundColor Gray        'DSC:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.DSC)                 "
        Write-Host -ForegroundColor Gray        'Source:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Source)             "
        Write-Host -ForegroundColor Gray        'Ensure:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Ensure)                    "
        Write-Host -ForegroundColor Gray        'AutoUpgrade:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.AutoUpgrade)                 "
        Write-Host -ForegroundColor Gray        'VPN:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.VPN)             "
        Write-Host -ForegroundColor Gray        'Params:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Params)                    "
        Write-Host -ForegroundColor Gray        'ChocoParams:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.ChocoParams)                    "
        Write-Host -ForegroundColor Gray        'Ring:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Ring)                    "
        Write-Host -ForegroundColor Gray        'OverrideMaintenanceWindow:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.OverrideMaintenanceWindow)                    "
        Write-Host -ForegroundColor Gray        'Warning:' -NoNewline
        Write-Host -ForegroundColor White       "$($_.Warning)                    "
        Write-Host -ForegroundColor DarkCyan    '========================='
    }
}
else {
    Write-Warning "File not found, packages will not be modified"
}


#Cleanup
#Preclear any previously downloaded NoCache configuration files
if ($NoCache) {
    Get-ChildItem -Path (Join-Path "$env:TEMP\chocolatey" 'config') -Filter *.psd1 | Remove-Item -Recurse -Force
}
$null = Set-ExecutionPolicy $CurrentExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if ($Transcript) {
    $null = Stop-Transcript -ErrorAction SilentlyContinue   
}
RotateLog