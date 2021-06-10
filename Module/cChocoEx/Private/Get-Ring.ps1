function Get-Ring {
    $RegValue = (Get-ItemProperty -Path "HKLM:\Software\Chocolatey\cChoco" -ErrorAction SilentlyContinue).Ring

    switch ($RegValue) {
        "Canary" { $Ring = 'canary' }
        "Fast" { $Ring = 'fast' }
        "Slow" { $Ring = 'slow' }
        Default { $Ring = $null }
    }
    if ($Ring) {
        Write-Log -Severity 'Information' -Message "Machine Ring: $Ring"
    }
    return $Ring
}