function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = (Join-Path $LogPath "cChoco.log"),
        [Parameter()]
        [Switch]
        $New
    )
 
    if ($New) {
        Remove-Item -Path $Path -Force
    }
    switch ($Severity) {
        Information { $Color = "White" }
        Warning { $Color = "Yellow" }
        Error { $Color = "Red" }
        Default { $Color = "White" }
    }
    $Object = [pscustomobject]@{
        Time     = (Get-Date -f g)
        Severity = $Severity
        Message  = $Message
    } 
    $Object | Export-Csv -Path $Path -Append -NoTypeInformation
    Write-Host "$($Object.Time) - $($Object.Severity) - $($Object.Message)" -ForegroundColor $Color
}