@{
    "Local MDT"  = @{
        Name     = "Local MDT"
        Priority = 2
        Source   = "\\wds01\DeploymentShare`$\Applications"
        Ensure   = "Present"
    }
    "chocolatey" = @{
        Name     = "chocolatey"
        Priority = 0
        Source   = 'https://chocolatey.org/api/v2/'
        Ensure   = 'Present'
    }
}