function Test-PathEx {
    param (
        # Path
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )
    $PathType = $null
    $URLRegEx = '^(http:\/\/www\.|https:\/\/www\.|http:\/\/|https:\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$'

    if (Test-Path -Path $Path -IsValid) {
        $PathType = 'FileSystem'
    }
    if ($Path -match $URLRegEx) {
        $PathType = 'URL'
    }
    $PathType
}