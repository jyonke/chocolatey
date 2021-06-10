function New-PSCredential {
    [CmdletBinding()]
    param (
        # User Name
        [Parameter(Mandatory = $true)]
        [string]
        $User,
        # Encrypted Password
        [Parameter(Mandatory = $true)]
        [string]
        $Password,
        # Key File
        [Parameter(Mandatory = $true)]
        [string]
        $KeyFile
    )
    $key = Get-Content $KeyFile
    [pscredential]$PSCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, ($Password | ConvertTo-SecureString -Key $key)
    return $PSCredential
}