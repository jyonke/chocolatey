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
    # URL to required cCHoco nupkg
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
    # Purge Localay Cached psd1's
    [Parameter()]
    [switch]
    $NoCache
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
    param (
        # Path
        [Parameter(Mandatory = $false)]
        [string]
        $Path = (Join-Path -Path (Join-Path $InstallDir "config") -ChildPath "ring.txt")
    )
    switch (Get-Content -Path $Path -ErrorAction SilentlyContinue) {
        "Canary" { $Ring = 'Canary' }
        "Fast" { $Ring = 'Fast' }
        "Slow" { $Ring = 'Slow' }
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
        "Canary" { $Value = 4 }
        "Fast" { $Value = 3 }
        "Slow" { $Value = 2 }
        Default { $Value = 0 }
    }
    return [int]$Value
}

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

#Confirm cChoco is installed and define $ModuleBase
$Test = 'Get-Module -ListAvailable -Name cChoco | Where-Object {$_.Version -eq $ModuleVersion}'
if (-not(Invoke-Expression -Command $Test)) {
    Write-Verbose "Installing cChoco - version $ModuleVersion"
    Write-Verbose "Source: $ModuleSource"
    $ModuleInstalled = $false
    if ($ModuleSource) {
        try {
            $DownloadFile = (Join-Path $env:TEMP "cChoco.$ModuleVersion.nupkg.zip")
            $Destination = (Join-Path "$env:ProgramFiles\WindowsPowerShell\Modules" "cChoco\$ModuleVersion")
            Invoke-WebRequest -Uri $ModuleSource -UseBasicParsing -OutFile $DownloadFile
            $null = New-Item -ItemType Directory -Path $Destination -Force -ErrorAction SilentlyContinue
            Expand-Archive -Path $DownloadFile -DestinationPath $Destination -Force -ErrorAction Stop
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
    if (Invoke-Expression -Command $Test) {
        $ModuleInstalled = $true
    }
}
else {
    $ModuleInstalled = $true
}
if ($ModuleInstalled) {
    $ModuleBase = (Invoke-Expression -Command $Test).ModuleBase
}
else {
    Throw "cChoco not installed"
    exit -1
}

#Ensure Destination Path Exists
$null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue

#Clean config folders of all cached PSD1's
if ($NoCache) {
    Get-ChildItem -Path (Join-Path $InstallDir "config") -Filter *.psd1 | Remove-Item -Recurse -Force
}
#Copy Config Config?
if ($ChocoConfig) {
    $Destination = (Join-Path "$InstallDir\config" "config.psd1")
    switch (Test-PathEx -Path $ChocoConfig) {
        'URL' { Invoke-WebRequest -Uri $ChocoConfig -UseBasicParsing -OutFile $Destination }
        'FileSystem' { Copy-Item -Path $ChocoConfig -Destination $Destination -Force }
    }
}

#Copy Sources Config
if ($SourcesConfig) {
    $Destination = (Join-Path "$InstallDir\config" "sources.psd1")
    switch (Test-PathEx -Path $SourcesConfig) {
        'URL' { Invoke-WebRequest -Uri $SourcesConfig -UseBasicParsing -OutFile $Destination }
        'FileSystem' { Copy-Item -Path $SourcesConfig -Destination $Destination -Force }
    }
}

#Copy Features Config
if ($FeatureConfig) {
    $Destination = (Join-Path "$InstallDir\config" "features.psd1")
    switch (Test-PathEx -Path $FeatureConfig) {
        'URL' { Invoke-WebRequest -Uri $FeatureConfig -UseBasicParsing -OutFile $Destination }
        'FileSystem' { Copy-Item -Path $FeatureConfig -Destination $Destination -Force }
    }
}

#Copy Package Config
if ($PackageConfig) {
    $PackageConfig | ForEach-Object {
        $Path = $_
        $Destination = (Join-Path "$InstallDir\config" ($_ | Split-Path -Leaf))
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
 
if (Test-Path (Join-Path "$InstallDir\config" "config.psd1") ) {
    $ConfigImport = $null
    $ConfigImport = Import-PowerShellDataFile (Join-Path "$InstallDir\config" "config.psd1")
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
    Write-Warning (Join-Path "$InstallDir\config" "config.psd1")
}

#cChocoConfig-MaintenanceWindowConfig
Write-Verbose "cChocoConfig-MaintenanceWindowConfig:Validating Chocolatey Maintenance Window is Setup"

$MaintenanceWindowEnabled = $True
$MaintenanceWindowActive = $True

if ($MaintenanceWindowConfig) {
    $Date = Get-Date 
    $StartTime = [datetime]$MaintenanceWindowConfig.Start
    if ([datetime]$MaintenanceWindowConfig.End -lt $StartTime) {
        $EndTime = ([datetime]$MaintenanceWindowConfig.End).AddDays(1)
    }
    else {
        $EndTime = [datetime]$MaintenanceWindowConfig.End
    }

    if ($MaintenanceWindowConfig.UTC -eq $True) {
        $Date = $Date.ToUniversalTime()
    }
    if ($Date -lt [datetime]$MaintenanceWindowConfig.EffectiveDateTime) {
        $MaintenanceWindowEnabled = $False
        $MaintenanceWindowActive = $False
        Write-Warning "EffectiveDateTime Set to Future DateTime"
    }
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
    Write-Host -ForegroundColor Gray        'Start:' -NoNewline
    Write-Host -ForegroundColor White       "$($MaintenanceWindowConfig.Start)             "
    Write-Host -ForegroundColor Gray        'End:' -NoNewline
    Write-Host -ForegroundColor White       "$($MaintenanceWindowConfig.End)             "
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
 
if (Test-Path (Join-Path "$InstallDir\config" "features.psd1") ) {
    $ConfigImport = $null
    $ConfigImport = Import-PowerShellDataFile (Join-Path "$InstallDir\config" "features.psd1")
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
    Write-Warning (Join-Path "$InstallDir\config" "features.psd1")
}

#cChocoSource
Write-Verbose "cChocoSource:Validating Chocolatey Sources are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoSource")
Import-Module $ModulePath
 
if (Test-Path (Join-Path "$InstallDir\config" "sources.psd1") ) {
    $ConfigImport = $null
    $ConfigImport = Import-PowerShellDataFile (Join-Path "$InstallDir\config" "sources.psd1")
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
    Write-Warning (Join-Path "$InstallDir\config" "sources.psd1")
}

#cChocoPackageInstall
Write-Verbose "cChocoPackageInstall:Validating Chocolatey Packages are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoPackageInstall")
Import-Module $ModulePath
$Status = @()
Get-ChildItem -Path "$InstallDir\config" -Filter *.psd1 | Where-Object { $_.Name -notmatch "sources.psd1|config.psd1|features.psd1" } | ForEach-Object {
    $ConfigImport = $null
    $ConfigImport = Import-PowerShellDataFile $_.FullName 
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
    $Ring = Get-Ring
    $Configurations | ForEach-Object {
        $DSC = $null
        $Configuration = $_
        $Object = [PSCustomObject]@{
            Name        = $Configuration.Name
            Version     = $Configuration.Version
            DSC         = $null
            Ensure      = $Configuration.Ensure
            Source      = $Configuration.Source
            AutoUpgrade = $Configuration.AutoUpgrade
            VPN         = $Configuration.VPN
            Params      = $Configuration.Params
            ChocoParams = $Configuration.ChocoParams
            Ring        = $Configuration.Ring
            Warning     = $null
        }
        #Evaluate VPN Restrictions
        if ($null -ne $Configuration.VPN) {
            if ($Configuration.VPN -eq $false -and $VPNStatus) {
                $Configuration.Remove("VPN")
                $Object.Warning = "Configuration restricted when VPN is connected"
                $DSC = Test-TargetResource @Configuration
                $Object.DSC = $DSC
                $Status += $Object        
                return
            }
            if ($Configuration.VPN -eq $true -and -not($VPNStatus)) {
                $Configuration.Remove("VPN")
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
                $Object.Warning = "Configuration restricted to $($Configuration.Ring) Ring"
                $Configuration.Remove("Ring")
                $DSC = Test-TargetResource @Configuration
                $Object.DSC = $DSC
                $Status += $Object        
                return
            }
            $Configuration.Remove("Ring")
        }
        $DSC = Test-TargetResource @Configuration
        if (-not($DSC)) {
            $null = Set-TargetResource @Configuration
            $DSC = Test-TargetResource @Configuration
        }
        $Object.DSC = $DSC
        $Status += $Object
    }
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
    Write-Host -ForegroundColor Gray        'Warning:' -NoNewline
    Write-Host -ForegroundColor White       "$($_.Warning)                    "
    Write-Host -ForegroundColor DarkCyan    '========================='
}

#Cleanup
$null = Set-ExecutionPolicy $CurrentExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if ($Transcript) {
    $null = Stop-Transcript -ErrorAction SilentlyContinue   
}
RotateLog