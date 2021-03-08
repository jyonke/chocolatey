# Copyright (c) 2017 Chocolatey Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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