@{
    # If authoring a script module, the RootModule is the name of your .psm1 file
    RootModule = 'cChocoEx.psm1'

    Author = 'Jonathan Yonke <jon.yonke@gmail.com>'

    ModuleVersion = '0.0.2.04'

    # Use the New-Guid command to generate a GUID, and copy/paste into the next line
    GUID = 'fa3aecec-1a56-443c-8fb9-13ee275f1391'

    Copyright = '2021'

    Description = 'Adds some additional functionality to the PowerShell DSC module cChoco'

    # Minimum PowerShell version supported by this module (optional, recommended)
    PowerShellVersion = '3.0'

    # Which PowerShell functions are exported from your module? (eg. Get-CoolObject)
    FunctionsToExport = @('Start-cChocoEx','Get-cChocoExRing','Set-cChocoExRing','Update-cChocoEx','Get-cChocoExLog','Get-cChocoExConfig','Get-cChocoExFeature','Get-cChocoExMaintenanceWindow','Get-cChocoExPackageInstall','Get-cChocoExSource')

    # Which PowerShell aliases are exported from your module? (eg. gco)
    AliasesToExport = @('')

    # Which PowerShell variables are exported from your module? (eg. Fruits, Vegetables)
    VariablesToExport = @('')

    # PowerShell Gallery: Define your module's metadata
    PrivateData = @{
        PSData = @{
            # What keywords represent your PowerShell module? (eg. cloud, tools, framework, vendor)
            Tags = @('chocolatey', 'cChoco')

            # What software license is your code being released under? (see https://opensource.org/licenses)
            LicenseUri = ''

            # What is the URL to your project's website?
            ProjectUri = ''

            # What is the URI to a custom icon file for your project? (optional)
            IconUri = ''

            # What new features, bug fixes, or deprecated features, are part of this release?
            ReleaseNotes = @'
'@
        }
    }

    # If your module supports updateable help, what is the URI to the help archive? (optional)
    # HelpInfoURI = ''
}