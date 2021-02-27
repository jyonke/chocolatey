@{
    'choco-config'  = @{
        InstallDir            = 'C:\ProgramData\chocolatey'
        ChocoInstallScriptUrl = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/Install/install.ps1'
    }
    'cchoco-config' = @{
        ModuleSource  = 'https://github.com/jyonke/chocolatey/raw/master/DSC/nupkg/cchoco.2.4.1.nupkg'
        ModuleVersion = '2.4.1.0'
        SourcesConfig = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/sources/sources.psd1'
        PackageConfig = @(
            'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/Global-Configuration.psd1'
            'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/Client-Configuration.psd1'
        )
    }
}