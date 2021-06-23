
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

#Register PSRepository
if (-not(Get-PSRepository -Name $RepositoryData.Name)) {
    Register-PSRepository @RepositoryData
}

#Install and Update cChoco and cChocoEx
if (Get-Module -Name 'cChoco') {
    Update-Module -Name 'cChoco'
}
else {
    Install-Module -Name 'cChoco' -Scope 'AllUsers' -Repository $RepositoryData.Name
}

if (Get-Module -Name 'cChocoEx') {
    Update-Module -Name 'cChocoEx'
}
else {
    Install-Module -Name 'cChocoEx' -Scope 'AllUsers' -Repository $RepositoryData.Name
}

Import-Module -Name 'cChocoEx' -Force

#Run cChocoEx
Start-cChocoEx @cChocoExData 