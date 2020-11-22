@{
    'choco-config'  = @{
        InstallDir            = 'C:\ProgramData\chocolatey'
        ChocoInstallScriptUrl = 'https://github.com/jyonke/chocolatey/raw/master/Install/install.ps1'
    }
    'cchoco-config' = @{
        ModuleSource          = 'https://github.com/jyonke/chocolatey/raw/master/DSC/cchoco.2.4.1.nupkg'
        ModuleVersion         = '2.4.1.0'
        SourcesConfig         = 'https://github.com/jyonke/chocolatey/raw/master/DSC/sources/sources.psd1'
        PackageConfig         = @(
                                'https://github.com/jyonke/chocolatey/raw/master/DSC/config/Global-Configuration.psd1'
                                'https://github.com/jyonke/chocolatey/raw/master/DSC/config/Client-Configuration.psd1'
        )
    }
}