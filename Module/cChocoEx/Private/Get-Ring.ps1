function Get-Ring {
    $RegValue = (Get-ItemProperty -Path "HKLM:\Software\Chocolatey\cChoco" -ErrorAction SilentlyContinue).Ring

    switch ($RegValue) {
        "Preview" { $Ring = "preview" }
        "Canary" { $Ring = 'canary' }
        "Pilot" { $Ring = "pilot" }
        "Fast" { $Ring = 'fast' }
        "Slow" { $Ring = 'slow' }
        "Broad" { $Ring = 'broad' }
        Default { $Ring = "broad" }
    }
    return $Ring
}