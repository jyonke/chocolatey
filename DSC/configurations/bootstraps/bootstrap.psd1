@{
    'choco-config'  = @{
        InstallDir            = 'C:\ProgramData\chocolatey'
        ChocoInstallScriptUrl = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/Install/install.ps1'
    }
    'cchoco-config' = @{
        ModuleSource  = 'https://github.com/jyonke/chocolatey/raw/master/DSC/nupkg/cchoco.2.5.0.nupkg'
        ModuleVersion = '2.5.0.0'
        SourcesConfig = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/sources/sources_lvl12.com.psd1'
        PackageConfig = @(
            'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/packages/windows-10-upgrade.psd1'
        )
    }
}