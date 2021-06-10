if ($PSVersionTable.PSVersion.Major -lt 5) {
    function Import-PowerShellDataFile {
        param (
            # Path to PSD1 File
            [Parameter(Mandatory = $true)]
            [string]
            $Path
        )
        [hashtable][Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformation()]$Hashtable = $Path
        return $Hashtable
    }
}