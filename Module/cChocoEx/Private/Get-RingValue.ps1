function Get-RingValue {
    param (
        # Name
        [Parameter()]
        [string]
        $Name
    )
    switch ($Name) {
        "preview" { $Value = 5 }
        "canary" { $Value = 5 }
        "pilot" { $Value = 4 }
        "fast" { $Value = 3 }
        "slow" { $Value = 2 }
        "broad" { $Value = 1 }
        Default { $Value = 0 }
    }
    return [int]$Value
}