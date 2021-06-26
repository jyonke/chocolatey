
$NuGetRepositoryName = 'nuget.lvl12.com'
$NugetRepositoryURI = 'https://nuget.lvl12.com/repository/nuget-ps/'

$cChocoExParamters = @{
    SettingsURI = 'https://raw.githubusercontent.com/jyonke/chocolatey/Module/DSC/configurations/examples/cChocoBootstrapExample.psd1' 
    RandomDelay = $true
}

#NuGet Provider Setup
Install-PackageProvider -Name NuGet -Force

#Register PSRepository
$RepositoryData = @{
    Name                      = $NuGetRepositoryName
    SourceLocation            = $NugetRepositoryURI
    InstallationPolicy        = 'Trusted'
    PackageManagementProvider = 'nuget'
}
Register-PSRepository @RepositoryData

#Install and Update cChoco and cChocoEx
if (Get-Module -Name 'cChoco') {Update-Module -Name 'cChoco'}
else {Install-Module -Name 'cChoco' -Scope 'AllUsers' -Repository $RepositoryData.Name -Force}

if (Get-Module -Name 'cChocoEx') {Update-Module -Name 'cChocoEx'}
else {Install-Module -Name 'cChocoEx' -Scope 'AllUsers' -Repository $RepositoryData.Name -Force}
Import-Module -Name 'cChocoEx' -Force

#Run cChocoEx
Start-cChocoEx @cChocoExParamters 