function Un7Zip-Archive {
    param (
        # Path
        [Parameter()]
        [string]
        $Path,
        # DestinationPath
        [Parameter()]
        [string]
        $DestinationPath
    )
    
    $7zaExe = Join-Path $env:TEMP -ChildPath '7za.exe'
    if (-not (Test-Path ($7zaExe))) {
        Write-Log -Severity 'Information' -Message "Downloading 7-Zip commandline tool prior to extraction."
        Invoke-WebRequest -UseBasicParsing -Uri 'https://community.chocolatey.org/7za.exe' -OutFile $7zaExe
    }
    else {
        Write-Log -Severity 'Information' -Message "7zip already present, skipping installation."
    }

    $params = 'x -o"{0}" -bd -y "{1}"' -f $DestinationPath, $Path

    # use more robust Process as compared to Start-Process -Wait (which doesn't
    # wait for the process to finish in PowerShell v3)
    $process = New-Object System.Diagnostics.Process

    try {
        $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo -ArgumentList $7zaExe, $params
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

        $null = $process.Start()
        $process.BeginOutputReadLine()
        $process.WaitForExit()

        $exitCode = $process.ExitCode
    }
    finally {
        $process.Dispose()
    }

    $errorMessage = "Unable to unzip package using 7zip. Perhaps try setting `$env:chocolateyUseWindowsCompression = 'true' and call install again. Error:"
    if ($exitCode -ne 0) {
        $errorDetails = switch ($exitCode) {
            1 { "Some files could not be extracted" }
            2 { "7-Zip encountered a fatal error while extracting the files" }
            7 { "7-Zip command line error" }
            8 { "7-Zip out of memory" }
            255 { "Extraction cancelled by the user" }
            default { "7-Zip signalled an unknown error (code $exitCode)" }
        }

        throw ($errorMessage, $errorDetails -join [Environment]::NewLine)
    }
}