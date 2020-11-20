Set-ExecutionPolicy Bypass -Scope Process

#Variables
$InstallDir = "$env:ProgramData\chocolatey"
$ChocoInstallScriptUrl = "https://github.com/jyonke/chocolatey/raw/master/Install/install.ps1"
$ModuleSource = "https://github.com/jyonke/chocolatey/raw/master/DSC/cchoco.2.4.1.nupkg"
$ModuleVersion = "2.4.1.0"
$SourcesConfig = 'https://github.com/jyonke/chocolatey/raw/master/DSC/sources/sources.psd1'
$PackageConfig = 'https://github.com/jyonke/chocolatey/raw/master/DSC/config/Global-Configuration.psd1'

#Confirm cChoco is installed and define $ModuleBase
$Test = 'Get-Module -ListAvailable -Name cChoco | Where-Object {$_.Version -eq $ModuleVersion}'
if (-not(Invoke-Expression -Command $Test)) {
    Write-Output "Installing cChoco - version $ModuleVersion"
    Write-Output "Source: $ModuleSource"
    $ModuleInstalled = $false
    try {
        $DownloadFile = (Join-Path $env:TEMP "cChoco.$ModuleVersion.nupkg.zip")
        $Destination = (Join-Path "$env:ProgramFiles\WindowsPowerShell\Modules" "cChoco\$ModuleVersion")
        Start-BitsTransfer -Destination $DownloadFile -Source $ModuleSource -ErrorAction Stop
        $null = New-Item -ItemType Directory -Path $Destination -Force -ErrorAction SilentlyContinue
        Expand-Archive -Path $DownloadFile -DestinationPath $Destination -Force -ErrorAction Stop
    }
    catch {
        Write-Warning $_.Exception.Message
        $AltMethod = $true
    }
    if ($AltMethod) {
        try {
            Write-Output "Internal Repository Failed"
            Write-Output "Attemping to install from PowerShell Gallery"
            $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction SilentlyContinue
            Install-Module cChoco -RequiredVersion $ModuleVersion -Confirm:$false -Force -ErrorAction Stop
        }
        catch {
            $_.Exception.Message
        }
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
    Start-BitsTransfer -Source $SourcesConfig -Destination (Join-Path "$InstallDir\config" "sources.psd1")
}

#Copy Package Config
if ($PackageConfig) {
    $null = New-Item -ItemType Directory -Path (Join-Path $InstallDir "config") -ErrorAction SilentlyContinue
    Start-BitsTransfer -Source $PackageConfig -Destination (Join-Path "$InstallDir\config" "packages.psd1") 
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
$ConfigImport = Import-PowerShellDataFile (Join-Path "$InstallDir\config" "sources.psd1") 
$Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
$Configurations | ForEach-Object {
    $Configuration = $_
    if (-not(Test-TargetResource @Configuration )) {
        Set-TargetResource @Configuration
    }
}

#Process Configuration
Write-Output "cChocoPackageInstall: Validating Chocolatey Packages are Installed"
$ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoPackageInstall")
Import-Module $ModulePath
$ConfigImport = Import-PowerShellDataFile (Join-Path "$InstallDir\config" "packages.psd1") 
$Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
$Configurations | ForEach-Object {
    $Configuration = $_
    if (-not(Test-TargetResource @Configuration )) {
        Set-TargetResource @Configuration
    }
}