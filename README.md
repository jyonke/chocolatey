# ![Bootstrap installing Chocolatey and Invoking PowerShell DSC Module cChoco](https://cdn.rawgit.com/chocolatey/choco/14a627932c78c8baaba6bef5f749ebfa1957d28d/docs/logo/chocolateyicon.gif "Chocolatey Logo") Bootstrap installing Chocolatey and Invoking PowerShell DSC Module cChoco

Define your install parameters, configurations, sources, and packages in a single file and automate your entire Windows software stack/config.

You can pass the following key/value pair in your bootstrap configuration file:

* `InstallDir`              - The local path to install Chocolatey to. Defaults to `$env:ProgramData\chocolatey` (e.g. `InstallDir = 'C:\ProgramData\chocolatey'`);
* `ChocoInstallScriptUrl`   - PowerShell script to install Chocolatey. Defaults to `https://raw.githubusercontent.com/jyonke/chocolatey/master/Install/install.ps1` (e.g. `$ChocoInstallScriptUrl = 'https://chocolatey.org/install.ps1'`);
* `ModuleSource`            - Path to cChoco DSC nupkg. Defaults to the PowerShell Gallery (e.g. `ModuleSource = 'https://github.com/jyonke/chocolatey/raw/master/DSC/nupkg/cchoco.2.5.0.nupkg'`);
* `ModuleVersion`           - Defines the required ModuleVersion. Must match your defined ModuleSource Defaults to `2.5.0.0` (e.g. `ModuleVersion = "2.4.1.0"`);
* `SourcesConfig`           - Path to the PowerShell Data File (PSD1) that defines your source configurations. (e.g. `SourcesConfig = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/examples/cChocoSourcesExample.psd1'`);
* `ChocoConfig`             - Path to the PowerShell Data File (PSD1) that defines your Chocolatey configurations. (e.g. `ChocoConfig   = 'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/examples/cChocoConfigExample.psd1'`);
* `SourcesConfig`           - Path to the PowerShell Data File (PSD1) that defines your array of package configurations. (e.g. `packageConfig = @('https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/examples/cChocoPackagesExample.psd1')`);


# Example One line Install 
`Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iwr https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/bootstrap.ps1 -UseBasicParsing -OutFile "$env:TEMP\bootstrap.ps1"; &"$env:TEMP\bootstrap.ps1" -SettingsURI 'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/examples/cChocoBootstrapExample.psd1'`;

# cChoco Chocolatey Configuration
* `ConfigName`  - The Chocolatey feature name. (e.g. `webRequestTimeoutSeconds`);
* `Ensure`      - Define desired state. Defaults to `Present`. (Valid options `Present,Absent`);
* `Value`       - Value to set related to defined configuration. (e.g. `60`);

# cChoco Chocolatey Package
* `Name`        - The package name. (e.g. `adobereader`);
* `Version`     - The package version. (e.g. `2021.001.20142`);
* `Ensure`      - Define desired state. Defaults to `Present`. (Valid options `Present,Absent`);
* `AutoUpgrade` - Define is package should automatically upgrade to latest version in defined sources. (Valid options `$true,$false`);
* `VPN`         - Control is package should be deployed if a VPN connection is detected. (Valid options `$true,$false`);
* `chocoParams` - Optional paramters to be used on package deployment. (e.g. `--execution-timeout 0`); 
* `Params`      - Package parameters to be used on package deployment. (e.g. `/UpdateMode:4`);

# cChoco Chocolatey Sources
* `Name`        - The source name. (e.g. `chocolatey`);
* `Priority`    - Priority value of the source repository. (e.g. `4`);
* `Source`      - The source repository value. (e.g. `https://chocolatey.org/api/v2/`);
* `Ensure`      - Define desired state. Defaults to `Present`. (Valid options `Present,Absent`);
* `User`        - User name used to authenticate to source. (e.g. `svc_chocolatey`);
* `Password`    - Encrypted password used to authentucate to source.;
* `KeyFile`     - Path to local private key used to decrypt the password string. (e.g. `C:\ProgramData\chocolatey\config\chocolatey.key`) ;