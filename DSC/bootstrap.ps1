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
        Write-Log -Severity 'Information' -Message "Machine Ring: $Ring"
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
        Write-Log -Severity 'Information' -Message "Downloading 7-Zip commandline tool prior to extraction."
        Invoke-WebRequest -UseBasicParsing -Uri 'https://community.chocolatey.org/7za.exe' -OutFile $7zaExe
    }
    else {
        Write-Log -Severity 'Information' -Message "7zip already present, skipping installation."
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
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = (Join-Path $LogPath "cChoco.log"),
        [Parameter()]
        [Switch]
        $New
    )
 
    if ($New) {
        Remove-Item -Path $Path -Force
    }
    switch ($Severity) {
        Information { $Color = "White" }
        Warning { $Color = "Yellow" }
        Error { $Color = "Red" }
        Default { $Color = "White" }
    }
    $Object = [pscustomobject]@{
        Time     = (Get-Date -f g)
        Severity = $Severity
        Message  = $Message
    } 
    $Object | Export-Csv -Path $Path -Append -NoTypeInformation
    Write-Host "$($Object.Time) - $($Object.Severity) - $($Object.Message)" -ForegroundColor $Color
}
function Get-MaintenanceWindow {
    param (
        # UTC
        [Parameter()]
        [bool]
        $UTC,
        # StartTime
        [Parameter(Mandatory = $True)]
        [datetime]
        $StartTime,
        # EndTime
        [Parameter(Mandatory = $True)]
        [datetime]
        $EndTime,
        # Effective Date Time
        [Parameter(Mandatory = $False)]
        [datetime]
        $EffectiveDateTime
    )
    $Date = Get-Date
    Write-Verbose "Current Date: $Date"
    if ($UTC -eq $True) {
        $Date = $Date.ToUniversalTime()
        Write-Verbose "Converted Time to UTC"
        Write-Verbose "Current Date: $Date"
    }
    #Offset Times if TimeSpan crosses 00:00
    if ($StartTime.TimeOfDay -gt $EndTime.TimeOfDay) {
        $OffSet = 24 - $StartTime.TimeOfDay.TotalHours
        $AltDate = $Date.TimeOfDay.TotalHours + $OffSet
        if ($AltDate -gt 24) {
            $AltDate = $AltDate - 24
        }
        $AltStartTime = [int]0.0
        $AltEndTime = $EndTime.TimeOfDay.TotalHours + $OffSet
        $MaintenanceWindowActive = $AltDate -ge $AltStartTime -and $AltDate -le $AltEndTime
        Write-Verbose "Start Time is Greater Than EndTime"
        Write-Verbose "Offset: $OffSet"
        Write-Verbose "AltDateHours: $AltDate"
        Write-Verbose "AltStartTimeHours: $AltStartTime"
        Write-Verbose "AltEndTimHours: $AltEndTime"
    }
    if (($StartTime.TimeOfDay -lt $EndTime.TimeOfDay)) {
        $MaintenanceWindowActive = $Date.TimeOfDay.TotalHours -ge $StartTime.TimeOfDay.TotalHours -and $Date.TimeOfDay.TotalHours -le $EndTime.TimeOfDay.TotalHours
        Write-Verbose "Start Time is Less Than EndTime"
    }
    #Determine if maintenance window is active yet, default to false if not active
    if ($Date -lt $EffectiveDateTime) {
        $MaintenanceWindowEnabled = $False
        $MaintenanceWindowActive = $False
        Write-Verbose "MaintenanceWindowEnabled False - Date is less than Effective Date Time"
    }
    else {
        $MaintenanceWindowEnabled = $True
        Write-Verbose "MaintenanceWindowEnabled True - Date is greater than Effective Date Time"

    }
    Write-Verbose "DateTimeofDay: $($Date.TimeOfDay)"
    Write-Verbose "StartTimeTimeOfDay: $($StartTime.TimeOfDay)"
    Write-Verbose "EndTimeTimeOfDay: $($EndTime.TimeOfDay)"
    Write-Verbose "EffectiveDateTime: $EffectiveDateTime"
    Write-Verbose "MaintenanceWindowEnabled: $MaintenanceWindowEnabled"
    Write-Verbose "MaintenanceWindowActive: $MaintenanceWindowActive"

    return [PSCustomObject]@{
        MaintenanceWindowEnabled = $MaintenanceWindowEnabled
        MaintenanceWindowActive  = $MaintenanceWindowActive
    }
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    function Import-PowerShellDataFile {
        param (
            # Path to PSD1 File
            [Parameter(Mandatory = $true)]
            [string]
            $Path
        )
        [hashtable][Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformation()]$Hashtable = $Path
        return $Hashtable
    }
}

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
    Write-Log -Severity 'Information' -Message 'cChoco Bootstrap Started'
}
catch {
    Write-Warning "Error Starting Log, wiping and retrying"
    Write-Log -Severity 'Information' -Message 'cChoco Bootstrap Started' -New

}

#Evaluate VPN Status
$VPNStatus = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'pangp|cisco|juniper|vpn' -and $_.Status -eq 'Up' }
if ($VPNStatus) {
    Write-Log -Severity 'Information' -Message "VPN Status: Active"
}
else {
    Write-Log -Severity 'Information' -Message "VPN Status: InActive"
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
    $ModuleSource = $Settings.ModuleSource
    $ModuleVersion = $settings.ModuleVersion
    $SourcesConfig = $settings.SourcesConfig
    $PackageConfig = $settings.PackageConfig
    $ChocoConfig = $settings.ChocoConfig
    $FeatureConfig = $settings.FeatureConfig
}

Write-Log -Severity 'Information' -Message "cCHoco Bootstrap Settings"
Write-Log -Severity 'Information' -Message "SettingsURI: $SettingsURI"
Write-Log -Severity 'Information' -Message "InstallDir: $InstallDir"
Write-Log -Severity 'Information' -Message "ChocoInstallScriptUrl: $ChocoInstallScriptUrl"
Write-Log -Severity 'Information' -Message "ModuleSource: $ModuleSource"
Write-Log -Severity 'Information' -Message "ModuleVersion: $ModuleVersion"
Write-Log -Severity 'Information' -Message "SourcesConfig: $SourcesConfig"
Write-Log -Severity 'Information' -Message "PackageConfig: $PackageConfig"
Write-Log -Severity 'Information' -Message "ChocoConfig: $ChocoConfig"
Write-Log -Severity 'Information' -Message "FeatureConfig: $FeatureConfig"

#Set Enviromental Variable for chocolatey url to nupkg
$env:chocolateyDownloadUrl = $ChocoDownloadUrl

#Confirm cChoco is installed and define $ModuleBase
$Destination = (Join-Path "$env:ProgramFiles\WindowsPowerShell\Modules" "cChoco\$ModuleVersion")

if (-not(Test-ModuleManifest (Join-Path $Destination 'cChoco.psd1') -ErrorAction SilentlyContinue)) {
    Write-Log -Severity 'Information' -Message "Installing cChoco - version $ModuleVersion"
    Write-Log -Severity 'Information' -Message "Source: $ModuleSource"
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
                    Write-Log -Severity 'Error' -Message "Unable to unzip package using built-in compression."
                    Write-Log -Severity 'Error' -Message "$($_.Exception.Message)"
                    throw "Unable to unzip package using built-in compression. Error: `n $_"
                }              
            }
            else {
                Expand-Archive -Path $DownloadFile -DestinationPath $Destination -Force -ErrorAction Stop
            }
        }
        catch {
            Write-Log -Severity 'Error' -Message "$($_.Exception.Message)"
        }
    }
    else {
        try {
            Write-Log -Severity 'Information' -Message "Attemping to install from PowerShell Gallery"
            $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction SilentlyContinue
            Install-Module cChoco -RequiredVersion $ModuleVersion -Confirm:$false -Force -ErrorAction Stop
        }
        catch {
            Write-Log -Severity 'Error' -Message "$($_.Exception.Message)"
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
    Write-Log -Severity 'Error' -Message "cChoco not installed"
    Throw "cChoco not installed"
    exit -1
}

#Ensure Base Destination Paths Exist
$null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path (Join-Path "$env:TEMP\chocolatey" 'config') -Force -ErrorAction SilentlyContinue

#Clean config folders of all cached PSD1's
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
$ChocoConfigDestination = (Join-Path "$InstallDir\config" "config.psd1")
if ($ChocoConfig) {
    if ($NoCache) {
        $ChocoConfigDestination = (Join-Path "$env:TEMP\chocolatey\config" "config.psd1")
    }
    switch (Test-PathEx -Path $ChocoConfig) {
        'URL' { Invoke-WebRequest -Uri $ChocoConfig -UseBasicParsing -OutFile $ChocoConfigDestination }
        'FileSystem' { Copy-Item -Path $ChocoConfig -Destination $ChocoConfigDestination -Force }
    }
    Write-Log -Severity 'Information' -Message 'Chocolatey Config File Set.'
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
    Write-Log -Severity 'Information' -Message 'Chocolatey Sources File Set.'
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
    Write-Log -Severity 'Information' -Message 'Chocolatey Feature File Set.'
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
    Write-Log -Severity 'Information' -Message 'Chocolatey Package File Set.'
}

#Start-DSCConfiguation
#cChocoInstaller
Write-Log -Severity 'Information' -Message "cChocoInstaller:Validating Chocolatey is installed"
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

Write-Log -Severity 'Information' -Message "cChocoInstaller"
Write-Log -Severity 'Information' -Message "Name: $($Object.Name)"
Write-Log -Severity 'Information' -Message "DSC: $($Object.DSC)"
Write-Log -Severity 'Information' -Message "InstallDir: $($Object.InstallDir)"
Write-Log -Severity 'Information' -Message "ChocoInstallScriptUrl: $($Object.ChocoInstallScriptUrl)"

#cChocoConfig
Write-Log -Severity 'Information' -Message "cChocoConfig:Validating Chocolatey Configurations are Setup"
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

    Write-Log -Severity 'Information' -Message 'cChocoConfig'
    $Status | ForEach-Object {
        Write-Log -Severity 'Information' -Message "ConfigName: $($_.ConfigName)"
        Write-Log -Severity 'Information' -Message "DSC: $($_.DSC)"
        Write-Log -Severity 'Information' -Message "Ensure: $($_.Ensure)"
        Write-Log -Severity 'Information' -Message "Value: $($_.Value)"               
    }
}
else {
    Write-Log -Severity 'Warning'  -Message "File not found, configuration will not be modified"          
}

#cChocoConfig-MaintenanceWindowConfig
Write-Log -Severity 'Information'  -Message "cChocoConfig-MaintenanceWindowConfig:Validating Chocolatey Maintenance Window is Setup"

$MaintenanceWindowEnabled = $True
$MaintenanceWindowActive = $True

if ($MaintenanceWindowConfig) {
    $MaintenanceWindowTest = Get-MaintenanceWindow -StartTime $MaintenanceWindowConfig.Start -EndTime $MaintenanceWindowConfig.End -EffectiveDateTime $MaintenanceWindowConfig.EffectiveDateTime -UTC $MaintenanceWindowConfig.UTC -Verbose
    $MaintenanceWindowEnabled = $MaintenanceWindowTest.MaintenanceWindowEnabled
    $MaintenanceWindowActive = $MaintenanceWindowTest.MaintenanceWindowActive

    Write-Log -Severity 'Information' -Message "cChocoConfig-MaintenanceWindowConfig"
    Write-Log -Severity 'Information' -Message "Name: $($MaintenanceWindowConfig.Name)"
    Write-Log -Severity 'Information' -Message "EffectiveDateTime: $($MaintenanceWindowConfig.EffectiveDateTime)"
    Write-Log -Severity 'Information' -Message "Start: $($MaintenanceWindowConfig.Start)"
    Write-Log -Severity 'Information' -Message "End: $($MaintenanceWindowConfig.End)"
    Write-Log -Severity 'Information' -Message "UTC: $($MaintenanceWindowConfig.UTC)"
    Write-Log -Severity 'Information' -Message "MaintenanceWindowEnabled: $($MaintenanceWindowEnabled)"
    Write-Log -Severity 'Information' -Message "MaintenanceWindowActive: $($MaintenanceWindowActive)"
}
else {
    Write-Log -Severity 'Warning' -Message "No Defined Maintenance Window"
}

#cChocoFeature
Write-Log -Severity 'Information' -Message "cChocoConfig:Validating Chocolatey Configurations are Setup"
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

    Write-Log -Severity 'Information' -Message 'cChocoFeature'
    $Status | ForEach-Object {
        Write-Log -Severity 'Information' -Message "FeatureName: $($_.FeatureName)"
        Write-Log -Severity 'Information' -Message "DSC: $($_.DSC)"
        Write-Log -Severity 'Information' -Message "Ensure: $($_.Ensure)"
    }
}
else {
    Write-Log -Severity 'Information' -Message "File not found, features will not be modified"
}

#cChocoSource
Write-Log -Severity "Information" -Message "cChocoSource:Validating Chocolatey Sources are Setup"
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

    Write-Log -Severity 'Information' -Message "cChocoSource"
    $Status | ForEach-Object {
        Write-Log -Severity 'Information' -Message "Name: $($_.Name)"
        Write-Log -Severity 'Information' -Message "DSC: $($_.DSC)"
        Write-Log -Severity 'Information' -Message "Ensure: $($_.Ensure)"
        Write-Log -Severity 'Information' -Message "Priority: $($_.Priority)"
        Write-Log -Severity 'Information' -Message "Source: $($_.Source)"
        Write-Log -Severity 'Information' -Message "User: $($_.User)"
        Write-Log -Severity 'Information' -Message "KeyFile: $($_.KeyFile)"
        if ($_.Warning) {
            Write-Log -Severity 'Warning' -Message "$($_.Warning)"
        }
    }
}
else {
    Write-Log -Severity "Information" -Message "File not found, sources will not be modified"
}

#cChocoPackageInstall
Write-Log -Severity "Information" -Message "cChocoPackageInstall:Validating Chocolatey Packages are Setup"
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

    Write-Log -Severity "Information" -Message "cChocoPackageInstall"
    $Status | ForEach-Object {
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