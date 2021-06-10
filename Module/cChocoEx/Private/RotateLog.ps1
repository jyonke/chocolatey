Function RotateLog {
    if (Test-Path -Path (Join-Path $LogPath "cChoco.log")) {
        $LogFile = Get-Item (Join-Path $LogPath "cChoco.log")
        if ($LogFile.Length -ge 10MB) {
            Copy-Item -Path (Join-Path $LogPath "cChoco.log") -Destination (Join-Path $LogPath "cChoco.1.log")
            Clear-Content -Path (Join-Path $LogPath "cChoco.log") -Force -ErrorAction SilentlyContinue
        }
    }
}