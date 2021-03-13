# chocolatey

One line install 
Set-ExecutionPolicy Bypass -Scope Process -Force; iwr https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/bootstrap.ps1 -UseBasicParsing -OutFile "$env:TEMP\bootstrap.ps1"; &"$env:TEMP\bootstrap.ps1" -SettingsURI 'https://raw.githubusercontent.com/jyonke/chocolatey/master/DSC/configurations/examples/cChocoBootstrapExample.psd1'