function Start-cChocoSource {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]
        $ConfigImport
    )

    Write-Log -Severity "Information" -Message "cChocoSource:Validating Chocolatey Sources are Setup"
    $ModulePath = (Join-Path "$ModuleBase\DSCResources" "cChocoSource")
    Import-Module $ModulePath

    $Configurations = $ConfigImport | ForEach-Object { $_.Keys | ForEach-Object { $ConfigImport.$_ } }
    $Status = @()
    $Configurations | ForEach-Object {
        $DSC = $null
        $Configuration = $_
        $Object = [PSCustomObject]@{
            Name     = $Configuration.Name
            Priority = $Configuration.Priority
            DSC      = $null
            Source   = $Configuration.Source
            Ensure   = $Configuration.Ensure
            User     = $Configuration.User
            KeyFile  = $Configuration.KeyFile
            Warning  = $null
        }

        #Create PSCredential from key pair if defined
        if ($Configuration.Password) {
            #Validate Keyfile
            if (-not(Test-Path -Path $Configuration.KeyFile)) {
                $Object.Warning = "Keyfile not accessible"
                $Status += $Object
                return
            }
            try {
                $Configuration.Credentials = New-PSCredential -User $Configuration.User -Password $Configuration.Password -KeyFile $Configuration.KeyFile
            }
            catch {
                $Object.Warning = "Can not create PSCredential"
                $Status += $Object
                return
            }
            $Configuration.Remove("User")
            $Configuration.Remove("Password")
            $Configuration.Remove("KeyFile")
        }
        $null = Set-TargetResource @Configuration
        $DSC = Test-TargetResource @Configuration
        
        $Object.DSC = $DSC
        $Status += $Object
    }
    #Remove Module for Write-Host limitations
    Remove-Module "cChocoSource"

    Write-Log -Severity 'Information' -Message "cChocoSource"
    $Status | ForEach-Object {
        Write-Log -Severity 'Information' -Message "Name: $($_.Name)"
        Write-Log -Severity 'Information' -Message "DSC: $($_.DSC)"
        Write-Log -Severity 'Information' -Message "Ensure: $($_.Ensure)"
        Write-Log -Severity 'Information' -Message "Priority: $($_.Priority)"
        Write-Log -Severity 'Information' -Message "Source: $($_.Source)"
        Write-Log -Severity 'Information' -Message "User: $($_.User)"
        Write-Log -Severity 'Information' -Message "KeyFile: $($_.KeyFile)"
        if ($_.Warning) {
            Write-Log -Severity 'Warning' -Message "$($_.Warning)"
        }
    }
    
}