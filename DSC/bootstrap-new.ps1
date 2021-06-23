
$RepositoryData = @{
    Name                      = 'nuget.lvl12.com'
    SourceLocation            = 'https://nuget.lvl12.com/repository/nuget-ps/'
    InstallationPolicy        = 'Trusted'
    PackageManagementProvider = 'nuget'
}

$cChocoExData = @{
    SettingsURI = 'https://raw.githubusercontent.com/jyonke/chocolatey/Module/DSC/configurations/examples/cChocoBootstrapExample.psd1' 
    RandomDelay = $true
}

$PackageProviderData = @{
    Name           = 'Nuget'
    MinimumVersion = 2.8.5.201
    Force          = $true
}
#NuGet Provider Setup
if (-not(Get-PackageProvider -Name $PackageProviderData.Name -ErrorAction SilentlyContinue)) {
    Install-PackageProvider @PackageProviderData
}

#Register PSRepository
if (-not(Get-PSRepository -Name $RepositoryData.Name -ErrorAction SilentlyContinue)) {
    Register-PSRepository @RepositoryData
}

#Install and Update cChoco and cChocoEx
if (Get-Module -Name 'cChoco') {
    Update-Module -Name 'cChoco'
}
else {
    Install-Module -Name 'cChoco' -Scope 'AllUsers' -Repository $RepositoryData.Name -Force
}

if (Get-Module -Name 'cChocoEx') {
    Update-Module -Name 'cChocoEx'
}
else {
    Install-Module -Name 'cChocoEx' -Scope 'AllUsers' -Repository $RepositoryData.Name -Force
}

Import-Module -Name 'cChocoEx' -Force

#Run cChocoEx
Start-cChocoEx @cChocoExData 