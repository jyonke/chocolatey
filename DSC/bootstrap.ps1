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

Function RotateLog{
    if (Test-Path -Path (Join-Path $LogPath "cChoco.log")) {
        $LogFile = Get-Item (Join-Path $LogPath "cChoco.log")
        if ($LogFile.Length -ge 10MB) {
            Copy-Item -Path (Join-Path $LogPath "cChoco.log") -Destination (Join-Path $LogPath "cChoco.1.log")
            Clear-Content -Path (Join-Path $LogPath "cChoco.log") -Force -ErrorAction SilentlyContinue
        }
    }
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
    Invoke-WebRequest -Uri $SettingsURI -UseBasicParsing -OutFile (Join-Path "$env:SystemRoot\temp" "bootstrap-cchoco.psd1")
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

#Clean config folders of all cached PSD1's
if ($NoCache) {
    Get-ChildItem -Path (Join-Path $InstallDir "config") -Filter *.psd1 | Remove-Item -Recurse -Force
}
#Copy Config Config?
if ($ChocoConfig) {
    $null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $ChocoConfig -UseBasicParsing -OutFile (Join-Path "$InstallDir\config" "config.psd1")
}

#Copy Sources Config
if ($SourcesConfig) {
    $null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $SourcesConfig -UseBasicParsing -OutFile (Join-Path "$InstallDir\config" "sources.psd1")
}

#Copy Features Config
if ($FeatureConfig) {
    $null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $FeatureConfig -UseBasicParsing -OutFile (Join-Path "$InstallDir\config" "features.psd1")
}

#Copy Package Config
if ($PackageConfig) {
    $null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
    $PackageConfig | ForEach-Object {
        Invoke-WebRequest -Uri $_ -UseBasicParsing -OutFile (Join-Path "$InstallDir\config" ($_ | Split-Path -Leaf))
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
    $ConfigImport = Import-PowerShellDataFile (Join-Path "$InstallDir\config" "config.psd1")
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
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

#cChocoFeature
Write-Verbose "cChocoConfig:Validating Chocolatey Configurations are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoFeature")
Import-Module $ModulePath
 
if (Test-Path (Join-Path "$InstallDir\config" "features.psd1") ) {
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
    $ConfigImport = Import-PowerShellDataFile $_.FullName 
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
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