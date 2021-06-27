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
    "adobereader"                        = @{
        Name        = "adobereader"
        Ensure      = 'Present'
        AutoUpgrade = $True
    }
    "7zip.install"                       = @{
        Name        = "7zip.install"
        Ensure      = 'Present'
        AutoUpgrade = $True
    }
    "notepadplusplus.install"            = @{
        Name        = "notepadplusplus.install"
        Ensure      = 'Present'
        AutoUpgrade = $True
    }
    "vlc-broad"                          = @{
        Name                      = "vlc"
        MinimumVersion            = "2.0.1"
        Ensure                    = 'Present'
        OverrideMaintenanceWindow = $True
        Ring                      = 'Broad'
    }
    "vlc-preview"                        = @{
        Name        = "vlc"
        Ensure      = 'Present'
        AutoUpgrade = $True
        Ring        = 'Preview'
    }
    "vlc-slow"                           = @{
        Name           = "vlc"
        Ensure         = 'Present'
        MinimumVersion = "3.0.0"
        Ring           = 'Slow'
    }
    "vlc-fast"                           = @{
        Name                      = "vlc"
        Ensure                    = 'Present'
        MinimumVersion            = "3.0.15"
        OverrideMaintenanceWindow = $True
        Ring                      = 'Fast'
    }
    "jre8"                               = @{
        Name                      = "jre8"
        Ensure                    = 'Present'
        AutoUpgrade               = $True
        OverrideMaintenanceWindow = $False
    }
    "git.install"                        = @{
        Name        = "git.install"
        Ensure      = 'Present'
        AutoUpgrade = $True
        chocoParams = '--execution-timeout 0'
        Source      = 'https://chocolatey.org/api/v2/'
    }
    "adobeair"                           = @{
        Name        = "adobeair"
        Ensure      = 'Present'
        AutoUpgrade = $True
        VPN         = $True
    }
    "chocolatey-windowsupdate.extension" = @{
        Name        = "chocolatey-windowsupdate.extension"
        Ensure      = 'Present'
        AutoUpgrade = $True
        VPN         = $False
    }
    'firefox-x64'                        = @{
        Name    = 'firefox-x64'
        Version = "87.0"
        Ensure  = 'Present'
        Ring    = 'broad'
    }
    'firefox-x64-latest'                 = @{
        Name        = 'firefox-x64'
        Ensure      = 'Present'
        AutoUpgrade = $True
        Ring        = 'Pilot'
    }
    'microsoft-edge'                     = @{
        Name        = 'microsoft-edge'
        Ensure      = 'Present'
        AutoUpgrade = $True
        Ring        = 'Broad'
    }
    'winscp'                             = @{
        Name        = 'winscp'
        Ensure      = 'Present'
        AutoUpgrade = $True
        Ring        = 'Broad'
    }
}