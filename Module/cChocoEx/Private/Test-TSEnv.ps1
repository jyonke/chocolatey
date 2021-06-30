function Test-TSEnv {
    try {
        $TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
        if ($TSEnv) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}