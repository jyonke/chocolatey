@{
    "windows-10-upgrade" = @{
        Name        = "windows-10-upgrade"
        Ensure      = 'Present'
        Params      = '/Source:LAX'
        chocoParams = '--execution-timeout 0 --params-global'
        VPN         = $false
    } 
}