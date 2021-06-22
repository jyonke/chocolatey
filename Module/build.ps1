$LocalRepository = "$PSScriptRoot\builds"

New-Item -ItemType Directory -Path $LocalRepository -Force -ErrorAction SilentlyContinue

Register-PSRepository -Name Local_Nuget_Feed -SourceLocation $LocalRepository -PublishLocation $LocalRepository -InstallationPolicy Trusted

Publish-Module -Path "$PSScriptRoot\cChocoEx" -Repository Local_Nuget_Feed -NuGetApiKey 'ABC123'

Unregister-PSRepository -Name Local_Nuget_Feed