@{
    "adobereader"             = @{
        Name   = "adobereader"
        Ensure = 'Present'
    } 
    "googlechrome"            = @{
        Name   = "googlechrome"
        Ensure = 'Present'
    }
    "firefox"                 = @{
        Name   = "firefox"
        Ensure = 'Present'
    }
    "jre8"                    = @{
        Name   = "jre8"
        Ensure = 'Present'
    }
    "vcredist140"             = @{
        Name   = "vcredist140"
        Ensure = 'Present'
    }
    "notepadplusplus.install" = @{
        Name   = "notepadplusplus.install"
        Ensure = 'Present'
    }
    "7zip.install"            = @{
        Name   = "7zip.install"
        Ensure = 'Present'
    }
    "vlc"                     = @{
        Name   = "vlc"
        Ensure = 'Present'
    }
    "microsoft-teams.install" = @{
        Name        = "microsoft-teams.install"
        Ensure      = 'Present'
        AutoUpgrade = $true
    }
    "microsoft-edge"          = @{
        Name        = "microsoft-edge"
        Ensure      = 'Present'
        AutoUpgrade = $true
    }
    "zoom"                    = @{
        Name        = "zoom"
        Ensure      = 'Present'
        AutoUpgrade = $true
    }
    'chocolateygui'           = @{
        Name   = 'chocolateygui'
        Ensure = 'Present'
    }
    'citrix-workspace-broad'  = @{
        Name           = 'citrix-workspace'
        Ensure         = 'Present'
        MinimumVersion = '21.5.0.48'
        Ring           = 'Broad'
    }
    'citrix-workspace-fast'   = @{
        Name        = 'citrix-workspace'
        Ensure      = 'Present'
        AutoUpgrade = $true
        Ring        = 'Fast'
    }
}