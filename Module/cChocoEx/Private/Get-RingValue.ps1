function Get-RingValue {
    param (
        # Name
        [Parameter()]
        [string]
        $Name
    )
    switch ($Name) {
        "canary" { $Value = 4 }
        "fast" { $Value = 3 }
        "slow" { $Value = 2 }
        Default { $Value = 0 }
    }
    return [int]$Value
}