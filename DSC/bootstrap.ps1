[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $SettingsURI,
    # Use Cached bootstrap settings
    [Parameter()]
    [switch]
    $Cache
)
#Default Variables
$InstallDir = "$env:ProgramData\chocolatey"
$ChocoInstallScriptUrl = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/Install/install.ps1'
$ModuleVersion = "2.5.0.0"

$CurrentExecutionPolicy = Get-ExecutionPolicy
try {
    $null = Set-ExecutionPolicy Bypass -Scope CurrentUser
}
catch {
    Write-Warning "Error Changing Execution Policy"
}

try {
    Start-Transcript -Path (Join-Path "$env:SystemRoot\temp" "bootstrap-cchoco.log")
    $Transcript = $true
}
catch {
    Write-Warning "Error Starting Log"
    #$_.Exception.Message
}

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
}
elseif ($Cache -and (Test-Path (Join-Path "$env:SystemRoot\temp" "bootstrap-cchoco.psd1"))) {
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

}
else {
    Write-Warning "No settings defined, using all default"
}

Write-Verbose "SettingsURI = $SettingsURI"
Write-Verbose "InstallDir = $InstallDir"
Write-Verbose "ChocoInstallScriptUrl = $ChocoInstallScriptUrl"
Write-Verbose "ModuleSource = $ModuleSource"
Write-Verbose "ModuleVersion = $ModuleVersion"
Write-Verbose "SourcesConfig = $SourcesConfig"
Write-Verbose "PackageConfig = $PackageConfig"
Write-Verbose "ConfigConfig = $ChocoConfig"

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
Write-Output $Object | Select-Object * | Format-Table -AutoSize

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
    Write-Output $Status | Select-Object * | Format-Table -AutoSize
}
else {
    Write-Warning "File not found, configuration will not be modified"
    Write-Warning (Join-Path "$InstallDir\config" "config.psd1")
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
            Warning = $null
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
    Write-Output $Status | Select-Object * | Format-Table -AutoSize
}
else {
    Write-Warning "File not found, sources will not be modified"
    Write-Warning (Join-Path "$InstallDir\config" "sources.psd1")
}

#cChocoPackageInstall
Write-Verbose "cChocoPackageInstall:Validating Chocolatey Packages are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoPackageInstall")
Import-Module $ModulePath
Get-ChildItem -Path "$InstallDir\config" -Filter *.psd1 | Where-Object { $_.Name -ne "sources.psd1" -and $_.Name -ne "config.psd1" } | ForEach-Object {
    $ConfigImport = Import-PowerShellDataFile $_.FullName 
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
    $Status = @()
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
    Write-Output $Status | Select-Object * | Format-Table -AutoSize
}

#Cleanup
$null = Set-ExecutionPolicy $CurrentExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if ($Transcript) {
    Stop-Transcript -ErrorAction SilentlyContinue   
}