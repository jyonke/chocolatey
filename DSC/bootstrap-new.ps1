
$RepositoryData = @{
    Name                      = 'nuget.lvl12.com'
    SourceLocation            = 'https://nuget.lvl12.com/repository/nuget-ps/'
    InstallationPolicy        = 'Trusted'
    PackageManagementProvider = 'nuget'
}
if (-not(Get-PSRepository -Name $RepositoryData.Name)) {
    Register-PSRepository @RepositoryData
}
Install-Module -Name 'cChoco' -Scope 'AllUsers' -Repository $RepositoryData.Name
Install-Module -Name 'cChocoEx' -Scope 'AllUsers' -Repository $RepositoryData.Name

Start-cChocoEx