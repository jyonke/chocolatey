#Requires -Modules Invoke-CommandAs

function Set-ChocolateySource {
    [CmdletBinding()]
    param (
        # ComputerName
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string[]]
        $ComputerName = $env:COMPUTERNAME,
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name,
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',
        [parameter(Mandatory = $false)]
        [UInt32]
        $Priority,
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [PSCredential[]]
        $Credentials,
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [System.String[]]
        $Source
    )
    
    begin {
        #Establish Session
        try {
            $ModuleBase = (Split-Path -parent $PSScriptRoot)
            $ModulePath = (Join-Path "$ModuleBase\Private\DSCResources" "cChocoSource")
            $ModuleContent = Get-Content (Get-ChildItem -Path $ModulePath -Filter *.psm1).FullName
            $ScriptBlockImport = {
                $using:ModuleContent | Set-Content "$env:SystemRoot\Temp\cChocoSource.psm1" -Force
            }
            $ScriptBlockSet = {
                $null = Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
                $null = Import-Module "$env:SystemRoot\Temp\cChocoSource.psm1"
                $Configuration = @{}
                $object = [PSCustomObject]@{}                
                if ($args[0]) { $Configuration.Name = $args[0]; $object | Add-Member -MemberType NoteProperty -Name "Name" -Value $args[0] }
                if ($args[1]) { $Configuration.Ensure = $args[1]; $object | Add-Member -MemberType NoteProperty -Name "Ensure" -Value $args[1] }
                if ($args[2]) { $Configuration.Priority = $args[2]; $object | Add-Member -MemberType NoteProperty -Name "Priority" -Value $args[2] }
                if ($args[3]) { $Configuration.Credentials = $args[3]; $object | Add-Member -MemberType NoteProperty -Name "Credentials" -Value $args[3] }
                if ($args[4]) { $Configuration.Source = $args[4]; $object | Add-Member -MemberType NoteProperty -Name "Source" -Value $args[4] }
                $Configuration.ErrorAction = "SilentlyContinue"           
                
                if (-not(Test-TargetResource @Configuration )) {
                    $null = Set-TargetResource @Configuration
                }
                $SetResult = Test-TargetResource @Configuration
                $object | Add-Member -MemberType NoteProperty -Name "DesiredState" -Value $SetResult
                return $object
            }
        }
        catch {
            throw $_.Exception.Message
            break            
        }
    }
    
    process {
        try {
            if (-not($ComputerName)) {
                $ComputerName = $env:COMPUTERNAME
            }
            $Session = New-PSSession $ComputerName -EnableNetworkAccess

            $InvokeParams = @{
                Session     = $Session
                ScriptBlock = $ScriptBlockImport
            }
            $null = Invoke-Command @InvokeParams
            $InvokeParams = @{
                Session      = $Session
                ScriptBlock  = $ScriptBlockSet
                ArgumentList = $Name, $Ensure, $Priority, $Credentials, $Source
            }
            if ($Session -and $ComputerName -ne $env:COMPUTERNAME) {                
                if ($Credential) {
                    $InvokeParams.AsUser = $Credential
                }            
                else {
                    $InvokeParams.AsSystem = $true                
                }
                $return = Invoke-CommandAs @InvokeParams
            }
            else {
                $return = Invoke-Command @InvokeParams
            }
            $return = $return | Select-Object * -ExcludeProperty RunspaceId
            $return  | Add-Member -MemberType NoteProperty -Name ComputerName -Value $ComputerName
            return $return
        }
        catch {
            throw $_
        }       

    }
    
    end {
        $Session | Remove-PSSession -ErrorAction SilentlyContinue
    }
}