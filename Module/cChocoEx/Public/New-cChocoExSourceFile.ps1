function New-cChocoExSourceFile {
    [CmdletBinding()]
    param (
        # Path of Output File
        [Parameter(Mandatory)]
        [string]
        $Path,
        # NoClobber
        [Parameter()]
        [switch]
        $NoClobber
    )
    
    begin {
        $ExportString = "@{`n"
        $Absent = New-Object System.Management.Automation.Host.ChoiceDescription '&Absent'
        $Present = New-Object System.Management.Automation.Host.ChoiceDescription '&Present'
        $SelectTrue = New-Object System.Management.Automation.Host.ChoiceDescription '&True'
        $SelectFalse = New-Object System.Management.Automation.Host.ChoiceDescription '&False'
        $SelectYes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes'
        $SelectNo = New-Object System.Management.Automation.Host.ChoiceDescription '&No'
        $EnsureOptions = [System.Management.Automation.Host.ChoiceDescription[]]($Present, $Absent)
        $TrueFalseOptions = [System.Management.Automation.Host.ChoiceDescription[]]($SelectTrue, $SelectFalse)
        $YesNoOptions = [System.Management.Automation.Host.ChoiceDescription[]]($SelectYes, $SelectNo)
        $Title = 'cChocoEx - Desired State'
        $ReqChoices = @(
            'Name'
            'Ensure (Present/Absent)'
        )
        $Optchoices = @(
            'Priority'
            'Source'
            'User'
            'Password'
            'KeyFile'
            'VPN ($True/$False)'
        )
    }
    
    process {
        do {
            $HashTable = $null
            $HashTable = $host.ui.Prompt(($Title + " - Sources"), $null, $Reqchoices)

            $ExportString += "`t`'$($HashTable.Name)`' = @{`n"
            $ExportString += "`t`tName`t`t= `'$($HashTable.Name)`'`n"
            $ExportString += "`t`tEnsure`t`t= `'$($HashTable.('Ensure (Present/Absent)'))`'`n"

            if ($HashTable.('Ensure (Present/Absent)') -eq 'Absent') {
            }
            else {
                #Options
                $HashTable += $host.ui.Prompt($null, $null, $Optchoices)
                if ($HashTable.Priority) {
                    $ExportString += "`t`tPriority`t= `'$($HashTable.Priority)`'`n"
                }
                if ($HashTable.Source) {
                    $ExportString += "`t`tSource`t`t= `'$($HashTable.Source)`'`n"
                }
                if ($HashTable.User) {
                    $ExportString += "`t`tUser`t`t= `'$($HashTable.User)`'`n"
                }
                if ($HashTable.Password) {
                    $ExportString += "`t`tPassword`t= `'$($HashTable.Password)`'`n"
                }
                if ($HashTable.KeyFile) {
                    $ExportString += "`t`tKeyFile`t`t= `'$($HashTable.KeyFile)`'`n"
                }
                if ($HashTable.('VPN ($True/$False)')) {
                    $ExportString += "`t`tVPN`t`t= $($HashTable.('VPN ($True/$False)'))`n"
                }
            }
            $ExportString += "`t}`n"

            $Finished = $host.ui.PromptForChoice($null, 'Finished?', $YesNoOptions, 0)

        } until ($Finished -eq 0) 
        $ExportString += "`n}"
    }
    
    end {
        try {
            if ($NoClobber -and (Test-Path -Path $Path)) {
                Write-Warning "File Already Exists and NoClobber Specified. Requesting Alternative Path"
                $Path = Read-Host -Prompt "Path"
                $ExportString | Set-Content -Path $Path
            }
            else {
                $ExportString | Set-Content -Path $Path
            }
            $FullPath = (Get-Item -Path $Path).Fullname
            Write-Host "File Wriiten to $FullPath"
        }
        catch {
            $_.Exception.Message
        }
    }
}