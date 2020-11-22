[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $SettingsURI,
    # Used Cached bootstrap settings
    [Parameter()]
    [switch]
    $Cache
)

Set-ExecutionPolicy Bypass -Scope Process

Start-Transcript -Path (Join-Path "$env:SystemRoot\temp" "bootstrap-cchoco.log")

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
    Write-Warning "No settings defined, using default"
    $InstallDir = "$env:ProgramData\chocolatey"
    $ChocoInstallScriptUrl = 'https://chocolatey.org/install.ps1'
    $ModuleVersion = "2.4.1.0"
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
Write-Output "cChocoInstaller: Validating Chocolatey is installed"
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
Write-Output "cChocoSource: Validating Chocolatey Sources are Setup"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoSource")
Import-Module $ModulePath
 
if (Test-Path (Join-Path "$InstallDir\config" "sources.psd1") ) {
    $ConfigImport = Import-PowerShellDataFile (Join-Path "$InstallDir\config" "sources.psd1")
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
    $Configurations | ForEach-Object {
        $Configuration = $_
        Write-Output $Configuration
        Write-Output "-------------------------------"
        if (-not(Test-TargetResource @Configuration )) {
            Set-TargetResource @Configuration
        }
    }
}
else {
    Write-Warning "File not found, sources will not be modified"
    Write-Warning (Join-Path "$InstallDir\config" "sources.psd1")
}


#Process Configuration
Write-Output "cChocoPackageInstall: Validating Chocolatey Packages are Installed"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoPackageInstall")
Import-Module $ModulePath
Get-ChildItem -Path "$InstallDir\config" -Filter *.psd1 | Where-Object {$_.Name -ne "sources.psd1"} | ForEach-Object {
    $ConfigImport = Import-PowerShellDataFile $_.FullName 
    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
    $Configurations | ForEach-Object {
        $Configuration = $_
        Write-Output $Configuration
        Write-Output "-------------------------------"
        if (-not(Test-TargetResource @Configuration )) {
            Set-TargetResource @Configuration
        }
    }
}
Stop-Transcript