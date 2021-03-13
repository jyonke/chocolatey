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
$ModuleVersion = "2.4.1.0"

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
    Start-BitsTransfer -Destination (Join-Path "$env:SystemRoot\temp" "bootstrap-cchoco.psd1") -Source $SettingsURI -ErrorAction Stop
    $SettingsFile = Import-PowerShellDataFile -Path (Join-Path "$env:SystemRoot\temp" "bootstrap-cchoco.psd1")
    $Settings = $SettingsFile | ForEach-Object { $_.Keys | ForEach-Object { $SettingsFile.$_ } } 
    
    #Variables
    $InstallDir = $Settings.InstallDir
    $ChocoInstallScriptUrl = $Settings.ChocoInstallScriptUrl
    $ModuleSource = $Settings.ModuleSource
    $ModuleVersion = $settings.ModuleVersion
    $SourcesConfig = $settings.SourcesConfig
    $PackageConfig = $settings.PackageConfig
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

}
else {
    Write-Warning "No settings defined, using all default"
}

Write-Output "SettingsURI = $SettingsURI"
Write-Output "InstallDir = $InstallDir"
Write-Output "ChocoInstallScriptUrl = $ChocoInstallScriptUrl"
Write-Output "ModuleSource = $ModuleSource"
Write-Output "ModuleVersion = $ModuleVersion"
Write-Output "SourcesConfig = $SourcesConfig"
Write-Output "PackageConfig = $PackageConfig"

#Confirm cChoco is installed and define $ModuleBase
$Test = 'Get-Module -ListAvailable -Name cChoco | Where-Object {$_.Version -eq $ModuleVersion}'
if (-not(Invoke-Expression -Command $Test)) {
    Write-Output "Installing cChoco - version $ModuleVersion"
    Write-Output "Source: $ModuleSource"
    $ModuleInstalled = $false
    if ($ModuleSource) {
        try {
            $DownloadFile = (Join-Path $env:TEMP "cChoco.$ModuleVersion.nupkg.zip")
            $Destination = (Join-Path "$env:ProgramFiles\WindowsPowerShell\Modules" "cChoco\$ModuleVersion")
            Start-BitsTransfer -Destination $DownloadFile -Source $ModuleSource -ErrorAction Stop
            $null = New-Item -ItemType Directory -Path $Destination -Force -ErrorAction SilentlyContinue
            Expand-Archive -Path $DownloadFile -DestinationPath $Destination -Force -ErrorAction Stop
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }
    else {
        try {
            Write-Output "Attemping to install from PowerShell Gallery"
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

#Copy Sources Config
if ($SourcesConfig) {
    $null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
    $SourcesConfig | ForEach-Object {
        Start-BitsTransfer -Source $_ -Destination (Join-Path "$InstallDir\config" "sources.psd1")
    }
}

#Copy Package Config
if ($PackageConfig) {
    $null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
    $PackageConfig | ForEach-Object {
        Start-BitsTransfer -Source $_ -Destination (Join-Path "$InstallDir\config" ($_ | Split-Path -Leaf))
    } 
}

#Confirm chocolatey is installed
Write-Output "cChocoInstaller:Validating Chocolatey is installed"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoInstaller")
Import-Module $ModulePath
$Configuration = @{
    InstallDir            = $InstallDir
    ChocoInstallScriptUrl = $ChocoInstallScriptUrl
}
if (-not(Test-TargetResource @Configuration )) {
    Set-TargetResource @Configuration   
}

#Confirm chocolatey sources are setup correctly
Write-Output "cChocoSource:Validating Chocolatey Sources are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoSource")
Import-Module $ModulePath
 
if (Test-Path (Join-Path "$InstallDir\config" "sources.psd1") ) {
    $ConfigImport = Import-PowerShellDataFile (Join-Path "$InstallDir\config" "sources.psd1")
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
    $Configurations | ForEach-Object {
        $DSC = $null
        $Configuration = $_
        $Object = [PSCustomObject]$Configuration
        #Create PSCredential from key pair if defined
        if ($Configuration.Password) {
            #Validate Keyfile
            if (-not(Test-Path -Path $Configuration.KeyFile)) {
                Write-Warning "Keyfile not accessible - $($Configuration.KeyFile)"
                return
            }
            try {
                $Configuration.Credentials = New-PSCredential -User $Configuration.User -Password $Configuration.Password -KeyFile $Configuration.KeyFile
            }
            catch {
                Write-Warning "Can not create PSCredential"
                return
            }
            $Configuration.Remove("User")
            $Configuration.Remove("Password")
            $Configuration.Remove("KeyFile")
        }
        $DSC = Set-TargetResource @Configuration
        $DSC = Test-TargetResource @Configuration
        
        $Object | Add-Member -MemberType NoteProperty -Name DSC -Value $DSC
        $Object
    }
}
else {
    Write-Warning "File not found, sources will not be modified"
    Write-Warning (Join-Path "$InstallDir\config" "sources.psd1")
}

#Process Configuration
Write-Output "cChocoPackageInstall:Validating Chocolatey Sources are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoPackageInstall")
Import-Module $ModulePath
Get-ChildItem -Path "$InstallDir\config" -Filter *.psd1 | Where-Object { $_.Name -ne "sources.psd1" } | ForEach-Object {
    $ConfigImport = Import-PowerShellDataFile $_.FullName 
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
    $Configurations | ForEach-Object {
        $DSC = $null
        $Configuration = $_
        $Object = [PSCustomObject]$Configuration
        #Evaluate VPN Restrictions
        if ($null -ne $Configuration.VPN) {
            if ($Configuration.VPN -eq $false -and $VPNStatus) {
                $Configuration.Remove("VPN")
                $Object | Add-Member -MemberType NoteProperty -Name Warning -Value "Configuration restricted when VPN is connected"
                $DSC = Test-TargetResource @Configuration
                $Object | Add-Member -MemberType NoteProperty -Name DSC -Value $DSC
                $Object        
                return
            }
            if ($Configuration.VPN -eq $true -and -not($VPNStatus)) {
                $Configuration.Remove("VPN")
                $Object | Add-Member -MemberType NoteProperty -Name Warning -Value "Configuration restricted when VPN is not established"
                $DSC = Test-TargetResource @Configuration
                $Object | Add-Member -MemberType NoteProperty -Name DSC -Value $DSC
                $Object
                return
            }
            $Configuration.Remove("VPN")
        }
        $DSC = Test-TargetResource @Configuration
        if (-not($DSC)) {
            $DSC = Set-TargetResource @Configuration
        }
        $Object | Add-Member -MemberType NoteProperty -Name DSC -Value $DSC
        $Object
    }
}

#Cleanup
$null = Set-ExecutionPolicy $CurrentExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if ($Transcript) {
    Stop-Transcript -ErrorAction SilentlyContinue   
}