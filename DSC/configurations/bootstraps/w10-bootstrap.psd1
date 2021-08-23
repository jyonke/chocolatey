#Requires -Version 5.1
#Requires -RunAsAdministrator

$NuGetRepositoryName = 'nuget.lvl12.com'
$NugetRepositoryURI = 'https://nuget.lvl12.com/repository/nuget-ps-group/'
$cChocoExParamters = @{
    ChocoConfig                 = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/configs/w10-default.psd1'
    ChocoDownloadUrl            = 'https://github.com/jyonke/chocolatey/raw/master/Install/chocolatey.0.10.15.nupkg'
    ChocoInstallScriptUrl       = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/Install/install.ps1'
    #FeatureConfig               = ''
    #InstallDir                  = ''
    Loop                        = $true
    LoopDelay                   = 15
    #MigrateLegacyConfigurations = $null
    #NoCache                     = $null
    PackageConfig               = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/packages/w10-default.psd1'
    #RandomDelay                 = $null
    #SettingsURI                 = ''
    SourcesConfig               = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/sources/sources-lvl12.com.psd1'
    #WipeCache                   = $null
}

##########################################

#NuGet Provider Setup
Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies

#Register PSRepository
$RepositoryData = @{
    Name                      = $NuGetRepositoryName
    SourceLocation            = $NugetRepositoryURI
    InstallationPolicy        = 'Trusted'
    PackageManagementProvider = 'nuget'
    ErrorAction               = 'SilentlyContinue'
}
if ($RepositoryData.SourceLocation -eq 'https://www.powershellgallery.com/api/v2') {
    Get-PSRepository | Where-Object {$_.SourceLocation -eq $PSRepositoryData.SourceLocation} | Set-PSRepository -InstallationPolicy Trusted
}
else {
    Register-PSRepository @RepositoryData
}
#Install and Update cChocoEx
if (Get-Module -Name 'cChocoEx') {
    Update-Module -Name 'cChocoEx'
}
else { 
    Install-Module -Name 'cChocoEx' -Repository $RepositoryData.Name -Force
}
Import-Module -Name 'cChocoEx' -Force

#Run cChocoEx
Start-cChocoEx @cChocoExParamters 